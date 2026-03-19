# Ghostty Windows Terminal

基于 Ghostty 终端引擎，参考 cmux 的 Agent 工作台理念，开发适用于 Windows 平台的终端应用。

**技术栈**: Zig (核心引擎), C ABI (嵌入接口), Win32/WinUI3 (Windows UI), OpenGL (渲染)

## 常用命令

```bash
# Windows 构建（首次需要先打补丁）
scripts/patch-zig-windows.sh    # 或 scripts\patch-zig-windows.bat
zig build -Dapp-runtime=windows

# Windows 构建 + 运行
zig build -Dapp-runtime=windows run

# 构建（Linux/macOS 默认）
zig build

# 测试
zig build test

# 构建 libghostty（Release）
zig build -Demit-xcframework=true -Doptimize=ReleaseFast

# Lint
# Zig: zig fmt --check src/
# Shell: shellcheck scripts/*.sh
```

## 项目结构

```
src/
├── terminal/       # 终端仿真引擎（VT 协议、屏幕管理、滚动缓冲）
├── renderer/       # GPU 渲染（Metal/OpenGL/WebGL）
├── font/           # 字体系统（Atlas、Discovery、Metrics）
├── input/          # 输入处理（键盘绑定、鼠标、粘贴）
├── config/         # 配置系统（文件/CLI/环境变量）
├── apprt/          # 应用运行时（平台适配层）⭐ Windows 开发重点
│   ├── gtk/        # Linux GTK4 运行时（参考实现）
│   ├── embedded.zig # macOS 嵌入运行时
│   └── [windows/]  # 🆕 Windows 运行时（待开发）
├── os/
│   └── windows.zig # Windows API 绑定（ConPTY、进程管理）
├── build/          # 构建系统配置
├── Surface.zig     # 终端 Surface 抽象（平台无关）
├── Command.zig     # 进程管理（含 startWindows）
└── main_c.zig      # libghostty C ABI 导出
dist/windows/       # Windows 资源文件（ico、manifest、rc）
include/ghostty.h   # C 嵌入 API 头文件
```

## 核心系统（概要）

- **终端仿真**: VT102 完整实现，支持 Kitty 图形 → 详见 `src/terminal/`
- **渲染引擎**: OpenGL 后端用于 Windows → 详见 `src/renderer/`
- **AppRuntime**: 平台适配层，Windows 版需新建 → 详见 `.claude/skills/apprt-windows.md`
- **Surface**: 平台无关的终端控件抽象 → 详见 `src/Surface.zig`
- **配置系统**: 10000+ 行，支持条件配置 → 详见 `src/config/`
- **Windows 基础**: ConPTY + 进程管理已实现 → 详见 `src/os/windows.zig`, `src/Command.zig`

## 版本控制

- 分支策略：`feature/windows-terminal-app` 为开发主分支
- 提交格式：`<type>(scope): description`，type = feat/fix/refactor/docs/test
- scope 常用值：apprt-win, renderer, surface, config, build, agent, sidebar, notify

## Claude Code 配置索引

### Rules（每次会话自动加载）
- `constitution.md` — 禁区宪法：不可修改的核心目录
- `golden-principles.md` — 黄金原则 + Agent 工作流
- `known-pitfalls.md` — 已知陷阱
- `zig-style.md` — Zig 编码规范

### Skills（按需加载）
- `apprt-windows.md` — Windows AppRuntime 开发指南
- `cmux-features.md` — cmux 功能借鉴参考

### Commands
- `/plan` — 规划先行
- `/verify` — 机械化检查
- `/review` — 代码审查
- `/fix-harness` — 出错改 Harness
