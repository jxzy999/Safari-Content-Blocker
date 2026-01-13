//
//  BackgroundTaskManager.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/13.
//


import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    // 必须与 Info.plist 里的 ID 一致
    let taskId = "com.zhijian.demo.Safari-Content-Blocker.refreshRules"
    
    // MARK: - 注册任务
    // 在 App 启动 (init) 时调用
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            // 当系统唤醒 App 执行任务时，会运行这个闭包
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: appRefreshTask)
        }
    }
    
    // MARK: - 调度任务
    // 在 App 进入后台时调用
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        
        // 最早什么时候开始？设置为 24 小时后
        // 注意：这只是“最早”，iOS 会根据电量、使用习惯决定具体时间
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 已预约下一次后台更新任务 (约24小时后)")
        } catch {
            print("❌ 预约后台任务失败: \(error)")
        }
    }
    
    // MARK: - 执行任务逻辑
    private func handleAppRefresh(task: BGAppRefreshTask) {
        print("🚀 后台唤醒：开始更新规则...")
        
        // 1. 设置超时处理 (如果运行太久，系统会发信号，我们必须快速清理)
        task.expirationHandler = {
            print("⚠️ 后台任务即将超时，强制结束")
            // 取消所有下载任务... (简单起见这里直接不做处理，依靠系统强杀)
        }
        
        // 2. 执行核心更新逻辑
        // 注意：这里我们传入一个临时的 SettingsManager，因为后台不需要 UI
        let dummySettings = SettingsManager.shared
        
        RuleBuilder.shared.buildRules(settings: dummySettings, isBackground: true) { success in
            // 3. 告诉系统任务完成
            print("✅ 后台任务完成，结果: \(success)")
            task.setTaskCompleted(success: success)
            
            // 4. 再次预约下一次 (循环链)
            self.scheduleAppRefresh()
        }
    }
}
