# Ghostty Windows Terminal — 架构设计

## 核心架构分层

```
┌─────────────────────────────────────────────────────────┐
│  Windows App Layer (🆕 待开发)                          │
│  ┌─────────────┬──────────────┬────────────────────┐    │
│  │ Win32/WinUI │ Sidebar +    │ Notification       │    │
│  │ Window Mgmt │ Vertical Tab │ System (Toast)     │    │
│  └─────────────┴──────────────┴────────────────────┘    │
├─────────────────────────────────────────────────────────┤
│  Agent Integration Layer (🆕 待开发，借鉴 cmux)         │
│  ┌─────────────┬──────────────┬────────────────────┐    │
│  │ Named Pipe  │ Agent PID    │ Port Monitor       │    │
│  │ Control API │ Registry     │ (netstat)          │    │
│  └─────────────┴──────────────┴────────────────────┘    │
├─────────────────────────────────────────────────────────┤
│  Surface Layer (已有，平台无关)                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Surface.zig — 终端控件抽象                        │   │
│  │  ├── Terminal Emulation (terminal/)               │   │
│  │  ├── Renderer (renderer/ — OpenGL for Windows)    │   │
│  │  ├── Font System (font/ — Freetype/HarfBuzz)     │   │
│  │  └── Input Handling (input/)                      │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│  OS Layer (部分已有)                                     │
│  ┌──────────────────────────────────────────────────┐   │
│  │ os/windows.zig — ConPTY, Process, Named Pipes    │   │
│  │ Command.zig — startWindows() 进程创建             │   │
│  │ pty.zig — WindowsPty 伪控制台                     │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## 依赖方向

Windows App → Agent Layer → Surface → OS/PTY
                                ↕
                          Config System

**严格规则**: 下层不依赖上层，Surface 层不感知 Windows API。

## 模块职责

| 模块 | 职责 | 状态 |
|------|------|------|
| `src/apprt/windows/` | Win32 窗口管理、事件循环、消息分发 | 🆕 待开发 |
| `src/apprt/windows/sidebar.zig` | 垂直 Tab + 信息面板 | 🆕 待开发 |
| `src/apprt/windows/notification.zig` | Windows Toast 通知 + 应用内通知 | 🆕 待开发 |
| `src/apprt/windows/agent.zig` | Agent PID 注册、Named Pipe API | 🆕 待开发 |
| `src/apprt/windows/browser.zig` | WebView2 嵌入浏览器 | 🆕 P2 |
| `src/renderer/OpenGL.zig` | OpenGL 渲染后端 | ✅ 已有 |
| `src/terminal/` | 终端仿真引擎 | ✅ 已有 |
| `src/font/` | 字体系统 (需加 DirectWrite discovery) | ⚠️ 需扩展 |
| `src/os/windows.zig` | ConPTY + 进程管理 | ✅ 基础已有 |
| `src/config/` | 配置系统 | ✅ 已有 |

## 关键设计决策

### D1: Windows UI 框架选择
- **选项 A**: 纯 Win32 API — 最轻量，与 Zig 兼容好，参考 GTK apprt 实现模式
- **选项 B**: WinUI3/XAML — 现代 UI，但需 C++/WinRT 桥接
- **推荐**: 先用 Win32 API 实现基础窗口+渲染，后续可加 WinUI3 shell

### D2: 渲染后端
- 使用已有的 OpenGL 后端（Windows 原生支持 OpenGL 4.1+）
- 后续可选 DirectX 11/12 后端

### D3: Agent 通信机制
- cmux 使用 Unix Domain Socket → Windows 用 Named Pipe 替代
- 协议保持兼容 cmux 的文本命令格式

### D4: 字体发现
- Linux: Fontconfig（已有）
- macOS: CoreText（已有）
- Windows: DirectWrite（需新增）或 Fontconfig/Freetype

## 数据流

```
用户输入 → Win32 WM_KEYDOWN → input/ 键绑定查找 → Surface 处理
  ↓
PTY 输入 → ConPTY → terminal/ 解析 VT 序列 → Screen 更新
  ↓
Screen dirty → renderer/ OpenGL 绘制 → SwapBuffers → 屏幕
  ↓
Agent 通信 → Named Pipe → 命令解析 → 通知/工作区/分屏操作
```
