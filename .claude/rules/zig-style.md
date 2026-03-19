---
paths:
  - "src/**/*.zig"
---

# Zig 编码规范（Ghostty 项目）

## 格式
- 缩进：4 空格
- 行宽：无硬性限制，但建议 120 字符
- 提交前运行 `zig fmt` 格式化

## 错误处理
- 优先使用 error union `!T`
- `try` 传播错误，`catch` 处理可恢复错误
- 不可恢复错误才用 `@panic`（仅限初始化阶段）
- 资源清理用 `defer` / `errdefer`

## 内存管理
- 分配器通过参数传入，不使用全局分配器
- `defer allocator.free(...)` 紧跟分配语句
- 热路径避免分配，优先使用栈或 arena

## 测试
- 测试函数紧跟被测函数所在文件
- 测试命名：`test "descriptive name"`
- 使用 `std.testing.expect*` 系列断言

## 注释
- 公共函数写 doc comment（`///`）
- 复杂算法写行内注释解释"为什么"
- 禁止注释掉的代码提交
