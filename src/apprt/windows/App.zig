/// Windows apprt App implementation.
/// Provides a Win32 window with OpenGL context and message loop for Ghostty.
const App = @This();

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const configpkg = @import("../../config.zig");
const input = @import("../../input.zig");
const input_key = @import("../../input/key.zig");
const CoreApp = @import("../../App.zig");
const CoreSurface = @import("../../Surface.zig");
const Surface = @import("Surface.zig");
const key = @import("key.zig");
const win32 = @import("../../os/windows.zig").exp;

const log = std.log.scoped(.windows);

/// WGL context must be on the same thread that created it.
pub const must_draw_from_app_thread = true;

/// Core app reference
core_app: *CoreApp,

/// The single surface for Phase 1
surface: ?*Surface = null,

/// Win32 window handle
hwnd: ?win32.HWND = null,

/// Device context for OpenGL
hdc: ?win32.HDC = null,

/// OpenGL rendering context
hglrc: ?win32.HGLRC = null,

/// Whether the app is still running
running: bool = true,

/// Render timer ID
render_timer: usize = 0,

/// Global pointer for WndProc callback (WndProc is a C callback, no context)
var g_app: ?*App = null;

const CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWindowClass");
const WINDOW_TITLE = std.unicode.utf8ToUtf16LeStringLiteral("Ghostty");
const RENDER_TIMER_ID: usize = 1;
const RENDER_INTERVAL_MS: u32 = 16; // ~60 FPS

pub fn init(
    self: *App,
    core_app: *CoreApp,
    opts: struct {},
) !void {
    _ = opts;
    self.* = .{
        .core_app = core_app,
    };
    g_app = self;

    // Register window class
    const wc = win32.WNDCLASSEXW{
        .lpfnWndProc = wndProc,
        .hInstance = null,
        .hCursor = win32.user32.LoadCursorW(null, win32.IDC_ARROW),
        .lpszClassName = CLASS_NAME,
    };

    if (win32.user32.RegisterClassExW(&wc) == 0) {
        log.err("RegisterClassExW failed", .{});
        return error.WindowClassRegistrationFailed;
    }

    // Create window
    self.hwnd = win32.user32.CreateWindowExW(
        0, // dwExStyle
        CLASS_NAME,
        WINDOW_TITLE,
        win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
        win32.CW_USEDEFAULT, // x
        win32.CW_USEDEFAULT, // y
        1024, // width
        768, // height
        null, // parent
        null, // menu
        null, // hInstance
        null, // lpParam
    );

    if (self.hwnd == null) {
        log.err("CreateWindowExW failed", .{});
        return error.WindowCreationFailed;
    }

    // Setup OpenGL context
    try self.initOpenGL();

    // Show window
    _ = win32.user32.ShowWindow(self.hwnd.?, win32.SW_SHOW);
    _ = win32.user32.UpdateWindow(self.hwnd.?);

    // Start render timer (~60fps)
    self.render_timer = win32.user32.SetTimer(self.hwnd, RENDER_TIMER_ID, RENDER_INTERVAL_MS, null);

    log.info("Windows apprt initialized: hwnd={*}", .{self.hwnd.?});
}

fn initOpenGL(self: *App) !void {
    self.hdc = win32.user32.GetDC(self.hwnd);
    if (self.hdc == null) {
        log.err("GetDC failed", .{});
        return error.GetDCFailed;
    }

    // Setup pixel format for OpenGL
    var pfd = win32.PIXELFORMATDESCRIPTOR{
        .dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL | win32.PFD_DOUBLEBUFFER,
        .iPixelType = win32.PFD_TYPE_RGBA,
        .cColorBits = 32,
        .cDepthBits = 24,
        .cStencilBits = 8,
        .iLayerType = win32.PFD_MAIN_PLANE,
    };

    const pixel_format = win32.gdi32.ChoosePixelFormat(self.hdc.?, &pfd);
    if (pixel_format == 0) {
        log.err("ChoosePixelFormat failed", .{});
        return error.ChoosePixelFormatFailed;
    }

    if (win32.gdi32.SetPixelFormat(self.hdc.?, pixel_format, &pfd) == 0) {
        log.err("SetPixelFormat failed", .{});
        return error.SetPixelFormatFailed;
    }

    // Create OpenGL context
    self.hglrc = win32.opengl32.wglCreateContext(self.hdc.?);
    if (self.hglrc == null) {
        log.err("wglCreateContext failed", .{});
        return error.WglCreateContextFailed;
    }

    if (win32.opengl32.wglMakeCurrent(self.hdc, self.hglrc) == 0) {
        log.err("wglMakeCurrent failed", .{});
        return error.WglMakeCurrentFailed;
    }

    log.info("OpenGL context created successfully", .{});
}

pub fn run(self: *App) !void {
    log.info("entering Win32 message loop", .{});

    // Create the initial terminal surface
    const alloc = self.core_app.alloc;
    var surface = try alloc.create(Surface);
    errdefer alloc.destroy(surface);
    try surface.init(self);
    self.surface = surface;

    log.info("terminal surface created, starting message loop", .{});

    // Main message loop
    var msg: win32.MSG = undefined;
    while (self.running) {
        // Process all pending messages
        while (win32.user32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            if (msg.message == win32.WM_QUIT) {
                self.running = false;
                break;
            }
            _ = win32.user32.TranslateMessage(&msg);
            _ = win32.user32.DispatchMessageW(&msg);
        }

        if (!self.running) break;

        // Tick core app (drains mailbox, processes surface messages)
        self.core_app.tick(self) catch |err| {
            log.err("core_app.tick error: {}", .{err});
        };

        // Rendering is driven by the renderer thread sending redraw_surface
        // messages, handled by performAction(.render) which calls drawFrame + SwapBuffers.

        // Sleep briefly to avoid busy-spinning (will be replaced by proper
        // MsgWaitForMultipleObjects in Phase 2)
        std.Thread.sleep(8 * std.time.ns_per_ms);
    }

    log.info("Win32 message loop exited", .{});
}

