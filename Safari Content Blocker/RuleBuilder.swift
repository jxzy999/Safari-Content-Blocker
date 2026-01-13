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
    
    // 定义成人网站列表的源地址 (这里使用 Steven Black 的 Porn 专供列表)
    // ⚠️ 注意：这个文件可能很大 (几 MB)，下载和解析需要一点时间
    let adultBlockListURL = URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts")!
    
    // 异步构建并保存规则
    func buildRules(settings: SettingsManager) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 开始 Loading
            settings.setLoading(true)
            
            var allRules: [[String: Any]] = []
            
            // 添加基础功能规则 (根据开关)
            allRules.append(contentsOf: self.generateBasicRules(settings: settings))
            
            // 处理广告拦截 (如果开启)
            if settings.get(forKey: .blockAds) {
                if let adRules = self.fetchAndParseEasyList() {
                    allRules.append(contentsOf: adRules)
                } else {
                    // 失败反馈已经在 fetchAndParseEasyList 内部调用了，这里只需确保 Loading 结束
                    settings.setLoading(false)
                    return // 结束执行
                }
            } else {
                // 如果没开启广告拦截，也需要结束 Loading
                settings.setLoading(false)
            }
            
            // 成人网站拦截 (如果开启)
            if settings.get(forKey: .blockAdult) {
                // 如果开启了广告拦截，已经下载了很多规则，这里需要限制一下数量防止超出 Safari 上限
                // 如果是单独开启成人拦截，可以多放宽一些
                let limit = settings.get(forKey: .blockAds) ? 10000 : 30000
                
                if let adultRules = self.fetchAndParseHosts(url: self.adultBlockListURL, limit: limit) {
                    print("🔞 已加载成人网站规则: \(adultRules.count) 条")
                    allRules.append(contentsOf: adultRules)
                }
            }
            
            // 写入共享文件
            self.saveRulesToSharedFile(rules: allRules)
            
            // 确保最后 Loading 消失 (如果上面没报成功/失败)
            if settings.isLoading {
                settings.setLoading(false)
            }
            
            // 计算总数
            let totalCount = allRules.count
            let message = "规则更新完成。\n当前生效规则总数: \(totalCount)"
            settings.reportResult(title: "更新成功", message: message)
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
    
    // MARK: - EasyList
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
            
            SettingsManager.shared.reportResult(title: "EasyList更新失败", message: errorMsg)
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
    
    // MARK: - Hosts 文件解析器
    // 专门用于解析 "0.0.0.0 domain.com" 这种格式
    private func fetchAndParseHosts(url: URL, limit: Int) -> [[String: Any]]? {
        print("⏳ 开始下载成人网站列表...")
        
        // 复用之前的下载逻辑 (带超时控制)
        var content: String?
        var downloadError: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0 // 文件较大，给 30 秒
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
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
        
        _ = semaphore.wait(timeout: .now() + 31)
        
        guard let fileContent = content else {
            print("❌ 成人列表下载失败")
            // 区分是超时还是无网络
            let errorMsg: String
            if let err = downloadError as NSError?, err.code == NSURLErrorTimedOut {
                errorMsg = "下载超时 (30秒)。请检查网络状况。"
            } else {
                errorMsg = "无法下载规则。请确保网络连接正常。"
            }
            
            SettingsManager.shared.reportResult(title: "Steven Black更新失败", message: errorMsg)
            return nil
        }
        
        print("✅ 列表下载完成，开始解析...")
        
        var rules: [[String: Any]] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            let parts = trimmed.components(separatedBy: .whitespaces)
            
            // 1. 获取域名部分
            if let rawDomain = parts.last,
               !rawDomain.isEmpty,
               rawDomain != "0.0.0.0",
               rawDomain != "127.0.0.1",
               rawDomain != "localhost" {
                
                // 2. 核心修复：强制转小写
                let domain = rawDomain.lowercased()
                
                // 3. 核心修复：检查是否只包含 ASCII 字符
                // Safari 极其严格，如果包含中文或特殊符号会直接报错导致所有规则失效
                if domain.canBeConverted(to: .ascii) {
                    
                    let rule: [String: Any] = [
                        "action": ["type": "block"],
                        "trigger": [
                            "url-filter": ".*",
                            // 注意：Safari 要求 if-domain 里的域名也必须是小写
                            "if-domain": ["*\(domain)"]
                        ]
                    ]
                    rules.append(rule)
                }
            }
            
            if rules.count >= limit { break }
        }
        
        return rules
    }
    
    // MARK: - 保存规则文件
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
