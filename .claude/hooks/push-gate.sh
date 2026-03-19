#!/bin/bash
# Push 门禁 — 检查 push-approved 标记
# 事件: PreToolUse Bash (匹配 git push)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -q "git push"; then
  if [ -f ".claude/push-approved" ]; then
    rm -f ".claude/push-approved"
    exit 0
  else
    echo "PUSH BLOCKED: 请先执行 /review 获得推送授权" >&2
    exit 2
  fi
fi

exit 0
