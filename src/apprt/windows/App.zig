/// Windows apprt App implementation.
/// Manages multiple windows, each with its own Surface and OpenGL context.
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
const windows_os = @import("../../os/windows.zig");
const win32 = windows_os.exp;

const log = std.log.scoped(.windows);

/// WGL context must be on the same thread that created it.
pub const must_draw_from_app_thread = true;

/// Window class name (shared by all windows).
pub const CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWindowClass");
pub const WINDOW_TITLE = std.unicode.utf8ToUtf16LeStringLiteral("Ghostty");

/// Core app reference
core_app: *CoreApp,

/// All active surfaces. Each surface owns its own HWND.
surfaces: std.ArrayListUnmanaged(*Surface),

/// Primary OpenGL context for wglShareLists (first surface's context).
primary_hglrc: ?win32.HGLRC = null,

/// Whether the app is still running
running: bool = true,

/// Wakeup event handle for cross-thread signaling
wakeup_event: ?std.os.windows.HANDLE = null,

/// Global pointer for WndProc callback (WndProc is a C callback, no context)
var g_app: ?*App = null;

pub fn init(
    self: *App,
    core_app: *CoreApp,
    opts: struct {},
) !void {
    _ = opts;
    self.* = .{
        .core_app = core_app,
        .surfaces = .{},
    };
    g_app = self;

    // Register window class (shared by all windows)
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

    // Create wakeup event for cross-thread signaling
    self.wakeup_event = win32.CreateEventW(null, windows_os.TRUE, windows_os.FALSE, null);

    log.info("Windows apprt initialized (multi-window)", .{});
}

pub fn run(self: *App) !void {
    log.info("entering Win32 message loop", .{});

    // Create the initial terminal surface
    try self.newSurface();

    log.info("initial surface created, starting message loop", .{});

    // Main message loop using MsgWaitForMultipleObjects for efficient waiting
    var msg: win32.MSG = undefined;
    var handle_arr: [1]std.os.windows.HANDLE = .{self.wakeup_event orelse std.os.windows.INVALID_HANDLE_VALUE};
    const handles: ?[*]const std.os.windows.HANDLE = if (self.wakeup_event != null) &handle_arr else null;
    const handle_count: u32 = if (self.wakeup_event != null) 1 else 0;

    while (self.running) {
        const wait_result = win32.MsgWaitForMultipleObjects(
            handle_count,
            handles,
            windows_os.FALSE,
            windows_os.INFINITE,
            win32.QS_ALLINPUT,
        );

        if (!self.running) break;

        if (wait_result == win32.WAIT_OBJECT_0 and self.wakeup_event != null) {
            _ = win32.ResetEvent(self.wakeup_event.?);
        }

        while (win32.user32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
            if (msg.message == win32.WM_QUIT) {
                self.running = false;
                break;
            }
            _ = win32.user32.TranslateMessage(&msg);
            _ = win32.user32.DispatchMessageW(&msg);
        }

        if (!self.running) break;

        self.core_app.tick(self) catch |err| {
            log.err("core_app.tick error: {}", .{err});
        };
    }

    log.info("Win32 message loop exited", .{});
}

/// Create a new surface with its own window.
fn newSurface(self: *App) !void {
    const alloc = self.core_app.alloc;
    const surface = try alloc.create(Surface);
    errdefer alloc.destroy(surface);
    try surface.init(self);
    try self.surfaces.append(alloc, surface);
    log.info("new surface created, total={}", .{self.surfaces.items.len});
}

/// Remove a surface from the list and clean it up.
fn closeSurface(self: *App, surface: *Surface) void {
    // Remove from our list
    var i: usize = 0;
    while (i < self.surfaces.items.len) {
        if (self.surfaces.items[i] == surface) {
            _ = self.surfaces.swapRemove(i);
            continue;
        }
        i += 1;
    }

    // Unregister from core app and clean up
    self.core_app.deleteSurface(surface);
    surface.deinit();
    self.core_app.alloc.destroy(surface);

    log.info("surface closed, remaining={}", .{self.surfaces.items.len});

    // If no surfaces remain, quit
    if (self.surfaces.items.len == 0) {
        self.running = false;
        win32.user32.PostQuitMessage(0);
    }
}

/// Find a surface by its HWND.
fn findSurfaceByHwnd(self: *App, hwnd: win32.HWND) ?*Surface {
    for (self.surfaces.items) |surface| {
        if (surface.hwnd) |surface_hwnd| {
            if (surface_hwnd == hwnd) return surface;
        }
    }
    return null;
}

pub fn terminate(self: *App) void {
    // Clean up all surfaces
    const alloc = self.core_app.alloc;
    while (self.surfaces.items.len > 0) {
        const surface = self.surfaces.items[self.surfaces.items.len - 1];
        _ = self.surfaces.pop();
        self.core_app.deleteSurface(surface);
        surface.deinit();
        alloc.destroy(surface);
    }
    self.surfaces.deinit(alloc);

    if (self.wakeup_event) |evt| {
        std.os.windows.CloseHandle(evt);
        self.wakeup_event = null;
    }

    g_app = null;
    log.info("Windows apprt terminated", .{});
}

/// Called from core app thread to wake the event loop.
pub fn wakeup(self: *App) void {
    if (self.wakeup_event) |evt| {
        _ = win32.SetEvent(evt);
    }
}

