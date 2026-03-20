const std = @import("std");
const windows = std.os.windows;

// Export any constants or functions we need from the Windows API so
// we can just import one file.
pub const kernel32 = windows.kernel32;
pub const unexpectedError = windows.unexpectedError;
pub const OpenFile = windows.OpenFile;
pub const CloseHandle = windows.CloseHandle;
pub const GetCurrentProcessId = windows.GetCurrentProcessId;
pub const SetHandleInformation = windows.SetHandleInformation;
pub const DWORD = windows.DWORD;
pub const FILE_ATTRIBUTE_NORMAL = windows.FILE_ATTRIBUTE_NORMAL;
pub const FILE_FLAG_OVERLAPPED = windows.FILE_FLAG_OVERLAPPED;
pub const FILE_SHARE_READ = windows.FILE_SHARE_READ;
pub const GENERIC_READ = windows.GENERIC_READ;
pub const HANDLE = windows.HANDLE;
pub const HANDLE_FLAG_INHERIT = windows.HANDLE_FLAG_INHERIT;
pub const INFINITE = windows.INFINITE;
pub const INVALID_HANDLE_VALUE = windows.INVALID_HANDLE_VALUE;
pub const OPEN_EXISTING = windows.OPEN_EXISTING;
pub const PIPE_ACCESS_OUTBOUND = windows.PIPE_ACCESS_OUTBOUND;
pub const PIPE_TYPE_BYTE = windows.PIPE_TYPE_BYTE;
pub const PROCESS_INFORMATION = windows.PROCESS_INFORMATION;
pub const S_OK = windows.S_OK;
pub const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
pub const STARTUPINFOW = windows.STARTUPINFOW;
pub const STARTF_USESTDHANDLES = windows.STARTF_USESTDHANDLES;
pub const SYNCHRONIZE = windows.SYNCHRONIZE;
pub const WAIT_FAILED = windows.WAIT_FAILED;
pub const FALSE = windows.FALSE;
pub const TRUE = windows.TRUE;

