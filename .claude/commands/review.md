---
description: "代码审查：架构合规 + 编码规范 + 逻辑审查 + Harness 完整性"
---

# /review

## 检查层次
1. **前置** — 先跑 /verify，未通过则直接 FAIL
2. **架构合规** [机械+AI]
   - 禁区是否被修改
   - 分层依赖方向是否正确（下层不依赖上层）
   - Windows 代码是否隔离在 apprt/windows/ 和 os/windows.zig
3. **编码规范** [机械+AI]
   - 逐条对照 golden-principles 和 zig-style
   - 错误处理是否完整（defer/errdefer）
4. **逻辑审查** [AI判断]
   - 与 cmux 对应功能的一致性
   - 命名意图、边界情况、冗余代码、副作用、性能
   - 跨平台兼容性
5. **Harness 完整性** [机械+AI]
   - 有修复是否更新了 rules

## PASS 后操作
- 创建 `.claude/push-approved` 标记文件
- 输出"审查通过，可以 push"

## 严重度
- CRITICAL: 阻断，必须修复
- HIGH: 强烈建议修复，累计 3 个以上则 FAIL
- MEDIUM: 建议改进，不阻断
