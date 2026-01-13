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
    
    // MARK: - 配置源
    
    /// EasyList 广告规则源
    private let easyListURL = URL(string: "https://easylist.to/easylist/easylist.txt")!
    
    /// Steven Black 成人网站 Hosts 源
    /// ⚠️ 注意：文件较大，解析耗时
    private let adultBlockListURL = URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts")!
    
    // 你的 Safari Extension Bundle ID
    private let extensionBundleID = "com.zhijian.demo.Safari-Content-Blocker.ContentBlocker"
    
    // MARK: - 公共方法
    
    /// 核心构建方法：根据设置生成规则文件并通知 Safari
    func buildRules(settings: SettingsManager) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. 开始 Loading 状态
            settings.setLoading(true)
            
            var allRules: [[String: Any]] = []
            var errorMessages: [String] = [] // 用于收集各个步骤的报错信息
            
            // 2. 生成基础规则 (本地生成，不会失败)
            allRules.append(contentsOf: self.generateBasicRules(settings: settings))
            
            // 3. 处理广告拦截 (EasyList)
            if settings.get(forKey: .blockAds) {
                // 尝试获取规则
                if let adRules = self.fetchAndParseEasyList() {
                    allRules.append(contentsOf: adRules)
                } else {
                    // 如果失败，记录错误，但**不中断**流程，继续尝试下载下一个功能
                    errorMessages.append("广告规则下载失败(超时或网络中断)")
                }
            }
            
            // 4. 处理成人网站拦截 (Hosts)
            if settings.get(forKey: .blockAdult) {
                // 根据是否开启广告拦截动态调整 limit，防止规则总数超过 Safari 限制
                // 开启广告拦截时，留给成人规则的空间少一点；否则多一点。
                let limit = settings.get(forKey: .blockAds) ? 10000 : 30000
                
                if let adultRules = self.fetchAndParseHosts(url: self.adultBlockListURL, limit: limit) {
                    print("🔞 已加载成人网站规则: \(adultRules.count) 条")
                    allRules.append(contentsOf: adultRules)
                } else {
                    errorMessages.append("成人网站列表下载失败")
                }
            }
            
            // 5. 写入共享文件 (即使下载失败，基础规则也应该写入)
            self.saveRulesToSharedFile(rules: allRules)
            
            // 6. 结束 Loading
            settings.setLoading(false)
            
            // 7. 统合结果反馈逻辑
            self.reportFinalResult(settings: settings, totalRules: allRules.count, errors: errorMessages)
        }
    }
    
    // MARK: - 结果反馈逻辑
    
    private func reportFinalResult(settings: SettingsManager, totalRules: Int, errors: [String]) {
        if errors.isEmpty {
            // 情况A：完美成功
            let message = "规则更新完成。\n当前生效规则总数: \(totalRules)"
            settings.reportResult(title: "更新成功", message: message)
            
        } else if totalRules > 0 {
            // 情况B：部分成功 (如下载失败，但基础规则或另一个列表成功了)
            let errorDetails = errors.joined(separator: "\n")
            let message = "部分规则更新失败，但现有规则已生效。\n\n失败原因:\n\(errorDetails)"
            settings.reportResult(title: "部分完成", message: message)
            
        } else {
            // 情况C：完全失败 (几乎不可能发生，除非基础规则都没生成)
            settings.reportResult(title: "更新失败", message: "无法生成任何规则，请检查设置。")
        }
    }
    
    // MARK: - 基础规则生成
    
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
        // ... 可在此处扩展更多基础 CSS 隐藏规则 ...
        
        return rules
    }
    
    // MARK: - 网络请求通用助手
    
    /// 通用的同步下载方法 (带超时控制)
    /// - Parameters:
    ///   - url: 下载地址
    ///   - timeout: 超时时间 (秒)
    /// - Returns: 下载的字符串内容，失败则返回 nil
    private func downloadContent(from url: URL, timeout: TimeInterval) -> String? {
        var content: String?
        var downloadError: Error?
        
        // 使用信号量将异步请求转为同步，以便在后台队列顺序执行
        let semaphore = DispatchSemaphore(value: 0)
        
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                downloadError = error
            } else if let data = data, let str = String(data: data, encoding: .utf8) {
                content = str
            }
            semaphore.signal()
        }
        task.resume()
        
        // 等待结果 (多给 1 秒缓冲)
        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        
        if let result = content {
            return result
        } else {
            // 打印具体的错误日志
            let errorDesc = downloadError?.localizedDescription ?? "Unknown error"
            print("❌ 下载失败 [\(url.lastPathComponent)]: \(errorDesc)")
            return nil
        }
    }
    
    // MARK: - EasyList 解析
    
    private func fetchAndParseEasyList() -> [[String: Any]]? {
        print("⏳ 开始下载 EasyList...")
        
        // 调用通用下载方法，超时 20秒
        guard let fileContent = downloadContent(from: easyListURL, timeout: 20.0) else {
            return nil
        }
        
        print("✅ EasyList 下载完成，开始解析...")
        
        var rules: [[String: Any]] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        for line in lines {
            // 快速跳过无效行
            if line.isEmpty || line.hasPrefix("!") || line.hasPrefix("[") { continue }
            
            // 解析简单的 ABP 规则: ||example.com^
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
            
            // 性能保护：防止模拟器/低端机解析过久
            if rules.count >= 5000 { break }
        }
        
        return rules
    }
    
    // MARK: - Hosts 文件解析
    
    private func fetchAndParseHosts(url: URL, limit: Int) -> [[String: Any]]? {
        print("⏳ 开始下载成人网站列表...")
        
        // Hosts 文件通常较大，超时给 30秒
        guard let fileContent = downloadContent(from: url, timeout: 30.0) else {
            return nil
        }
        
        print("✅ Hosts 列表下载完成，开始解析...")
        
        var rules: [[String: Any]] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            let parts = trimmed.components(separatedBy: .whitespaces)
            
            // 提取域名 (Hosts 格式: 0.0.0.0 domain.com)
            if let rawDomain = parts.last,
               !rawDomain.isEmpty,
               rawDomain != "0.0.0.0",
               rawDomain != "127.0.0.1",
               rawDomain != "localhost" {
                
                // ⚠️ Safari 核心要求 1: 必须小写
                let domain = rawDomain.lowercased()
                
                // ⚠️ Safari 核心要求 2: 必须仅含 ASCII 字符
                // 包含中文或特殊字符会导致整个 Content Blocker 编译失败
                if domain.canBeConverted(to: .ascii) {
                    
                    let rule: [String: Any] = [
                        "action": ["type": "block"],
                        "trigger": [
                            "url-filter": ".*",          // 匹配任何路径
                            "if-domain": ["*\(domain)"]  // 仅在命中该域名时生效
                        ]
                    ]
                    rules.append(rule)
                }
            }
            
            if rules.count >= limit { break }
        }
        
        return rules
    }
    
    // MARK: - 文件保存与刷新
    
    private func saveRulesToSharedFile(rules: [[String: Any]]) {
        guard let url = SharedConfig.rulesFileURL else {
            print("❌ 错误：找不到 App Group 共享路径")
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: rules, options: [])
            try data.write(to: url)
            print("✅ 规则已写入文件: \(url.path)")
            
            // 通知 Safari 重新加载
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionBundleID) { error in
                if let err = error {
                    print("⚠️ Safari 刷新报错: \(err.localizedDescription)")
                    print("可能原因: Bundle ID 不匹配，或扩展未在设置中开启。")
                } else {
                    print("🚀 Safari 拦截器已成功刷新")
                }
            }
        } catch {
            print("❌ 写入文件失败: \(error)")
        }
    }
}
