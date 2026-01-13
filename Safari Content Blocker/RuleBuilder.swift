//
//  RuleBuilder.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/12.
//

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
    /// - Parameters:
    ///   - settings: 设置管理器
    ///   - isBackground: 是否由后台任务触发
    ///   - completion: 任务结束回调 (成功/失败)
    func buildRules(settings: SettingsManager, isBackground: Bool = false, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            
            // 0. [新增] 检查后台更新开关
            // 如果是后台触发，且用户关闭了“背景更新”，则直接跳过
            if isBackground {
                if !settings.get(forKey: .autoUpdate) {
                    print("🔕 [后台任务] 用户未开启自动更新，跳过本次任务。")
                    completion?(true) // 返回 true 告诉系统任务已处理（虽然是跳过），避免系统误判
                    return
                }
                print("🚀 [后台任务] 开始执行自动更新...")
            } else {
                // 如果是前台触发，显示 Loading
                DispatchQueue.main.async { settings.setLoading(true) }
            }
            
            var allRules: [[String: Any]] = []
            var errorMessages: [String] = [] // 用于收集各个步骤的报错信息
            
            // 1. 生成基础规则 (本地生成，不会失败)
            allRules.append(contentsOf: self.generateBasicRules(settings: settings))
            
            // 2. 处理广告拦截 (EasyList)
            if settings.get(forKey: .blockAds) {
                // 尝试获取规则 (带缓存机制)
                if let adRules = self.fetchAndParseEasyList() {
                    allRules.append(contentsOf: adRules)
                } else {
                    // 如果失败，记录错误，但**不中断**流程，继续尝试下载下一个功能
                    errorMessages.append("广告规则下载失败(超时或网络中断)")
                }
            }
            
            // 3. 处理成人网站拦截 (Hosts)
            if settings.get(forKey: .blockAdult) {
                // 根据是否开启广告拦截动态调整 limit，防止规则总数超过 Safari 限制
                let limit = settings.get(forKey: .blockAds) ? 10000 : 30000
                
                if let adultRules = self.fetchAndParseHosts(url: self.adultBlockListURL, limit: limit) {
                    print("🔞 已加载成人网站规则: \(adultRules.count) 条")
                    allRules.append(contentsOf: adultRules)
                } else {
                    errorMessages.append("成人网站列表下载失败")
                }
            }
            
            // 4. 写入共享文件 (即使下载失败，基础规则也应该写入)
            self.saveRulesToSharedFile(rules: allRules)
            
            if !isBackground {
                // 5. 前台任务：结束 Loading 并弹窗报告
                DispatchQueue.main.async { settings.setLoading(false) }
                self.reportFinalResult(settings: settings, totalRules: allRules.count, errors: errorMessages)
            }
            
            print("🏁 规则构建流程结束 (后台模式: \(isBackground))")
            
            // 6. 执行回调通知系统
            let success = !allRules.isEmpty
            completion?(success)
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
        
        // 1. 基础资源拦截 (图片、字体)
        if settings.get(forKey: .blockImages) {
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": ".*", "resource-type": ["image"]]])
        }
        if settings.get(forKey: .blockFonts) {
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": ".*", "resource-type": ["font"]]])
        }
        
        // 2. 强制 HTTPS
        if settings.get(forKey: .forceHTTPS) {
            rules.append(["action": ["type": "make-https"], "trigger": ["url-filter": ".*"]])
        }
        
        // 3. 拦截自动弹窗/跳转
        if settings.get(forKey: .blockPopups) {
            // 规则: 拦截所有的弹窗资源
            let popupRule: [String: Any] = [
                "action": ["type": "block"],
                "trigger": [
                    "url-filter": ".*",
                    "resource-type": ["popup"]
                ]
            ]
            rules.append(popupRule)
            
            // 规则: 拦截跳转脚本 (uaredirect.js)
            rules.append([
                "action": ["type": "block"],
                "trigger": ["url-filter": ".*uaredirect.*\\.js.*"]
            ])
            
            // 针对统计代码
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": ".*hm\\.baidu\\.com.*"]])
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": ".*cnzz\\.com.*"]])
            
            // 策略 A: 拦截特定小说站跳转域名
            rules.append([
                "action": ["type": "block"],
                "trigger": ["url-filter": ".*m\\.sanjiangge\\.org.*"]
            ])
            
            // 策略 B: 针对特定域名的强力脚本拦截
            rules.append([
                "action": ["type": "block"],
                "trigger": [
                    "url-filter": ".*",
                    "resource-type": ["script"],
                    "if-domain": ["*sanjiangge.org"]
                ]
            ])
        }
        
        // 4. 拦截挖矿
        if settings.get(forKey: .blockMiners) {
            rules.append(contentsOf: generateMinerRules())
        }
        
        // 5. 拦截社交按钮
        if settings.get(forKey: .blockSocial) {
            rules.append(contentsOf: generateSocialRules())
        }
        
        // 6. 隐藏 Cookie 提示
        if settings.get(forKey: .hideCookies) {
            rules.append(contentsOf: generateCookieHidingRules())
        }
        
        // 7. 隐藏评论区域
        if settings.get(forKey: .blockComments) {
            rules.append(contentsOf: generateCommentHidingRules())
        }
        
        // 8. 安全上网
        if settings.get(forKey: .blockMalice) {
            rules.append(contentsOf: generateMaliceRules())
        }
        
        return rules
    }
    
    // MARK: - 具体功能生成器
    
    private func generateMinerRules() -> [[String: Any]] {
        let filters = [
            ".*coin-hive.*", ".*coinhive.*", ".*crypto-loot.*",
            ".*miner\\.js.*", ".*minr\\.js.*", ".*deepminer.*",
            ".*coin-have.*", ".*webmine.*", ".*monerominer.*"
        ]
        var rules: [[String: Any]] = []
        for filter in filters {
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": filter]])
        }
        return rules
    }
    
    private func generateSocialRules() -> [[String: Any]] {
        var rules: [[String: Any]] = []
        // A. 拦截脚本
        let socialDomains = [
            ".*connect\\.facebook\\.net.*", ".*platform\\.twitter\\.com.*",
            ".*buttons\\.js.*", ".*addthis\\.com.*", ".*sharethis\\.com.*"
        ]
        for domain in socialDomains {
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": domain]])
        }
        // B. 隐藏元素
        let selectors = [
            ".share-button", ".social-share", ".social-icons",
            ".fb-like", ".fb-share-button", ".twitter-share-button",
            "#share-buttons", ".share-bar", ".addthis_toolbox"
        ]
        rules.append(createCSSRule(selectors: selectors))
        return rules
    }
    
    private func generateCookieHidingRules() -> [[String: Any]] {
        let selectors = [
            "#onetrust-consent-sdk", ".onetrust-pc-dark-filter",
            "#cookie-banner", ".cookie-banner", "#cookie-notice", ".cookie-notice",
            ".cc-window", ".cc-banner", "[aria-label='cookieconsent']",
            "#gdpr-banner", ".gdpr-banner", ".app_bottom_bar", ".fc-consent-root"
        ]
        return [createCSSRule(selectors: selectors)]
    }
    
    private func generateCommentHidingRules() -> [[String: Any]] {
        let selectors = [
            "#comments", ".comments", ".comment-list",
            "#disqus_thread", ".fb-comments", "#livefyre-comments",
            ".comment-section", ".comments-area", ".post-comments"
        ]
        return [createCSSRule(selectors: selectors)]
    }
    
    private func generateMaliceRules() -> [[String: Any]] {
        let patterns = [
            ".*bet365.*", ".*v1\\.cn.*", ".*pop\\.ads.*",
            ".*ad\\.doubleclick\\.net.*", ".*googlesyndication\\.com.*",
            ".*17ksw\\.com.*"
        ]
        var rules: [[String: Any]] = []
        for pattern in patterns {
            rules.append(["action": ["type": "block"], "trigger": ["url-filter": pattern]])
        }
        return rules
    }
    
    private func createCSSRule(selectors: [String]) -> [String: Any] {
        let selectorString = selectors.joined(separator: ", ")
        return [
            "action": ["type": "css-display-none", "selector": selectorString],
            "trigger": ["url-filter": ".*"]
        ]
    }
    
    // MARK: - 网络与缓存助手
    
    /// 获取内容（带每日缓存机制）
    private func fetchContentWithDailyCache(url: URL, cacheFileName: String, timeout: TimeInterval) -> String? {
        // 1. 获取缓存路径
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return downloadContent(from: url, timeout: timeout)
        }
        let fileURL = cacheDir.appendingPathComponent(cacheFileName)
        
        // 2. 检查缓存有效性 (必须是今天的)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date {
                    if Calendar.current.isDateInToday(modificationDate) {
                        print("📦 [缓存命中] \(cacheFileName) 是最新的，直接使用。")
                        return try String(contentsOf: fileURL, encoding: .utf8)
                    } else {
                        print("🔄 [缓存过期] \(cacheFileName) 日期已旧，准备更新...")
                    }
                }
            } catch {
                print("⚠️ 缓存检查失败: \(error)")
            }
        } else {
            print("🆕 [无缓存] 首次下载 \(cacheFileName)...")
        }
        
        // 3. 下载新内容
        guard let content = downloadContent(from: url, timeout: timeout) else {
            print("❌ 下载失败，尝试使用旧缓存兜底...")
            if let oldContent = try? String(contentsOf: fileURL, encoding: .utf8) {
                print("⚠️ 已降级使用旧缓存。")
                return oldContent
            }
            return nil
        }
        
        // 4. 更新缓存
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("💾 [缓存更新] 已写入新内容至 \(cacheFileName)")
        } catch {
            print("❌ 写入缓存失败: \(error)")
        }
        return content
    }
    
    /// 基础下载方法
    private func downloadContent(from url: URL, timeout: TimeInterval) -> String? {
        var content: String?
        var downloadError: Error?
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
        
        _ = semaphore.wait(timeout: .now() + timeout + 1.0)
        
        if let result = content {
            return result
        } else {
            let errorDesc = downloadError?.localizedDescription ?? "超时或未知错误"
            print("❌ 下载错误 [\(url.lastPathComponent)]: \(errorDesc)")
            return nil
        }
    }
    
    // MARK: - 列表解析逻辑
    
    private func fetchAndParseEasyList() -> [[String: Any]]? {
        // 使用缓存获取
        guard let fileContent = fetchContentWithDailyCache(
            url: easyListURL,
            cacheFileName: "easylist.txt",
            timeout: 20.0
        ) else { return nil }
        
        print("✅ EasyList 获取成功，正在解析...")
        var rules: [[String: Any]] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty || line.hasPrefix("!") || line.hasPrefix("[") { continue }
            if line.hasPrefix("||") {
                var domain = line.dropFirst(2)
                if let separatorIndex = domain.firstIndex(of: "^") {
                    domain = domain[..<separatorIndex]
                }
                rules.append([
                    "action": ["type": "block"],
                    "trigger": ["url-filter": ".*\(domain).*", "if-domain": ["*\(domain)"]]
                ])
            }
            if rules.count >= 5000 { break }
        }
        return rules
    }
    
    private func fetchAndParseHosts(url: URL, limit: Int) -> [[String: Any]]? {
        // 使用缓存获取
        guard let fileContent = fetchContentWithDailyCache(
            url: url,
            cacheFileName: "adult_hosts.txt",
            timeout: 30.0
        ) else { return nil }
        
        print("✅ Hosts 获取成功，正在解析...")
        var rules: [[String: Any]] = []
        let lines = fileContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            let parts = trimmed.components(separatedBy: .whitespaces)
            if let rawDomain = parts.last, !rawDomain.isEmpty,
               rawDomain != "0.0.0.0", rawDomain != "127.0.0.1", rawDomain != "localhost" {
                
                let domain = rawDomain.lowercased()
                if domain.canBeConverted(to: .ascii) {
                    rules.append([
                        "action": ["type": "block"],
                        "trigger": ["url-filter": ".*", "if-domain": ["*\(domain)"]]
                    ])
                }
            }
            if rules.count >= limit { break }
        }
        return rules
    }
    
    // MARK: - 文件保存
    
    private func saveRulesToSharedFile(rules: [[String: Any]]) {
        guard let url = SharedConfig.rulesFileURL else {
            print("❌ 错误：找不到 App Group 共享路径")
            return
        }
        
        var finalRules = rules
        // 防止空规则导致报错
        if finalRules.isEmpty {
            finalRules.append([
                "action": ["type": "block"],
                "trigger": ["url-filter": "placeholder-123456", "if-domain": ["nonexistent.local"]]
            ])
            print("ℹ️ 规则列表为空，已添加占位规则。")
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: finalRules, options: [])
            try data.write(to: url)
            print("✅ 规则文件已保存: \(url.path)")
            
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: extensionBundleID) { error in
                if let err = error {
                    print("⚠️ Safari 刷新报错: \(err.localizedDescription)")
                } else {
                    print("🚀 Safari 拦截器已刷新 (生效规则: \(finalRules.count) 条)")
                }
            }
        } catch {
            print("❌ 文件保存失败: \(error)")
        }
    }
}