pub fn performAction(
    self: *App,
    target: apprt.Target,
    comptime action: apprt.Action.Key,
    value: apprt.Action.Value(action),
) !bool {
    switch (action) {
        .new_window => {
            try self.newSurface();
            return true;
        },
        .quit => {
            self.running = false;
            return true;
        },
        .close_window => {
            // Close the target surface's window, or all if target is app
            switch (target) {
                .app => {
                    self.running = false;
                },
                .surface => |cs| {
                    // Find the Surface that wraps this CoreSurface
                    for (self.surfaces.items) |surface| {
                        if (surface.initialized and &surface.core_surface == cs) {
                            self.closeSurface(surface);
                            break;
                        }
                    }
                },
            }
            return true;
        },
        .set_title => {
            // Set title on the target surface's window
            const hwnd = switch (target) {
                .surface => |cs| hwnd: {
                    for (self.surfaces.items) |surface| {
                        if (surface.initialized and &surface.core_surface == cs) {
                            break :hwnd surface.hwnd;
                        }
                    }
                    break :hwnd null;
                },
                .app => if (self.surfaces.items.len > 0) self.surfaces.items[0].hwnd else null,
            };
            if (hwnd) |h| {
                var buf: [256]u16 = undefined;
                const len = std.unicode.utf8ToUtf16Le(&buf, value.title) catch 0;
                if (len < buf.len) {
                    buf[len] = 0;
                    _ = win32.user32.SetWindowTextW(h, @ptrCast(&buf));
                }
            }
            return true;
        },
        .ring_bell => {
            _ = win32.user32_ext.MessageBeep(0);
            return true;
        },
        .render => {
            // Find the target surface and draw
            switch (target) {
                .surface => |cs| {
                    for (self.surfaces.items) |surface| {
                        if (surface.initialized and &surface.core_surface == cs) {
                            surface.drawFrame();
                            break;
                        }
                    }
                },
                .app => {
                    // Render all surfaces
                    for (self.surfaces.items) |surface| {
                        surface.drawFrame();
                    }
                },
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

/// Win32 window procedure — routes messages to the correct Surface by HWND.
fn wndProc(hwnd: win32.HWND, msg: win32.UINT, wParam: win32.WPARAM, lParam: win32.LPARAM) callconv(.winapi) win32.LRESULT {
    const app = g_app orelse return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam);

    switch (msg) {
        win32.WM_CLOSE => {
            // Close this specific window
            if (app.findSurfaceByHwnd(hwnd)) |surface| {
                // Nullify HWND before closeSurface to avoid double DestroyWindow
                surface.hwnd = null;
                app.closeSurface(surface);
            }
            return 0;
        },
        win32.WM_DESTROY => {
            // Already handled by WM_CLOSE
            return 0;
        },
        win32.WM_SIZE => {
            const width: u32 = @truncate(@as(usize, @bitCast(lParam)) & 0xFFFF);
            const height: u32 = @truncate((@as(usize, @bitCast(lParam)) >> 16) & 0xFFFF);
            if (width > 0 and height > 0) {
                if (app.findSurfaceByHwnd(hwnd)) |surface| {
                    surface.width = width;
                    surface.height = height;
                    if (surface.initialized) {
                        surface.core_surface.sizeCallback(.{
                            .width = width,
                            .height = height,
                        }) catch |err| {
                            log.warn("sizeCallback error: {}", .{err});
                        };
                    }
                }
            }
            return 0;
        },
        win32.WM_PAINT => {
            return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam);
        },
        win32.WM_KEYDOWN, win32.WM_KEYUP => {
            const surface = app.findSurfaceByHwnd(hwnd);
            const cs = if (surface) |s| (if (s.initialized) &s.core_surface else null) else null;
            if (cs) |s| {
                const vk: u16 = @truncate(wParam);
                const ghostty_key = key.keyFromVirtualKey(vk);
                const action: input_key.Action = if (msg == win32.WM_KEYDOWN) .press else .release;
                const mods = key.modsFromKeyState(win32.user32.GetKeyState);

                switch (ghostty_key) {
                    .arrow_left, .arrow_right, .arrow_up, .arrow_down,
                    .home, .end, .page_up, .page_down,
                    .insert, .delete,
                    .backspace, .enter, .tab, .escape,
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
            return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam);
        },
        win32.WM_CHAR => {
            const surface = app.findSurfaceByHwnd(hwnd);
            const cs = if (surface) |s| (if (s.initialized) &s.core_surface else null) else null;
            if (cs) |s| {
                const wchar: u16 = @truncate(wParam);
                if (wchar < 0x20 or wchar == 0x7F) return 0;

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
        win32.WM_MOUSEWHEEL => {
            const surface = app.findSurfaceByHwnd(hwnd);
            const cs = if (surface) |s| (if (s.initialized) &s.core_surface else null) else null;
            if (cs) |s| {
                const delta = win32.GET_WHEEL_DELTA_WPARAM(wParam);
                const yoff: f64 = @as(f64, @floatFromInt(delta)) / @as(f64, @floatFromInt(win32.WHEEL_DELTA));
                s.scrollCallback(0, yoff, .{}) catch |err| {
                    log.warn("scrollCallback error: {}", .{err});
                };
            }
            return 0;
        },
        win32.WM_TIMER => {
            if (wParam == 1) { // RENDER_TIMER_ID
                _ = win32.user32.InvalidateRect(hwnd, null, 0);
            }
            return 0;
        },
        else => return win32.user32.DefWindowProcW(hwnd, msg, wParam, lParam),
    }
}
