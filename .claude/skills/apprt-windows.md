# Windows AppRuntime 开发指南

## 参考实现
- **GTK apprt**: `src/apprt/gtk/` — 最接近的参考，完整的桌面 apprt 实现
- **Embedded apprt**: `src/apprt/embedded.zig` — macOS 嵌入模式参考
- **Runtime 接口**: `src/apprt/runtime.zig` — 必须实现的接口定义

## AppRuntime 接口要求

Windows apprt 必须实现 `apprt.Runtime` 的所有方法。参考 `runtime.zig` 中的 trait：

关键方法：
- `init` / `deinit` — 生命周期
- `performAction` — 处理 keybinding/menu 触发的动作
- `wakeup` — 跨线程唤醒事件循环
- `loop` — 主事件循环（Windows: `GetMessage` / `DispatchMessage`）

Surface 相关：
- `newSurface` / `closeSurface` — 终端 surface 创建/销毁
- `setSurfaceSize` — 调整 surface 大小
- `redraw` — 请求重绘

## Windows 技术选型

### 窗口系统
- Win32 `CreateWindowExW` 创建主窗口
- WGL 创建 OpenGL context（用于渲染）
- `WM_SIZE` / `WM_KEYDOWN` / `WM_CHAR` 处理输入

### 消息循环
```
while (GetMessage(&msg)) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
}
```
对应 Zig: 使用 `std.os.windows` API

### 已有 Windows 基础
- `src/os/windows.zig` — ConPTY、进程创建、Named Pipe
- `src/Command.zig: startWindows()` — Windows 进程启动
- `src/pty.zig: WindowsPty` — 伪控制台实现
- `dist/windows/` — ico、manifest、rc 资源文件

## 开发路径（建议顺序）

### Phase 1: 最小可运行窗口
1. 创建 `src/apprt/windows/App.zig` — Win32 窗口 + 消息循环
2. 创建 `src/apprt/windows/Surface.zig` — OpenGL context + 渲染
3. 扩展 `src/apprt/runtime.zig` — 添加 `.windows` 枚举
4. 扩展 `src/build/Config.zig` — Windows 构建目标
5. 验证：能打开窗口，显示终端，输入文字

### Phase 2: 核心功能
1. 键盘输入完整支持（IME、快捷键）
2. 鼠标支持（选择、滚动、链接点击）
3. 配置文件加载（`%APPDATA%\ghostty\config`）
4. 多窗口/多 Tab 支持
5. 字体发现（DirectWrite 或 Freetype）

### Phase 3: cmux 功能集成
1. 垂直 Sidebar + Tab 信息面板
2. Named Pipe 控制 API（兼容 cmux 命令协议）
3. Agent PID 注册与监控
4. Windows Toast 通知 + 应用内通知
5. 端口监控（Windows netstat API）
6. 会话持久化（`%APPDATA%\ghostty\sessions\`）

### Phase 4: 增强功能
1. WebView2 内嵌浏览器
2. Git 分支/PR 状态集成
3. 分屏（水平+垂直）
4. 工作区管理