pub const exp = struct {
    pub const HPCON = windows.LPVOID;

    pub const CREATE_UNICODE_ENVIRONMENT = 0x00000400;
    pub const EXTENDED_STARTUPINFO_PRESENT = 0x00080000;
    pub const LPPROC_THREAD_ATTRIBUTE_LIST = ?*anyopaque;
    pub const FILE_FLAG_FIRST_PIPE_INSTANCE = 0x00080000;

    pub const STATUS_PENDING = 0x00000103;
    pub const STILL_ACTIVE = STATUS_PENDING;

    pub const STARTUPINFOEX = extern struct {
        StartupInfo: windows.STARTUPINFOW,
        lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
    };

    pub const kernel32 = struct {
        pub extern "kernel32" fn CreatePipe(
            hReadPipe: *windows.HANDLE,
            hWritePipe: *windows.HANDLE,
            lpPipeAttributes: ?*const windows.SECURITY_ATTRIBUTES,
            nSize: windows.DWORD,
        ) callconv(.winapi) windows.BOOL;
        pub extern "kernel32" fn CreatePseudoConsole(
            size: windows.COORD,
            hInput: windows.HANDLE,
            hOutput: windows.HANDLE,
            dwFlags: windows.DWORD,
            phPC: *HPCON,
        ) callconv(.winapi) windows.HRESULT;
        pub extern "kernel32" fn ResizePseudoConsole(hPC: HPCON, size: windows.COORD) callconv(.winapi) windows.HRESULT;
        pub extern "kernel32" fn ClosePseudoConsole(hPC: HPCON) callconv(.winapi) void;
        pub extern "kernel32" fn InitializeProcThreadAttributeList(
            lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
            dwAttributeCount: windows.DWORD,
            dwFlags: windows.DWORD,
            lpSize: *windows.SIZE_T,
        ) callconv(.winapi) windows.BOOL;
        pub extern "kernel32" fn UpdateProcThreadAttribute(
            lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST,
            dwFlags: windows.DWORD,
            Attribute: windows.DWORD_PTR,
            lpValue: windows.PVOID,
            cbSize: windows.SIZE_T,
            lpPreviousValue: ?windows.PVOID,
            lpReturnSize: ?*windows.SIZE_T,
        ) callconv(.winapi) windows.BOOL;
        pub extern "kernel32" fn PeekNamedPipe(
            hNamedPipe: windows.HANDLE,
            lpBuffer: ?windows.LPVOID,
            nBufferSize: windows.DWORD,
            lpBytesRead: ?*windows.DWORD,
            lpTotalBytesAvail: ?*windows.DWORD,
            lpBytesLeftThisMessage: ?*windows.DWORD,
        ) callconv(.winapi) windows.BOOL;
        // Duplicated here because lpCommandLine is not marked optional in zig std
        pub extern "kernel32" fn CreateProcessW(
            lpApplicationName: ?windows.LPWSTR,
            lpCommandLine: ?windows.LPWSTR,
            lpProcessAttributes: ?*windows.SECURITY_ATTRIBUTES,
            lpThreadAttributes: ?*windows.SECURITY_ATTRIBUTES,
            bInheritHandles: windows.BOOL,
            dwCreationFlags: windows.DWORD,
            lpEnvironment: ?*anyopaque,
            lpCurrentDirectory: ?windows.LPWSTR,
            lpStartupInfo: *windows.STARTUPINFOW,
            lpProcessInformation: *windows.PROCESS_INFORMATION,
        ) callconv(.winapi) windows.BOOL;
        /// https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getcomputernamea
        pub extern "kernel32" fn GetComputerNameA(
            lpBuffer: windows.LPSTR,
            nSize: *windows.DWORD,
        ) callconv(.winapi) windows.BOOL;
    };

    pub const PROC_THREAD_ATTRIBUTE_NUMBER = 0x0000FFFF;
    pub const PROC_THREAD_ATTRIBUTE_THREAD = 0x00010000;
    pub const PROC_THREAD_ATTRIBUTE_INPUT = 0x00020000;
    pub const PROC_THREAD_ATTRIBUTE_ADDITIVE = 0x00040000;

    pub const ProcThreadAttributeNumber = enum(windows.DWORD) {
        ProcThreadAttributePseudoConsole = 22,
        _,
    };

    /// Corresponds to the ProcThreadAttributeValue define in WinBase.h
    pub fn ProcThreadAttributeValue(
        comptime attribute: ProcThreadAttributeNumber,
        comptime thread: bool,
        comptime input: bool,
        comptime additive: bool,
    ) windows.DWORD {
        return (@intFromEnum(attribute) & PROC_THREAD_ATTRIBUTE_NUMBER) |
            (if (thread) PROC_THREAD_ATTRIBUTE_THREAD else 0) |
            (if (input) PROC_THREAD_ATTRIBUTE_INPUT else 0) |
            (if (additive) PROC_THREAD_ATTRIBUTE_ADDITIVE else 0);
    }

    pub const PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE = ProcThreadAttributeValue(.ProcThreadAttributePseudoConsole, false, true, false);

    // ── Win32 GUI types ──────────────────────────────────────────────
    pub const HWND = windows.HWND;
    pub const HINSTANCE = windows.HINSTANCE;
    pub const HDC = *anyopaque;
    pub const HGLRC = *anyopaque;
    pub const HMENU = *anyopaque;
    pub const HICON = *anyopaque;
    pub const HCURSOR = *anyopaque;
    pub const HBRUSH = *anyopaque;
    pub const ATOM = u16;
    pub const UINT = u32;
    pub const WPARAM = usize;
    pub const LPARAM = isize;
    pub const LRESULT = isize;
    pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

    pub const POINT = extern struct { x: i32, y: i32 };
    pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };

    pub const MSG = extern struct {
        hwnd: ?HWND,
        message: UINT,
        wParam: WPARAM,
        lParam: LPARAM,
        time: DWORD,
        pt: POINT,
    };

    pub const WNDCLASSEXW = extern struct {
        cbSize: UINT = @sizeOf(WNDCLASSEXW),
        style: UINT = 0,
        lpfnWndProc: WNDPROC,
        cbClsExtra: i32 = 0,
        cbWndExtra: i32 = 0,
        hInstance: ?HINSTANCE = null,
        hIcon: ?HICON = null,
        hCursor: ?HCURSOR = null,
        hbrBackground: ?HBRUSH = null,
        lpszMenuName: ?[*:0]const u16 = null,
        lpszClassName: [*:0]const u16,
        hIconSm: ?HICON = null,
    };

    pub const PIXELFORMATDESCRIPTOR = extern struct {
        nSize: u16 = @sizeOf(PIXELFORMATDESCRIPTOR),
        nVersion: u16 = 1,
        dwFlags: DWORD = 0,
        iPixelType: u8 = 0,
        cColorBits: u8 = 0,
        cRedBits: u8 = 0,
        cRedShift: u8 = 0,
        cGreenBits: u8 = 0,
        cGreenShift: u8 = 0,
        cBlueBits: u8 = 0,
        cBlueShift: u8 = 0,
        cAlphaBits: u8 = 0,
        cAlphaShift: u8 = 0,
        cAccumBits: u8 = 0,
        cAccumRedBits: u8 = 0,
        cAccumGreenBits: u8 = 0,
        cAccumBlueBits: u8 = 0,
        cAccumAlphaBits: u8 = 0,
        cDepthBits: u8 = 0,
        cStencilBits: u8 = 0,
        cAuxBuffers: u8 = 0,
        iLayerType: u8 = 0,
        bReserved: u8 = 0,
        dwLayerMask: DWORD = 0,
        dwVisibleMask: DWORD = 0,
        dwDamageMask: DWORD = 0,
    };

    // Window style constants
    pub const WS_OVERLAPPEDWINDOW = 0x00CF0000;
    pub const WS_VISIBLE = 0x10000000;
    pub const CW_USEDEFAULT: i32 = @bitCast(@as(u32, 0x80000000));

    // Window message constants
    pub const WM_DESTROY = 0x0002;
    pub const WM_SIZE = 0x0005;
    pub const WM_PAINT = 0x000F;
    pub const WM_CLOSE = 0x0010;
    pub const WM_QUIT = 0x0012;
    pub const WM_KEYDOWN = 0x0100;
    pub const WM_KEYUP = 0x0101;
    pub const WM_CHAR = 0x0102;
    pub const WM_SYSCOMMAND = 0x0112;
    pub const WM_TIMER = 0x0113;
    pub const WM_MOUSEMOVE = 0x0200;
    pub const WM_LBUTTONDOWN = 0x0201;
    pub const WM_LBUTTONUP = 0x0202;
    pub const WM_RBUTTONDOWN = 0x0204;
    pub const WM_RBUTTONUP = 0x0205;
    pub const WM_MBUTTONDOWN = 0x0207;
    pub const WM_MBUTTONUP = 0x0208;
    pub const WM_MOUSEWHEEL = 0x020A;
    pub const WM_MOUSEHWHEEL = 0x020E;
    pub const WM_IME_STARTCOMPOSITION = 0x010D;
    pub const WM_IME_ENDCOMPOSITION = 0x010E;
    pub const WM_IME_COMPOSITION = 0x010F;
    pub const WM_DPICHANGED = 0x02E0;

    // Mouse key state flags (in wParam of mouse messages)
    pub const MK_LBUTTON = 0x0001;
    pub const MK_RBUTTON = 0x0002;
    pub const MK_SHIFT = 0x0004;
    pub const MK_CONTROL = 0x0008;
    pub const MK_MBUTTON = 0x0010;

    // IME composition flags
    pub const GCS_RESULTSTR: windows.DWORD = 0x0800;
    pub const GCS_COMPSTR: windows.DWORD = 0x0008;

    // PeekMessage flags
    pub const PM_REMOVE = 0x0001;

    // Pixel format flags
    pub const PFD_DRAW_TO_WINDOW = 0x00000004;
    pub const PFD_SUPPORT_OPENGL = 0x00000020;
    pub const PFD_DOUBLEBUFFER = 0x00000001;
    pub const PFD_TYPE_RGBA = 0;
    pub const PFD_MAIN_PLANE = 0;

    // Timer
    pub const USER_TIMER_MINIMUM = 0x0000000A;

    // ── user32.dll ───────────────────────────────────────────────────
    pub const user32 = struct {
        pub extern "user32" fn RegisterClassExW(lpwcx: *const WNDCLASSEXW) callconv(.winapi) ATOM;
        pub extern "user32" fn CreateWindowExW(
            dwExStyle: DWORD,
            lpClassName: [*:0]const u16,
            lpWindowName: [*:0]const u16,
            dwStyle: DWORD,
            x: i32,
            y: i32,
            nWidth: i32,
            nHeight: i32,
            hWndParent: ?HWND,
            hMenu: ?HMENU,
            hInstance: ?HINSTANCE,
            lpParam: ?*anyopaque,
        ) callconv(.winapi) ?HWND;
        pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn DefWindowProcW(hWnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
        pub extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
        pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.winapi) void;
        pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: [*:0]const u16) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(.winapi) ?HDC;
        pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.winapi) i32;
        pub extern "user32" fn GetKeyState(nVirtKey: i32) callconv(.winapi) i16;
        pub extern "user32" fn SetTimer(hWnd: ?HWND, nIDEvent: usize, uElapse: UINT, lpTimerFunc: ?*anyopaque) callconv(.winapi) usize;
        pub extern "user32" fn KillTimer(hWnd: ?HWND, uIDEvent: usize) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn InvalidateRect(hWnd: ?HWND, lpRect: ?*const RECT, bErase: windows.BOOL) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn GetDpiForWindow(hWnd: HWND) callconv(.winapi) UINT;
        pub extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: usize) callconv(.winapi) ?HCURSOR;
    };

    // ── gdi32.dll ────────────────────────────────────────────────────
    pub const gdi32 = struct {
        pub extern "gdi32" fn ChoosePixelFormat(hdc: HDC, ppfd: *const PIXELFORMATDESCRIPTOR) callconv(.winapi) i32;
        pub extern "gdi32" fn SetPixelFormat(hdc: HDC, format: i32, ppfd: *const PIXELFORMATDESCRIPTOR) callconv(.winapi) windows.BOOL;
        pub extern "gdi32" fn SwapBuffers(hdc: HDC) callconv(.winapi) windows.BOOL;
    };

    // ── opengl32.dll ─────────────────────────────────────────────────
    pub const opengl32 = struct {
        pub extern "opengl32" fn wglCreateContext(hdc: HDC) callconv(.winapi) ?HGLRC;
        pub extern "opengl32" fn wglMakeCurrent(hdc: ?HDC, hglrc: ?HGLRC) callconv(.winapi) windows.BOOL;
        pub extern "opengl32" fn wglDeleteContext(hglrc: HGLRC) callconv(.winapi) windows.BOOL;
        pub extern "opengl32" fn wglShareLists(hglrc1: HGLRC, hglrc2: HGLRC) callconv(.winapi) windows.BOOL;
        pub extern "opengl32" fn wglGetProcAddress(lpszProc: [*:0]const u8) callconv(.winapi) ?*anyopaque;
    };

    // ── Event / Wait ─────────────────────────────────────────────────
    pub const WAIT_OBJECT_0: windows.DWORD = 0;
    pub const QS_ALLINPUT: windows.DWORD = 0x04FF;

    pub extern "kernel32" fn CreateEventW(
        lpEventAttributes: ?*anyopaque,
        bManualReset: windows.BOOL,
        bInitialState: windows.BOOL,
        lpName: ?[*:0]const u16,
    ) callconv(.winapi) ?windows.HANDLE;
    pub extern "kernel32" fn SetEvent(hEvent: windows.HANDLE) callconv(.winapi) windows.BOOL;
    pub extern "kernel32" fn ResetEvent(hEvent: windows.HANDLE) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn MsgWaitForMultipleObjects(
        nCount: windows.DWORD,
        pHandles: ?[*]const windows.HANDLE,
        bWaitAll: windows.BOOL,
        dwMilliseconds: windows.DWORD,
        dwWakeMask: windows.DWORD,
    ) callconv(.winapi) windows.DWORD;

    // ── Clipboard ─────────────────────────────────────────────────────
    pub const CF_UNICODETEXT: UINT = 13;
    pub const GMEM_MOVEABLE: UINT = 0x0002;

    pub extern "user32" fn OpenClipboard(hWndNewOwner: ?HWND) callconv(.winapi) windows.BOOL;
    pub extern "user32" fn CloseClipboard() callconv(.winapi) windows.BOOL;
    pub extern "user32" fn EmptyClipboard() callconv(.winapi) windows.BOOL;
    pub extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.winapi) ?windows.HANDLE;
    pub extern "user32" fn SetClipboardData(uFormat: UINT, hMem: windows.HANDLE) callconv(.winapi) ?windows.HANDLE;
    pub extern "kernel32" fn GlobalAlloc(uFlags: UINT, dwBytes: usize) callconv(.winapi) ?windows.HANDLE;
    pub extern "kernel32" fn GlobalLock(hMem: windows.HANDLE) callconv(.winapi) ?[*]u8;
    pub extern "kernel32" fn GlobalUnlock(hMem: windows.HANDLE) callconv(.winapi) windows.BOOL;
    pub extern "kernel32" fn GlobalFree(hMem: windows.HANDLE) callconv(.winapi) ?windows.HANDLE;

    // ── Mouse ─────────────────────────────────────────────────────────
    pub const WHEEL_DELTA: i16 = 120;

    pub const user32_ext = struct {
        pub extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn ScreenToClient(hWnd: HWND, lpPoint: *POINT) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn MessageBeep(uType: UINT) callconv(.winapi) windows.BOOL;
        pub extern "user32" fn SetCapture(hWnd: HWND) callconv(.winapi) ?HWND;
        pub extern "user32" fn ReleaseCapture() callconv(.winapi) windows.BOOL;
    };

    pub const user32_ext2 = struct {
        pub extern "user32" fn SetWindowPos(
            hWnd: HWND,
            hWndInsertAfter: ?HWND,
            X: i32,
            Y: i32,
            cx: i32,
            cy: i32,
            uFlags: UINT,
        ) callconv(.winapi) windows.BOOL;
    };

    // ── IME (imm32.dll) ──────────────────────────────────────────────
    pub const HIMC = ?*anyopaque;

    pub const imm32 = struct {
        pub extern "imm32" fn ImmGetContext(hWnd: HWND) callconv(.winapi) HIMC;
        pub extern "imm32" fn ImmReleaseContext(hWnd: HWND, hIMC: HIMC) callconv(.winapi) windows.BOOL;
        pub extern "imm32" fn ImmGetCompositionStringW(hIMC: HIMC, dwIndex: windows.DWORD, lpBuf: ?[*]u8, dwBufLen: windows.DWORD) callconv(.winapi) i32;
    };

    // ── Helpers ───────────────────────────────────────────────────────

    /// Extract wheel delta from WM_MOUSEWHEEL wParam (high word, signed).
    pub inline fn GET_WHEEL_DELTA_WPARAM(wParam: WPARAM) i16 {
        return @bitCast(@as(u16, @truncate(wParam >> 16)));
    }

    /// Extract x coordinate from lParam (low word, signed).
    pub inline fn GET_X_LPARAM(lParam: LPARAM) i16 {
        return @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lParam)))));
    }

    /// Extract y coordinate from lParam (high word, signed).
    pub inline fn GET_Y_LPARAM(lParam: LPARAM) i16 {
        return @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lParam)) >> 16)));
    }

    // IDC_ARROW = 32512
    pub const IDC_ARROW: usize = 32512;
    // SW_SHOW = 5
    pub const SW_SHOW: i32 = 5;
};
