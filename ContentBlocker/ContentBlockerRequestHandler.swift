//
//  ContentBlockerRequestHandler.swift
//  ContentBlocker
//
//  Created by true on 2026/1/12.
//

import UIKit
import MobileCoreServices
import Foundation


class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        
        // 1. 获取共享文件的路径
        guard let rulesURL = SharedConfig.rulesFileURL else {
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        // 2. 尝试读取文件
        // 这里的 Data 读取非常快，因为文件已经生成好了
        if let rulesData = try? Data(contentsOf: rulesURL) {
            
            let attachment = NSItemProvider(item: rulesData as NSData, typeIdentifier: "public.json")
            let item = NSExtensionItem()
            item.attachments = [attachment]
            
            context.completeRequest(returningItems: [item], completionHandler: nil)
        } else {
            // 如果文件不存在（比如第一次启动尚未生成），返回空
            context.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
