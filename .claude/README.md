# Claude Code 配置说明

## 目录结构

```
.claude/
├── rules/                  # 核心规则（自动加载）
│   ├── constitution.md     # 禁区宪法
│   ├── golden-principles.md # 黄金原则 + Agent 工作流
│   ├── known-pitfalls.md   # 已知陷阱
│   └── zig-style.md        # Zig 编码规范
├── skills/                 # 按需加载的知识模块
│   ├── apprt-windows.md    # Windows AppRuntime 开发指南
│   └── cmux-features.md    # cmux 功能借鉴参考
├── commands/               # 自定义命令
│   ├── plan.md             # /plan — 规划先行
│   ├── verify.md           # /verify — 机械化检查
│   ├── review.md           # /review — 代码审查
│   └── fix-harness.md      # /fix-harness — 出错改 Harness
├── hooks/                  # 自动化 hook 脚本
│   ├── constitution-guard.sh  # 禁区拦截
│   ├── push-gate.sh          # Push 门禁
│   └── post-commit-review.sh # Commit 后提醒
└── docs/
    ├── exec-plans/         # 执行计划
    │   ├── active/         # 进行中
    │   └── completed/      # 已完成
    └── design-docs/        # 架构决策文档
```

## 工作流

1. 新任务 → `/plan` → 用户确认 → 编码
2. 编码完成 → `/verify` → 修复问题 → `git commit`
3. 准备推送 → `/review` → 通过 → `git push`
4. 犯错修复 → 自动 `/fix-harness` → 更新 rules
