//
//  RuleBuilder.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/12.
//

import Foundation
import SafariServices

class RuleBuilder {
    static let shared = RuleBuilder()
    
    // EasyList 的下载地址
    let easyListURL = URL(string: "https://easylist.to/easylist/easylist.txt")!
    
    // 异步构建并保存规则
    func buildRules(settings: SettingsManager) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 开始 Loading
            settings.setLoading(true)
            
            var allRules: [[String: Any]] = []
            
            // 1. 添加基础功能规则 (根据开关)
            allRules.append(contentsOf: self.generateBasicRules(settings: settings))
            
            // 2. 处理广告拦截 (如果开启)
            if settings.get(forKey: .blockAds) {
                if let adRules = self.fetchAndParseEasyList() {
                    allRules.append(contentsOf: adRules)
                    // 成功反馈 (仅当下载成功且规则数 > 0 时)
                    if !adRules.isEmpty {
                        settings.reportResult(title: "更新成功", message: "成功加载 \(adRules.count) 条广告拦截规则。")
                    }
                } else {
                    // 失败反馈已经在 fetchAndParseEasyList 内部调用了，这里只需确保 Loading 结束
                    settings.setLoading(false)
                    return // 结束执行
                }
            } else {
                // 如果没开启广告拦截，也需要结束 Loading
                settings.setLoading(false)
            }
            
            // 3. 写入共享文件
            self.saveRulesToSharedFile(rules: allRules)
            
            // 确保最后 Loading 消失 (如果上面没报成功/失败)
            if settings.isLoading {
                settings.setLoading(false)
            }
        }
    }
    
    // 生成基础开关规则
    private func generateBasicRules(settings: SettingsManager) -> [[String: Any]] {
        var rules: [[String: Any]] = []
        
        if settings.get(forKey: .blockImages) {
            rules.append(["action": ["type": "block"], "trigger": ["resource-type": ["image"]]])
        }
        if settings.get(forKey: .blockFonts) {
            rules.append(["action": ["type": "block"], "trigger": ["resource-type": ["font"]]])
        }
        if settings.get(forKey: .forceHTTPS) {
            rules.append(["action": ["type": "make-https"], "trigger": ["url-filter": ".*"]])
        }
        // ... 其他简单规则 ...
        
        return rules
    }
    
    private func fetchAndParseEasyList() -> [[String: Any]]? {
        print("⏳ 开始下载 EasyList...")
        
        var content: String?
        var downloadError: Error?
        
        // 1. 使用信号量实现同步等待
        let semaphore = DispatchSemaphore(value: 0)
        
        // 2. 配置 20秒超时的 Request
        var request = URLRequest(url: easyListURL)
        request.timeoutInterval = 20.0 // ⏰ 设置 20 秒超时
        request.cachePolicy = .reloadIgnoringLocalCacheData // 确保下载最新
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                downloadError = error
            } else if let data = data, let str = String(data: data, encoding: .utf8) {
                content = str
            }
            semaphore.signal() // 任务结束，发送信号
        }
        task.resume()
        
        // 3. 等待网络请求结果
        _ = semaphore.wait(timeout: .now() + 21) // 稍微多给1秒缓冲
        
        // 4. 检查结果
        guard let fileContent = content else {
            print("❌ EasyList 下载失败: \(String(describing: downloadError))")
            
            // 区分是超时还是无网络
            let errorMsg: String
            if let err = downloadError as NSError?, err.code == NSURLErrorTimedOut {
                errorMsg = "下载超时 (20秒)。请检查网络状况。"
            } else {
                errorMsg = "无法下载规则。请确保网络连接正常。"
            }
            
            SettingsManager.shared.reportResult(title: "更新失败", message: errorMsg)
            return nil
        }
        
        print("✅ 下载完成，开始解析...")
        
        // 5. 解析逻辑 (保持原有逻辑)
        var rules: [[String: Any]] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty || line.hasPrefix("!") || line.hasPrefix("[") { continue }
            
            if line.hasPrefix("||") {
                var domain = line.dropFirst(2)
                if let separatorIndex = domain.firstIndex(of: "^") {
                    domain = domain[..<separatorIndex]
                }
                
                let rule: [String: Any] = [
                    "action": ["type": "block"],
                    "trigger": ["url-filter": ".*\(domain).*", "if-domain": ["*\(domain)"]]
                ]
                rules.append(rule)
            }
            
            // 性能限制
            if rules.count >= 5000 { break }
        }
        
        return rules
    }
    
    // 写入 JSON 到 App Group 目录
    private func saveRulesToSharedFile(rules: [[String: Any]]) {
        guard let url = SharedConfig.rulesFileURL else { return }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: rules, options: [])
            try data.write(to: url)
            print("✅ 规则已写入文件: \(url.path)")
            
            // 4. 最后通知 Safari 刷新
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: "com.zhijian.demo.Safari-Content-Blocker.ContentBlocker") { error in
                if let err = error { print("Reload Error: \(err)") }
                else { print("🚀 Safari 拦截器已刷新") }
            }
        } catch {
            print("❌ 写入文件失败: \(error)")
        }
    }
}
