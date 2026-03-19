#!/bin/bash
# Patch Zig 0.15.x standard library for Windows build compatibility.
#
# Zig 0.15.2 has a bug where std.Build.Step.Run.convertPathArg() asserts
# that a relative path result is not absolute. On Windows, when paths are
# on different drives, std.fs.path.relative() can return an absolute path,
# triggering the assertion. This patch replaces the assert with a graceful
# fallback.
#
# Usage:
#   ./scripts/patch-zig-windows.sh [ZIG_LIB_DIR]
#
# If ZIG_LIB_DIR is not provided, it will be auto-detected from `zig env`.

set -e

# Find Zig lib directory
if [ -n "$1" ]; then
    ZIG_LIB="$1"
else
    ZIG_LIB=$(zig env 2>/dev/null | python -c "import sys,json; print(json.load(sys.stdin)['lib_dir'])" 2>/dev/null || \
              zig env 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['lib_dir'])" 2>/dev/null || \
              echo "")
    if [ -z "$ZIG_LIB" ]; then
        echo "ERROR: Cannot detect Zig lib directory. Pass it as argument."
        echo "Usage: $0 <path-to-zig-lib>"
        exit 1
    fi
fi

RUN_ZIG="$ZIG_LIB/std/Build/Step/Run.zig"

if [ ! -f "$RUN_ZIG" ]; then
    echo "ERROR: $RUN_ZIG not found"
    exit 1
fi

# Check if already patched (check marker FIRST, before checking assert)
if grep -q "GHOSTTY-WIN-PATCH" "$RUN_ZIG" 2>/dev/null; then
    echo "Already patched. Skipping."
elif grep -q "assert(!std.fs.path.isAbsolute(child_cwd_rel));" "$RUN_ZIG" 2>/dev/null; then
    echo "Patching $RUN_ZIG ..."

    # Replace the assert with a graceful fallback
    sed -i 's/assert(!std.fs.path.isAbsolute(child_cwd_rel));/\/\/ [GHOSTTY-WIN-PATCH] On Windows, relative() can return absolute path across drives.\n    if (std.fs.path.isAbsolute(child_cwd_rel)) return child_cwd_rel;/' "$RUN_ZIG"

    echo "Patch applied successfully."
else
    echo "WARNING: Could not find expected assert in $RUN_ZIG"
    echo "Zig version may differ from 0.15.x. Manual patching may be needed."
    exit 1
fi

echo ""
echo "Done. You can now build with: zig build -Dapp-runtime=windows"
