# Safari 内容拦截器 (Safari Content Blocker)

一个基于 SwiftUI 构建的强大 Safari 内容拦截器和 Web 扩展，适用于 iOS 和 macOS。该应用允许用户自定义浏览体验，拦截广告、追踪器、社交小部件以及其他不需要的内容。

## 功能特性

本应用提供了一个用户友好的界面来开关各种拦截功能：

*   **🚫 拦截广告 (Block Ads):** 提升网页加载速度最高可达 4 倍。
*   **🔞 拦截成人网站 (Block Adult Content):** 提供更安全的上网环境。
*   **🍪 隐藏 Cookie 提示信息 (Hide Cookie Notices):** 去除烦人的 Cookie 同意横幅。
*   **💬 隐藏文章评论 (Hide Comments):** 隐藏文章底部的评论区。
*   **👍 拦截社交按钮 (Block Social Widgets):** 阻止社交媒体追踪代码。
*   **🔤 拦截自定义网页字体 (Block Custom Fonts):** 减少数据流量消耗并加快渲染速度。
*   **⛏️ 拦截挖矿程序 (Block Miners):** 阻止加密货币挖矿脚本。
*   **🖼️ 不加载图片 (Block Images):** 节省流量，适合低带宽网络。
*   **🔒 强制采用 HTTPS (Force HTTPS):** 强制使用安全的加密连接。
*   **🛡️ 安全上网 (Safe Browsing):** 拦截已知的恶意网页。
*   **🛑 拦截自动弹窗 (Block Popups):** 禁止网站自动打开新窗口或跳转。
*   **🔄 背景更新 (Background Updates):** 自动在后台更新拦截规则。

## 项目结构

本项目包含三个主要 Target：

1.  **Safari Content Blocker (App):**
    *   主容器应用，使用 **SwiftUI** 构建。
    *   通过 `SettingsManager` 管理用户设置。
    *   使用 `RuleBuilder` 动态生成拦截规则。
    *   通过 `BackgroundTaskManager` 处理后台任务。
    *   使用 **SwiftData** 进行数据持久化。

2.  **ContentBlocker (Extension):**
    *   标准的 Safari 内容拦截器扩展。
    *   包含 `blockerList.json` 和请求处理程序。

3.  **RedirectBlocker (Safari Web Extension):**
    *   基于 Manifest V3 的 Web 扩展，用于更高级的控制（如重定向拦截）。
    *   包含 `background.js`、`content.js` 和弹出界面。

## 环境要求

*   **Xcode:** 15.0 或更高版本
*   **iOS:** 17.0 或更高版本 (使用了最新的 SwiftUI 特性)
*   **macOS:** 14.0 或更高版本 (如果构建 Mac 版本)

## 安装与使用

1.  **克隆仓库:**
    ```bash
    git clone https://github.com/jxzy999/Safari-Content-Blocker.git
    ```

2.  **打开项目:**
    双击 `Safari Content Blocker.xcodeproj` 在 Xcode 中打开。

3.  **编译运行:**
    *   选择 `Safari Content Blocker` target。
    *   选择模拟器或连接的真机。
    *   按 `Cmd + R` 运行。

4.  **启用扩展:**
    *   **iOS:** 前往 *设置 > Safari 浏览器 > 扩展 > Safari Content Blocker* 并启用它。
    *   **macOS:** 打开 Safari，前往 *设置 > 扩展*，勾选 "Safari Content Blocker"。

## 开发说明

*   **核心逻辑:** 规则生成的核心逻辑位于 `RuleBuilder.swift` 中。
*   **用户界面:** UI 定义在 `ContentView.swift` 中。
*   **数据存储:** 设置通过 `UserDefaults` (封装在 `SettingsManager` 中) 存储，其他数据使用 `SwiftData`。

## 贡献

欢迎提交 Pull Requests。对于重大更改，请先提交 Issue 进行讨论。

## 许可证 (License)

[MIT](LICENSE)