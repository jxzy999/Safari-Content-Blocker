//
//  ContentView.swift
//  Safari Content Blocker
//
//  Created by true on 2026/1/12.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    @StateObject var settings = SettingsManager.shared
    
    // 辅助状态绑定
    func binding(for key: SettingsManager.Keys) -> Binding<Bool> {
        return Binding(
            get: { settings.get(forKey: key) },
            set: { settings.set($0, forKey: key) }
        )
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                List {
                    // 顶部状态栏
                    Section {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red)
                                .cornerRadius(8)
                            Text("Safari Content Blocker")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    
                    Section(header: Text("功能开关")) {
                        // 拦截广告：用 "hand.raised.fill" (停止手势) 或 "xmark.shield.fill"
                        ToggleRow(icon: "hand.raised.fill", color: .red, title: "拦截广告", subtitle: "加载速度快 4 倍", isOn: binding(for: .blockAds))
                        
                        // 拦截成人：保持原样或用 "eye.slash.fill" (非礼勿视)
                        ToggleRow(icon: "figure.2.and.child.holdinghands", color: .pink, title: "拦截成人网站", subtitle: "让孩子安全上网", isOn: binding(for: .blockAdult))
                        
                        // 隐藏Cookie：用 "macwindow.badge.xmark" (关闭弹窗) 或 "rectangle.slash"
                        ToggleRow(icon: "rectangle.slash", color: .orange, title: "隐藏 Cookie 提示信息", subtitle: "去除烦人横幅广告", isOn: binding(for: .hideCookies))
                        
                        // 隐藏评论：用 "bubble.left.and.bubble.right.fill" (对话气泡)
                        ToggleRow(icon: "bubble.left.and.bubble.right.fill", color: .blue, title: "隐藏文章评论", subtitle: "去除评论板块", isOn: binding(for: .blockComments))
                        
                        // 拦截社交：用 "hand.thumbsup.fill" (点赞图标) 代表社交组件
                        ToggleRow(icon: "hand.thumbsup.fill", color: .blue, title: "拦截社交按钮", subtitle: "拦截社交媒体追踪", isOn: binding(for: .blockSocial))
                        
                        // 字体：保持 "textformat"
                        ToggleRow(icon: "textformat", color: .green, title: "拦截自定义网页字体", subtitle: "减少数据用量，加快渲染速度", isOn: binding(for: .blockFonts))
                        
                        // 挖矿：用 "cpu.fill" (代表占用CPU) 或 "bitcoinsign.circle.fill" (比特币)
                        ToggleRow(icon: "cpu.fill", color: .purple, title: "拦截挖矿程序", subtitle: "拦截加密货币挖矿脚本", isOn: binding(for: .blockMiners))
                        
                        // 图片：用 "photo"
                        ToggleRow(icon: "photo", color: .gray, title: "不加载图片", subtitle: "大幅节省数据用量", isOn: binding(for: .blockImages))
                        
                        // HTTPS：用 "lock.shield.fill" (安全锁)
                        ToggleRow(icon: "lock.shield.fill", color: .green, title: "强制采用 HTTPS", subtitle: "强制采用安全网站连接", isOn: binding(for: .forceHTTPS))
                        
                        // 安全上网：用 "checkmark.shield.fill" (安全盾牌)
                        ToggleRow(icon: "checkmark.shield.fill", color: .green, title: "安全上网", subtitle: "拦截已知的恶意页面", isOn: binding(for: .blockMalice))
                        
                        // 拦截自动弹窗
                        ToggleRow(
                                icon: "rectangle.stack.badge.person.crop.fill",
                                color: .purple,
                                title: "拦截自动弹窗",
                                subtitle: "禁止网站自动打开新窗口或跳转",
                                isOn: binding(for: .blockPopups)
                            )
                    }
                    
                    Section(header: Text("设置")) {
                        // 背景更新：用 "arrow.triangle.2.circlepath" (循环更新)
                        // ⚠️ 注意：这里你需要新增一个 binding key，比如 .autoUpdate
                        ToggleRow(icon: "arrow.triangle.2.circlepath", color: .blue, title: "背景更新", subtitle: "自动更新广告过滤器", isOn: .constant(false))
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            // Loading 遮罩层
            if settings.isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("正在更新规则...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(12)
            }
        }
        .onAppear {
            // 启动时检查更新规则
            RuleBuilder.shared.buildRules(settings: settings)
        }
        .alert(isPresented: $settings.showErrorAlert) {
            Alert(
                title: Text(settings.alertTitle),
                message: Text(settings.alertMessage),
                dismissButton: .default(Text("好的"))
            )
        }
    }
}

// 自定义行组件
struct ToggleRow: View {
    var icon: String
    var color: Color
    var title: String
    var subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .padding(6)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}




#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
