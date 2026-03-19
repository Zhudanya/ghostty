---
paths:
  - "src/**/*.zig"
---

# 已知陷阱（真实 Agent 错误记录）

## Zig comptime 与 Windows 目标
- **错误**: 在非 Windows 构建中引用 `std.os.windows` 类型导致编译失败
- **正确**: 使用 `if (builtin.os.tag == .windows)` comptime 分支包裹所有 Windows API 调用

## Ghostty apprt 接口契约
- **错误**: 新增 apprt 时遗漏接口函数，导致 comptime 断言失败
- **正确**: 参考 `src/apprt/gtk/` 完整实现所有 `apprt.Runtime` 要求的接口

## build.zig 目标修改
- **错误**: 直接修改 build.zig 默认目标，影响其他平台构建
- **正确**: 通过 `-D` 选项添加 Windows 目标，不改变默认行为

## Windows ConPTY 生命周期
- **错误**: ConPTY handle 未正确关闭导致僵尸进程
- **正确**: 确保 `ClosePseudoConsole` 在 PTY 对象析构时调用，参考 `src/pty.zig` 中的 `WindowsPty.deinit`

## 待积累
<!-- 后续开发中遇到的陷阱将在此追加 -->
