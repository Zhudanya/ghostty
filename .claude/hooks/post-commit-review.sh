#!/bin/bash
# Commit 后提醒执行 review
# 事件: PostToolUse Bash (匹配 git commit)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -q "git commit"; then
  jq -n '{"systemMessage": "Commit 完成。推送前必须执行 /review。"}'
fi

exit 0