pub fn terminate(self: *App) void {
    // Cleanup surface
    if (self.surface) |surface| {
        self.core_app.deleteSurface(surface);
        surface.deinit();
        self.core_app.alloc.destroy(surface);
        self.surface = null;
    }

    if (self.render_timer != 0) {
        _ = win32.user32.KillTimer(self.hwnd, self.render_timer);
    }
    if (self.hglrc) |hglrc| {
        _ = win32.opengl32.wglMakeCurrent(null, null);
        _ = win32.opengl32.wglDeleteContext(hglrc);
    }
    if (self.hdc) |hdc| {
        _ = win32.user32.ReleaseDC(self.hwnd, hdc);
    }
    if (self.hwnd) |hwnd| {
        _ = win32.user32.DestroyWindow(hwnd);
    }
    g_app = null;
    log.info("Windows apprt terminated", .{});
}

/// Called from core app thread to wake the event loop.
pub fn wakeup(self: *App) void {
    // Invalidate window to trigger WM_PAINT, which wakes the message loop
    if (self.hwnd) |hwnd| {
        _ = win32.user32.InvalidateRect(hwnd, null, 0);
    }
}

pub fn performAction(
    self: *App,
    target: apprt.Target,
    comptime action: apprt.Action.Key,
    value: apprt.Action.Value(action),
) !bool {
    _ = target;
    _ = value;

    switch (action) {
        .quit, .close_window => {
            self.running = false;
            return true;
        },
        .set_title => {
            // Phase 2: update window title from terminal
            return false;
        },
        .render => {
            // Redraw triggered by renderer thread via redraw_surface message.
            // Since must_draw_from_app_thread = true, we draw on the app thread.
            if (self.surface) |surface| {
                if (surface.initialized) {
                    surface.core_surface.renderer.drawFrame(false) catch |err| {
                        log.warn("drawFrame error: {}", .{err});
                    };
                    if (self.hdc) |hdc| {
                        _ = win32.gdi32.SwapBuffers(hdc);
                    }
                }
            }
            return true;
        },
        else => return false,
    }
}

pub fn performIpc(
    _: Allocator,
    _: apprt.ipc.Target,
    comptime action: apprt.ipc.Action.Key,
    _: apprt.ipc.Action.Value(action),
) !bool {
    return false;
}

pub fn redrawInspector(_: *App, surface: *Surface) void {
    surface.redrawInspector();
}

/// Win32 window procedure — C callback, uses global g_app pointer.
fn wndProc(hwnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    const app = g_app orelse return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam);

    switch (msg) {
        win32.WM_CLOSE => {
            app.running = false;
            win32.user32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_DESTROY => {
            app.running = false;
            win32.user32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_SIZE => {
            // Phase 2: resize surface and OpenGL viewport
            return 0;
        },
        win32.WM_PAINT => {
            // Handled in main loop render
            return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam);
        },
        win32.WM_KEYDOWN, win32.WM_KEYUP => {
            const surface = if (app.surface) |s| (if (s.initialized) &s.core_surface else null) else null;
            if (surface) |s| {
                const vk: u16 = @truncate(wParam);
                const ghostty_key = key.keyFromVirtualKey(vk);
                const action: input_key.Action = if (msg == win32.WM_KEYDOWN) .press else .release;
                const mods = key.modsFromKeyState(win32.user32.GetKeyState);

                // Handle non-character keys and control keys here.
                // Regular printable characters are handled by WM_CHAR.
                switch (ghostty_key) {
                    // Navigation
                    .arrow_left, .arrow_right, .arrow_up, .arrow_down,
                    .home, .end, .page_up, .page_down,
                    .insert, .delete,
                    // Control keys that must NOT go through WM_CHAR
                    .backspace, .enter, .tab, .escape,
                    // Function keys
                    .f1, .f2, .f3, .f4, .f5, .f6,
                    .f7, .f8, .f9, .f10, .f11, .f12,
                    .f13, .f14, .f15, .f16, .f17, .f18,
                    .f19, .f20, .f21, .f22, .f23, .f24,
                    .print_screen, .scroll_lock, .pause,
                    => {
                        _ = s.keyCallback(.{
                            .action = action,
                            .key = ghostty_key,
                            .mods = mods,
                        }) catch {};
                        return 0;
                    },
                    else => {},
                }
            }
            // Let TranslateMessage generate WM_CHAR for character keys
            return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam);
        },
        win32.WM_CHAR => {
            const surface = if (app.surface) |s| (if (s.initialized) &s.core_surface else null) else null;
            if (surface) |s| {
                const wchar: u16 = @truncate(wParam);
                // Skip control characters already handled by WM_KEYDOWN
                // (backspace=0x08, tab=0x09, enter=0x0D, escape=0x1B)
                if (wchar < 0x20 or wchar == 0x7F) return 0;

                // Convert UTF-16 to UTF-8
                var utf8_buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(@intCast(wchar), &utf8_buf) catch 0;
                if (len > 0) {
                    const mods = key.modsFromKeyState(win32.user32.GetKeyState);
                    _ = s.keyCallback(.{
                        .action = .press,
                        .key = .unidentified,
                        .mods = mods,
                        .utf8 = utf8_buf[0..len],
                    }) catch {};
                }
            }
            return 0;
        },
        win32.WM_TIMER => {
            if (wParam == RENDER_TIMER_ID) {
                // Trigger redraw
                _ = win32.user32.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        else => return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam),
    }
}
