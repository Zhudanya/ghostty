---
description: "Agent 犯错后更新 Harness"
---

# /fix-harness

## 路由表

| 错误类型 | 应该更新的文件 |
|---------|-------------|
| 违反禁区 | .claude/rules/constitution.md |
| 编码原则违反 | .claude/rules/golden-principles.md |
| 已知陷阱再犯 | .claude/rules/known-pitfalls.md |
| Zig 风格问题 | .claude/rules/zig-style.md |
| 架构边界违反 | ARCHITECTURE.md |
| Windows 特有问题 | .claude/skills/apprt-windows.md |

## 执行流程
1. 分析根因
2. 按路由表更新对应文件
3. 如果能机械化验证，同步添加到 /verify
4. `wc -l .claude/rules/*.md` 确认 ≤ 550，超出则同时精简
5. 检查过期的临时约束
6. 输出 Harness 更新报告
