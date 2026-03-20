/// Windows apprt Surface implementation.
/// Wraps a CoreSurface and provides the platform-specific interface.
const Self = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const configpkg = @import("../../config.zig");
const CoreSurface = @import("../../Surface.zig");
const CoreApp = @import("../../App.zig");
const App = @import("App.zig");
const win32 = @import("../../os/windows.zig").exp;
const internal_os = @import("../../os/main.zig");

const log = std.log.scoped(.windows_surface);

/// The core surface (initialized after creation).
core_surface: CoreSurface = undefined,

/// Whether the core surface has been initialized.
initialized: bool = false,

/// The parent app.
app: *App,

/// The surface config (must outlive the core surface).
config: configpkg.Config = undefined,
config_loaded: bool = false,

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

    // Update dimensions from actual window
    if (app.hwnd) |hwnd| {
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

    log.info("surface initialized: {}x{}", .{ self.width, self.height });
}

pub fn deinit(self: *Self) void {
    if (self.initialized) {
        self.core_surface.deinit();
        self.initialized = false;
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
    self.app.running = false;
}

pub fn cgroup(_: *Self) ?[]const u8 {
    return null;
}

pub fn getTitle(_: *Self) ?[:0]const u8 {
    return null;
}

pub fn getContentScale(self: *const Self) !apprt.ContentScale {
    if (self.app.hwnd) |hwnd| {
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
    if (self.app.hwnd) |hwnd| {
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
    // Read text from the Windows clipboard
    if (win32.OpenClipboard(self.app.hwnd) == 0) return false;
    defer _ = win32.CloseClipboard();

    const handle = win32.GetClipboardData(win32.CF_UNICODETEXT) orelse return false;
    const ptr = win32.GlobalLock(handle) orelse return false;
    defer _ = win32.GlobalUnlock(handle);

    // Convert UTF-16 to UTF-8
    const wide_ptr: [*]const u16 = @ptrCast(@alignCast(ptr));
    var wide_len: usize = 0;
    while (wide_ptr[wide_len] != 0) : (wide_len += 1) {}
    const wide_slice = wide_ptr[0..wide_len];

    // First pass: calculate required UTF-8 buffer size
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

    // Allocate buffer with sentinel null terminator
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

    // Use the first content entry
    const data = contents[0].data;

    // Convert UTF-8 to UTF-16 using stack buffer for small strings, heap for large
    const alloc = self.app.core_app.alloc;
    var stack_buf: [4096]u16 = undefined;
    const wide_len = std.unicode.utf8ToUtf16Le(&stack_buf, data) catch 0;
    if (wide_len == 0) return;

    // Allocate global memory for clipboard (includes null terminator)
    const byte_len = (wide_len + 1) * @sizeOf(u16);
    const hmem = win32.GlobalAlloc(win32.GMEM_MOVEABLE, byte_len) orelse return;
    _ = alloc;

    const dest = win32.GlobalLock(hmem) orelse {
        _ = win32.GlobalFree(hmem);
        return;
    };
    const dest_wide: [*]u16 = @ptrCast(@alignCast(dest));
    @memcpy(dest_wide[0..wide_len], stack_buf[0..wide_len]);
    dest_wide[wide_len] = 0;
    _ = win32.GlobalUnlock(hmem);

    if (win32.OpenClipboard(self.app.hwnd) == 0) {
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
