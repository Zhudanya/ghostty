---
description: "对当前代码变更进行机械化检查"
---

# /verify

## 检查流程
1. **Git 变更扫描** — 获取改动文件列表
2. **禁区检查** — 确认改动文件不在 constitution.md 禁区内
3. **禁用 API 检查** — grep golden-principles 里的每条禁止项：
   - `std.debug.print` 出现在非测试代码中
   - `@panic` 出现在非初始化代码中
   - 硬编码 `\\` 路径分隔符
   - 直接 Win32 API 调用不在 `os/windows.zig`
4. **平台隔离检查** — Windows 代码是否泄漏到核心层
5. **命名规范检查** — 新增类型/函数/文件命名
6. **Zig 格式检查** — `zig fmt --check` 改动文件
7. **Harness 更新完整性** — 有错误修复但 rules 无变更 → 警告
8. **Git Diff 摘要**

## 输出格式
```
验证报告: [PASS/FAIL]
[每项检查结果]
状态: [可以提交 / 需要修复]
```
