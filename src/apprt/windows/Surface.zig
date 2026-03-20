/// Windows apprt Surface implementation.
/// Each Surface owns its own Win32 window, OpenGL context, and terminal.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const configpkg = @import("../../config.zig");
const CoreSurface = @import("../../Surface.zig");
const CoreApp = @import("../../App.zig");
const App = @import("App.zig");
const windows_os = @import("../../os/windows.zig");
const win32 = windows_os.exp;
const internal_os = @import("../../os/main.zig");

const log = std.log.scoped(.windows_surface);

const RENDER_TIMER_ID: usize = 1;
const RENDER_INTERVAL_MS: u32 = 16; // ~60 FPS

/// The core surface (initialized after creation).
core_surface: CoreSurface = undefined,

/// Whether the core surface has been initialized.
initialized: bool = false,

/// The parent app.
app: *App,

/// The surface config (must outlive the core surface).
config: configpkg.Config = undefined,
config_loaded: bool = false,

/// This surface's Win32 window handle.
hwnd: ?win32.HWND = null,

/// Device context for OpenGL.
hdc: ?win32.HDC = null,

/// OpenGL rendering context.
hglrc: ?win32.HGLRC = null,

/// Render timer ID.
render_timer: usize = 0,

/// Cached window dimensions.
width: u32 = 1024,
height: u32 = 768,

pub fn init(
    self: *Self,
    app: *App,
) !void {
    const alloc = app.core_app.alloc;

    self.* = .{
        .app = app,
    };

    // Create a Win32 window for this surface
    self.hwnd = win32.user32.CreateWindowExW(
        0,
        App.CLASS_NAME,
        App.WINDOW_TITLE,
        win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        1024,
        768,
        null,
        null,
        null,
        null,
    );

    if (self.hwnd == null) {
        log.err("CreateWindowExW failed for surface", .{});
        return error.WindowCreationFailed;
    }

    // Setup OpenGL context for this window
    try self.initOpenGL();

    // Show window
    _ = win32.user32.ShowWindow(self.hwnd.?, win32.SW_SHOW);
    _ = win32.user32.UpdateWindow(self.hwnd.?);

    // Start render timer
    self.render_timer = win32.user32.SetTimer(self.hwnd, RENDER_TIMER_ID, RENDER_INTERVAL_MS, null);

    // Update dimensions from actual window
    if (self.hwnd) |hwnd| {
        var rect: win32.RECT = undefined;
        if (win32.user32.GetClientRect(hwnd, &rect) != 0) {
            self.width = @intCast(rect.right - rect.left);
            self.height = @intCast(rect.bottom - rect.top);
        }
    }

    // Load configuration
    self.config = try configpkg.Config.load(alloc);
    self.config_loaded = true;

    // Initialize the core surface which starts the terminal, renderer, and IO.
    try self.core_surface.init(
        alloc,
        &self.config,
        app.core_app,
        app,
        self,
    );
    self.initialized = true;

    // Register this surface with the core app
    try app.core_app.addSurface(self);

    log.info("surface initialized: {}x{} hwnd={*}", .{ self.width, self.height, self.hwnd.? });
}

fn initOpenGL(self: *Self) !void {
    self.hdc = win32.user32.GetDC(self.hwnd);
    if (self.hdc == null) {
        log.err("GetDC failed", .{});
        return error.GetDCFailed;
    }

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

    self.hglrc = win32.opengl32.wglCreateContext(self.hdc.?);
    if (self.hglrc == null) {
        log.err("wglCreateContext failed", .{});
        return error.WglCreateContextFailed;
    }

    // Share OpenGL resources (font atlas, textures) with the first surface
    if (self.app.primary_hglrc) |primary| {
        if (win32.opengl32.wglShareLists(primary, self.hglrc.?) == 0) {
            log.warn("wglShareLists failed, textures will not be shared", .{});
        }
    } else {
        // This is the first surface — store its context as the primary for sharing
        self.app.primary_hglrc = self.hglrc;
    }

    if (win32.opengl32.wglMakeCurrent(self.hdc, self.hglrc) == 0) {
        log.err("wglMakeCurrent failed", .{});
        return error.WglMakeCurrentFailed;
    }

    log.info("OpenGL context created for surface", .{});
}

pub fn deinit(self: *Self) void {
    if (self.initialized) {
        self.core_surface.deinit();
        self.initialized = false;
    }

    if (self.render_timer != 0) {
        _ = win32.user32.KillTimer(self.hwnd, self.render_timer);
        self.render_timer = 0;
    }

    // Clean up the primary_hglrc reference if this was the primary
    if (self.app.primary_hglrc) |primary| {
        if (self.hglrc) |hglrc| {
            if (primary == hglrc) {
                self.app.primary_hglrc = null;
            }
        }
    }

    if (self.hglrc) |hglrc| {
        _ = win32.opengl32.wglMakeCurrent(null, null);
        _ = win32.opengl32.wglDeleteContext(hglrc);
        self.hglrc = null;
    }
    if (self.hdc) |hdc| {
        _ = win32.user32.ReleaseDC(self.hwnd, hdc);
        self.hdc = null;
    }
    if (self.hwnd) |hwnd| {
        _ = win32.user32.DestroyWindow(hwnd);
        self.hwnd = null;
    }
}

