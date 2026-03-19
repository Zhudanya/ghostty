---
paths:
  - "src/**/*.zig"
  - "include/**"
  - "dist/**"
---

# 禁区宪法（违反即错误）

## 核心终端引擎（只读参考，不可修改）
- `src/terminal/` — 终端仿真核心，修改需充分理解 VT 协议
- `src/renderer/Generic.zig` — 通用渲染逻辑，影响所有平台
- `src/renderer/Metal.zig` — macOS 专用，Windows 开发不应触碰
- `src/Surface.zig` — Surface 抽象层，修改影响所有平台，需用户确认

## 其他平台运行时
- `src/apprt/gtk/` — Linux GTK 运行时，仅作参考模板，不可修改
- `src/apprt/embedded.zig` — macOS 嵌入运行时，不可修改
- `src/apprt/browser.zig` — WASM 运行时，不可修改

## C ABI 接口
- `include/ghostty.h` — 公共 C ABI，修改影响所有下游嵌入方，需用户确认
- `src/main_c.zig` — C ABI 实现，修改需用户确认

## 构建系统核心
- `build.zig` — 顶层构建文件，可扩展但需用户确认
- `build.zig.zon` — 包依赖声明，修改需用户确认

## 第三方与生成代码
- `vendor/` — 第三方依赖，不可直接修改
- `src/font/nerd_font_attributes.zig` — 自动生成，修改方式：运行 `nerd_font_codepoint_tables.py`

## 可修改区域（Windows 开发）
以下目录是 Windows 开发的主要工作区：
- `src/apprt/windows/` — 🆕 Windows 运行时（新建）
- `src/apprt/runtime.zig` — 需扩展 Windows 运行时选项（需确认）
- `src/apprt/action.zig` — 可能需扩展 Windows 特有动作
- `src/os/windows.zig` — 可扩展 Windows API 绑定
- `src/renderer/OpenGL.zig` — 可能需 Windows 特定调整
- `src/build/` — 构建配置扩展
- `dist/windows/` — Windows 资源文件

## 遇到禁区 Bug 的处理
1. 告知用户根因在哪个禁区
2. 如果能在 `src/apprt/windows/` 中规避：提供 WORKAROUND 方案
3. 如果无法规避：只做分析，不动代码
