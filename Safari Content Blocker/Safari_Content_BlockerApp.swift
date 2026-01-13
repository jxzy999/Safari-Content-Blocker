//
//  Safari_Content_BlockerApp.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/12.
//

import SwiftUI
import SwiftData

@main
struct Safari_Content_BlockerApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    
    // 使用 init 进行注册，这是官方推荐的时机
    init() {
        BackgroundTaskManager.shared.register()
    }
    
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        // 监听 App 状态变化
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // 当用户切到后台时，安排下一次更新
                BackgroundTaskManager.shared.scheduleAppRefresh()
            }
        }
    }
}
