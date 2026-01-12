//
//  SettingsManager.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/12.
//

import Foundation
import SafariServices
import Combine


class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // 使用 App Group 的 UserDefaults
    let userDefaults = UserDefaults(suiteName: "group.com.yourname.adblocker")!
    
    // MARK: - UI 状态控制
    @Published var showErrorAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var alertTitle: String = ""
    
    // Loading 状态
    @Published var isLoading: Bool = false
    
    // 定义功能的 Key
    enum Keys: String {
        case blockAds = "blockAds"
        case blockAdult = "blockAdult" // 需要域名列表
        case hideCookies = "hideCookies"
        case blockSocial = "blockSocial"
        case blockFonts = "blockFonts"
        case blockMiners = "blockMiners"
        case blockImages = "blockImages"
        case forceHTTPS = "forceHTTPS"
    }
    
    // 通用的获取和保存方法
    func set(_ value: Bool, forKey key: Keys) {
        // 在修改数据前发送变更通知，这样 UI 才会刷新
        objectWillChange.send()
        
        userDefaults.set(value, forKey: key.rawValue)
        
        // 触发规则重建
        print("🔄 设置改变，开始重建规则...")
        RuleBuilder.shared.buildRules(settings: self)
    }
    
    func get(forKey key: Keys) -> Bool {
        return userDefaults.bool(forKey: key.rawValue)
    }
    
    // 统一的弹窗方法 (支持成功或失败)
    func reportResult(title: String, message: String) {
        DispatchQueue.main.async {
            self.isLoading = false // 结果出来时，肯定停止加载
            self.alertTitle = title
            self.alertMessage = message
            self.showErrorAlert = true
        }
    }
    
    // 控制 Loading
    func setLoading(_ loading: Bool) {
        DispatchQueue.main.async {
            self.isLoading = loading
        }
    }
    
}