/// Draw frame and swap buffers for this surface.
pub fn drawFrame(self: *Self) void {
    if (!self.initialized) return;

    // Make this surface's GL context current
    if (self.hdc != null and self.hglrc != null) {
        _ = win32.opengl32.wglMakeCurrent(self.hdc, self.hglrc);
    }

    self.core_surface.renderer.drawFrame(false) catch |err| {
        log.warn("drawFrame error: {}", .{err});
        return;
    };

    if (self.hdc) |hdc| {
        _ = win32.gdi32.SwapBuffers(hdc);
    }
}

pub fn core(self: *Self) *CoreSurface {
    return &self.core_surface;
}

pub fn rtApp(self: *Self) *App {
    return self.app;
}

pub fn close(self: *Self, process_active: bool) void {
    _ = process_active;
    // Close just this surface's window; App will handle cleanup
    if (self.hwnd) |hwnd| {
        _ = win32.user32.DestroyWindow(hwnd);
    }
}

pub fn cgroup(_: *Self) ?[]const u8 {
    return null;
}

pub fn getTitle(_: *Self) ?[:0]const u8 {
    return null;
}

pub fn getContentScale(self: *const Self) !apprt.ContentScale {
    if (self.hwnd) |hwnd| {
        const dpi = win32.user32.GetDpiForWindow(hwnd);
        const scale: f32 = @as(f32, @floatFromInt(dpi)) / 96.0;
        return .{ .x = scale, .y = scale };
    }
    return .{ .x = 1.0, .y = 1.0 };
}

pub fn getSize(self: *const Self) !apprt.SurfaceSize {
    return .{ .width = self.width, .height = self.height };
}

pub fn getCursorPos(self: *const Self) !apprt.CursorPos {
    if (self.hwnd) |hwnd| {
        var pt: win32.POINT = undefined;
        if (win32.user32_ext.GetCursorPos(&pt) != 0) {
            _ = win32.user32_ext.ScreenToClient(hwnd, &pt);
            return .{
                .x = @floatFromInt(pt.x),
                .y = @floatFromInt(pt.y),
            };
        }
    }
    return .{ .x = 0, .y = 0 };
}

pub fn supportsClipboard(_: *const Self, clipboard_type: apprt.Clipboard) bool {
    return clipboard_type == .standard;
}

pub fn clipboardRequest(
    self: *Self,
    _: apprt.Clipboard,
    req: apprt.ClipboardRequest,
) !bool {
    if (win32.OpenClipboard(self.hwnd) == 0) return false;
    defer _ = win32.CloseClipboard();

    const handle = win32.GetClipboardData(win32.CF_UNICODETEXT) orelse return false;
    const ptr = win32.GlobalLock(handle) orelse return false;
    defer _ = win32.GlobalUnlock(handle);

    const wide_ptr: [*]const u16 = @ptrCast(@alignCast(ptr));
    var wide_len: usize = 0;
    while (wide_ptr[wide_len] != 0) : (wide_len += 1) {}
    const wide_slice = wide_ptr[0..wide_len];

    const alloc = self.app.core_app.alloc;
    var utf8_size: usize = 0;
    for (wide_slice) |wc| {
        if (wc < 0x80) {
            utf8_size += 1;
        } else if (wc < 0x800) {
            utf8_size += 2;
        } else {
            utf8_size += 3;
        }
    }

    const raw_buf = alloc.alloc(u8, utf8_size + 1) catch return false;
    defer alloc.free(raw_buf);
    const written = std.unicode.utf16LeToUtf8(raw_buf[0..utf8_size], wide_slice) catch return false;
    raw_buf[written] = 0;

    const sentinel_buf: [:0]const u8 = raw_buf[0..written :0];
    try self.core_surface.completeClipboardRequest(req, sentinel_buf, false);
    return true;
}

pub fn setClipboard(
    self: *Self,
    _: apprt.Clipboard,
    contents: []const apprt.ClipboardContent,
    _: bool,
) !void {
    if (contents.len == 0) return;

    const data = contents[0].data;

    var stack_buf: [4096]u16 = undefined;
    const wide_len = std.unicode.utf8ToUtf16Le(&stack_buf, data) catch 0;
    if (wide_len == 0) return;

    const byte_len = (wide_len + 1) * @sizeOf(u16);
    const hmem = win32.GlobalAlloc(win32.GMEM_MOVEABLE, byte_len) orelse return;

    const dest = win32.GlobalLock(hmem) orelse {
        _ = win32.GlobalFree(hmem);
        return;
    };
    const dest_wide: [*]u16 = @ptrCast(@alignCast(dest));
    @memcpy(dest_wide[0..wide_len], stack_buf[0..wide_len]);
    dest_wide[wide_len] = 0;
    _ = win32.GlobalUnlock(hmem);

    if (win32.OpenClipboard(self.hwnd) == 0) {
        _ = win32.GlobalFree(hmem);
        return;
    }
    _ = win32.EmptyClipboard();
    _ = win32.SetClipboardData(win32.CF_UNICODETEXT, hmem);
    _ = win32.CloseClipboard();
}

pub fn defaultTermioEnv(self: *Self) !std.process.EnvMap {
    _ = self;
    var env = try internal_os.getEnvMap(std.heap.page_allocator);
    try env.put("TERM", "xterm-256color");
    try env.put("COLORTERM", "truecolor");
    return env;
}

pub fn redrawInspector(_: *Self) void {}
