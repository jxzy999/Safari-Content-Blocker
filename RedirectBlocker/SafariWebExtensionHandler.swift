//
//  SafariWebExtensionHandler.swift
//  RedirectBlocker
//
//  Created by true on 2026/1/13.
//

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let profile: UUID?
        if #available(iOS 17.0, macOS 14.0, *) {
            profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            profile = request?.userInfo?["profile"] as? UUID
        }

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        os_log(.default, "Received message from browser.runtime.sendNativeMessage: %@ (profile: %@)", String(describing: message), profile?.uuidString ?? "none")
        
        // 解析 JS 发来的消息
        guard let messageDict = message as? [String: Any],
              let type = messageDict["type"] as? String,
              type == "getSettings" else {
            return
        }
        
        // 1. 读取共享配置 (和之前一样，必须用 App Group)
        // ⚠️ 确保这个 Target 也添加了 App Group 功能
        let userDefaults = UserDefaults(suiteName: "group.com.zhijian.demo.Safari-Content-Blocker.adblocker")
        let shouldBlock = userDefaults?.bool(forKey: "blockRedirects") ?? false

        let response = NSExtensionItem()
        let responseMsg = ["blockRedirects": shouldBlock]
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [ SFExtensionMessageKey: responseMsg ]
        } else {
            response.userInfo = [ "message": responseMsg ]
        }

        context.completeRequest(returningItems: [ response ], completionHandler: nil)
    }

}
