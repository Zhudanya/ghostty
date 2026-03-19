---
paths:
  - "src/**/*.zig"
---

# 黄金原则（编码必须遵守）

## Zig 编码规范
- 使用 `std.log` 进行日志记录
- 禁止 `std.debug.print` 用于非调试代码
- 错误处理使用 Zig error union（`!T`），禁止忽略错误（`_ = try ...` 除外需注释理由）
- 内存分配使用传入的 `Allocator`，禁止全局分配器

## 平台隔离
- Windows 专有代码只放 `src/apprt/windows/` 和 `src/os/windows.zig`
- 禁止在 `src/terminal/`, `src/renderer/Generic.zig`, `src/font/` 中加 `@import("builtin").os.tag == .windows` 分支
- 平台差异通过 `apprt` 接口抽象，不在核心层 if-else

## 命名规范
- 文件名：snake_case.zig
- 类型：PascalCase
- 函数/变量：camelCase
- 常量：snake_case 或 SCREAMING_SNAKE_CASE

## 借鉴 cmux 的原则
- 新增 UI 功能先参考 cmux 对应实现（`../cmux/Sources/`）
- Socket API 命令格式尽量兼容 cmux 协议（便于 Agent 工具复用）
- 通知系统需同时支持 Windows Toast 和应用内通知（双通道）

## 禁用 API 速查

| 禁止 | 替代 |
|------|------|
| `std.debug.print`（非调试） | `std.log.info/warn/err` |
| 全局 allocator | 参数传入 `Allocator` |
| `@panic` 处理业务错误 | 返回 error |
| 硬编码 Windows 路径分隔符 `\\` | `std.fs.path` |
| 直接调用 Win32 API | 封装到 `src/os/windows.zig` |

## Agent 工作流

### 规划先行 [AI判断]
- 涉及多文件修改（>3 文件或跨模块），动手前必须先列出文件清单 + 改动意图
- 修改 Surface.zig 或 apprt 接口等跨平台文件，必须分析对其他平台的影响

### 出错自动改 Harness [AI判断]
- Agent 修改导致错误并修复后，必须自动执行 fix-harness 流程

### 阶段完成标记 [机械执行]
- 每个 Phase 开发完成后，必须输出 `========== Phase N COMPLETE ==========`
- 未输出 COMPLETE 视为该阶段未完成，不可进入下一阶段

### 提交和推送自动链
- 提交前：必须先执行 `/verify`
- 推送前：必须先执行 `/review`
- 完整链条：`编码 → /verify → commit → /review → push`

## [临时] Agent 约束
<!-- 过期日期: 2026-09-19 -->
<!-- 移除条件：Windows apprt 基础框架完成后 -->
- 每次会话优先完成一个完整的小功能，而非铺开多个半成品
- 新文件创建前先搜索是否已有类似文件可扩展
