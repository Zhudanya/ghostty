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

pub fn getCursorPos(_: *const Self) !apprt.CursorPos {
    return .{ .x = 0, .y = 0 };
}

pub fn supportsClipboard(_: *const Self, clipboard_type: apprt.Clipboard) bool {
    return clipboard_type == .standard;
}

pub fn clipboardRequest(
    _: *Self,
    _: apprt.Clipboard,
    _: apprt.ClipboardRequest,
) !bool {
    return false;
}

pub fn setClipboard(
    _: *Self,
    _: apprt.Clipboard,
    _: []const apprt.ClipboardContent,
    _: bool,
) !void {}

pub fn defaultTermioEnv(self: *Self) !std.process.EnvMap {
    _ = self;
    var env = try internal_os.getEnvMap(std.heap.page_allocator);
    try env.put("TERM", "xterm-256color");
    try env.put("COLORTERM", "truecolor");
    return env;
}

pub fn redrawInspector(_: *Self) void {}
