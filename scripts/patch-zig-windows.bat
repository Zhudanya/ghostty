@echo off
REM Patch Zig 0.15.x standard library for Windows build compatibility.
REM
REM Usage:
REM   scripts\patch-zig-windows.bat [ZIG_LIB_DIR]
REM
REM If ZIG_LIB_DIR is not provided, auto-detects from `zig env`.

setlocal enabledelayedexpansion

if "%~1"=="" (
    for /f "delims=" %%i in ('zig env 2^>nul ^| python -c "import sys,json; print(json.load(sys.stdin)['lib_dir'])" 2^>nul') do set ZIG_LIB=%%i
    if "!ZIG_LIB!"=="" (
        for /f "delims=" %%i in ('zig env 2^>nul ^| python3 -c "import sys,json; print(json.load(sys.stdin)['lib_dir'])" 2^>nul') do set ZIG_LIB=%%i
    )
    if "!ZIG_LIB!"=="" (
        echo ERROR: Cannot detect Zig lib directory. Pass it as argument.
        echo Usage: %0 ^<path-to-zig-lib^>
        exit /b 1
    )
) else (
    set ZIG_LIB=%~1
)

set RUN_ZIG=%ZIG_LIB%\std\Build\Step\Run.zig

if not exist "%RUN_ZIG%" (
    echo ERROR: %RUN_ZIG% not found
    exit /b 1
)

findstr /c:"GHOSTTY-WIN-PATCH" "%RUN_ZIG%" >nul 2>&1
if %errorlevel%==0 (
    echo Already patched. Skipping.
    goto :done
)

findstr /c:"assert(!std.fs.path.isAbsolute(child_cwd_rel));" "%RUN_ZIG%" >nul 2>&1
if %errorlevel%==1 (
    echo WARNING: Could not find expected assert in %RUN_ZIG%
    echo Zig version may differ from 0.15.x. Manual patching may be needed.
    exit /b 1
)

echo Patching %RUN_ZIG% ...
powershell -Command "(Get-Content '%RUN_ZIG%') -replace 'assert\(!std\.fs\.path\.isAbsolute\(child_cwd_rel\)\);', '// [GHOSTTY-WIN-PATCH] On Windows, relative() can return absolute path across drives.`n    if (std.fs.path.isAbsolute(child_cwd_rel)) return child_cwd_rel;' | Set-Content '%RUN_ZIG%'"

if %errorlevel%==0 (
    echo Patch applied successfully.
) else (
    echo ERROR: Patch failed.
    exit /b 1
)

:done
echo.
echo Done. You can now build with: zig build -Dapp-runtime=windows
