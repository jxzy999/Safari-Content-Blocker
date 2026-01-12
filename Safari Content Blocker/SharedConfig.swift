//
//  SharedConfig.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/12.
//

import Foundation

struct SharedConfig {
    // ⚠️ 必须替换为你自己的 App Group ID
    static let appGroupID = "group.com.zhijian.demo.Safari-Content-Blocker.adblocker"
    static let jsonFileName = "blockerList.json"
    
    static var containerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    static var rulesFileURL: URL? {
        return containerURL?.appendingPathComponent(jsonFileName)
    }
}
