#!/bin/bash
# 禁区拦截 hook — 阻止修改受保护的核心文件
# 事件: PreToolUse Edit|Write

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.file // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 获取相对路径
REL_PATH=$(realpath --relative-to="$(pwd)" "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

BLOCKED=false
REASON=""

# 核心终端引擎
case "$REL_PATH" in
  src/terminal/*)
    BLOCKED=true
    REASON="核心终端仿真引擎"
    ;;
  src/renderer/Generic.zig)
    BLOCKED=true
    REASON="通用渲染逻辑，影响所有平台"
    ;;
  src/renderer/Metal.zig)
    BLOCKED=true
    REASON="macOS 专用渲染器"
    ;;
  src/apprt/gtk/*)
    BLOCKED=true
    REASON="Linux GTK 运行时（仅参考，不可修改）"
    ;;
  src/apprt/embedded.zig)
    BLOCKED=true
    REASON="macOS 嵌入运行时"
    ;;
  src/apprt/browser.zig)
    BLOCKED=true
    REASON="WASM 运行时"
    ;;
  vendor/*)
    BLOCKED=true
    REASON="第三方依赖"
    ;;
  src/font/nerd_font_attributes.zig)
    BLOCKED=true
    REASON="自动生成文件"
    ;;
esac

if [ "$BLOCKED" = "true" ]; then
  echo "CONSTITUTION VIOLATION: $REL_PATH — $REASON" >&2
  exit 2
fi

exit 0
