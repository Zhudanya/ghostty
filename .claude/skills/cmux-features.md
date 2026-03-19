# cmux 功能借鉴参考

## 源码位置
cmux 项目位于 `../cmux/Sources/`，以下为各功能模块与 Windows 实现的映射。

## 通知系统
**cmux**: `TerminalNotificationStore.swift`, `NotificationsPage.swift`
- 双通道：macOS UNUserNotificationCenter + 应用内存储
- 结构：id, tabId, surfaceId, title, subtitle, body, createdAt, isRead
- 抑制逻辑：焦点面板不弹通知
- 音效：系统音 + 自定义文件 + 自定义命令
- Dock 徽章

**Windows 对应**:
- Windows Toast Notification API (WinRT) + 应用内通知面板
- 任务栏闪烁 + 徽章（替代 Dock）
- 系统声音 via `PlaySound`

## Socket/IPC API
**cmux**: `SocketControlSettings.swift`, `TerminalController.swift`
- Unix Domain Socket，文本协议
- 命令格式：`namespace.action arg1 arg2`
- 访问控制：Off/cmuxOnly/Automation/Password/AllowAll

**Windows 对应**:
- Named Pipe (`\\.\pipe\ghostty-windows`)
- 保持相同文本协议格式
- 访问控制通过 Named Pipe DACL

## 垂直 Sidebar
**cmux**: `ContentView.swift`, `TabManager.swift`, `SidebarSelectionState.swift`
- 200-600pt 宽度，可拖拽
- 每 Tab 显示：标题、git 分支、PR、端口、通知、进度
- 活跃指示器：leftRail / solidFill

**Windows 对应**:
- Win32 子窗口或 Panel 控件
- 自绘 sidebar（OpenGL 或 GDI+）

## 端口扫描
**cmux**: `PortScanner.swift`
- 批量合并扫描（200ms 合并窗口 + 6 次突发扫描）
- `ps -t` + `lsof -nP` 获取 TTY→PID→Port 映射

**Windows 对应**:
- `GetExtendedTcpTable` API 获取 TCP 连接
- 通过进程树关联 ConPTY 子进程

## 会话持久化
**cmux**: `SessionPersistence.swift`
- JSON 序列化全部状态
- 8 秒自动保存
- 限制：12 窗口、128 工作区、512 面板、4000 行滚动

**Windows 对应**:
- `%APPDATA%\ghostty\sessions\` 存储 JSON
- 相同的自动保存策略

## Agent PID 管理
**cmux**: `Workspace.swift` (`agentPIDs` 字典)
- Socket 命令注册：`register_agent_pid <name> <pid>`
- 定期扫描清理已退出进程
- 在 sidebar 显示 agent 状态

**Windows 对应**:
- `OpenProcess` + `WaitForSingleObject` 检测进程存活
- Named Pipe 命令注册

## 浏览器集成
**cmux**: `BrowserWindowPortal.swift`
- WKWebView 嵌入终端分屏
- Inspector 支持
- 脚本化 API

**Windows 对应**:
- WebView2 (Microsoft Edge Chromium)
- DevTools 支持内置
