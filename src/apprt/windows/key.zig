/// Windows Virtual-Key to Ghostty input.Key translation.
/// Stateless translation functions mirroring src/apprt/gtk/key.zig.
const input = @import("../../input.zig");

/// Map a Windows Virtual-Key code to a Ghostty input.Key.
pub fn keyFromVirtualKey(vk: u16) input.Key {
    return switch (vk) {
        // Letters A-Z (0x41-0x5A)
        0x41 => .key_a,
        0x42 => .key_b,
        0x43 => .key_c,
        0x44 => .key_d,
        0x45 => .key_e,
        0x46 => .key_f,
        0x47 => .key_g,
        0x48 => .key_h,
        0x49 => .key_i,
        0x4A => .key_j,
        0x4B => .key_k,
        0x4C => .key_l,
        0x4D => .key_m,
        0x4E => .key_n,
        0x4F => .key_o,
        0x50 => .key_p,
        0x51 => .key_q,
        0x52 => .key_r,
        0x53 => .key_s,
        0x54 => .key_t,
        0x55 => .key_u,
        0x56 => .key_v,
        0x57 => .key_w,
        0x58 => .key_x,
        0x59 => .key_y,
        0x5A => .key_z,

        // Digits 0-9 (0x30-0x39)
        0x30 => .digit_0,
        0x31 => .digit_1,
        0x32 => .digit_2,
        0x33 => .digit_3,
        0x34 => .digit_4,
        0x35 => .digit_5,
        0x36 => .digit_6,
        0x37 => .digit_7,
        0x38 => .digit_8,
        0x39 => .digit_9,

        // Function keys
        0x70 => .f1,
        0x71 => .f2,
        0x72 => .f3,
        0x73 => .f4,
        0x74 => .f5,
        0x75 => .f6,
        0x76 => .f7,
        0x77 => .f8,
        0x78 => .f9,
        0x79 => .f10,
        0x7A => .f11,
        0x7B => .f12,
        0x7C => .f13,
        0x7D => .f14,
        0x7E => .f15,
        0x7F => .f16,
        0x80 => .f17,
        0x81 => .f18,
        0x82 => .f19,
        0x83 => .f20,
        0x84 => .f21,
        0x85 => .f22,
        0x86 => .f23,
        0x87 => .f24,

        // Control keys
        0x08 => .backspace, // VK_BACK
        0x09 => .tab, // VK_TAB
        0x0D => .enter, // VK_RETURN
        0x1B => .escape, // VK_ESCAPE
        0x20 => .space, // VK_SPACE

        // Navigation
        0x21 => .page_up, // VK_PRIOR
        0x22 => .page_down, // VK_NEXT
        0x23 => .end, // VK_END
        0x24 => .home, // VK_HOME
        0x25 => .arrow_left, // VK_LEFT
        0x26 => .arrow_up, // VK_UP
        0x27 => .arrow_right, // VK_RIGHT
        0x28 => .arrow_down, // VK_DOWN

        // Editing
        0x2D => .insert, // VK_INSERT
        0x2E => .delete, // VK_DELETE

        // Numpad
        0x60 => .numpad_0, // VK_NUMPAD0
        0x61 => .numpad_1,
        0x62 => .numpad_2,
        0x63 => .numpad_3,
        0x64 => .numpad_4,
        0x65 => .numpad_5,
        0x66 => .numpad_6,
        0x67 => .numpad_7,
        0x68 => .numpad_8,
        0x69 => .numpad_9,
        0x6A => .numpad_multiply, // VK_MULTIPLY
        0x6B => .numpad_add, // VK_ADD
        0x6C => .numpad_separator, // VK_SEPARATOR
        0x6D => .numpad_subtract, // VK_SUBTRACT
        0x6E => .numpad_decimal, // VK_DECIMAL
        0x6F => .numpad_divide, // VK_DIVIDE

        // Symbol keys
        0xBA => .semicolon, // VK_OEM_1 (;:)
        0xBB => .equal, // VK_OEM_PLUS (=+)
        0xBC => .comma, // VK_OEM_COMMA (,<)
        0xBD => .minus, // VK_OEM_MINUS (-_)
        0xBE => .period, // VK_OEM_PERIOD (.>)
        0xBF => .slash, // VK_OEM_2 (/?)
        0xC0 => .backquote, // VK_OEM_3 (`~)
        0xDB => .bracket_left, // VK_OEM_4 ([{)
        0xDC => .backslash, // VK_OEM_5 (\|)
        0xDD => .bracket_right, // VK_OEM_6 (]})
        0xDE => .quote, // VK_OEM_7 ('")

        // Modifier keys
        0x10 => .shift_left, // VK_SHIFT (generic)
        0x11 => .control_left, // VK_CONTROL (generic)
        0x12 => .alt_left, // VK_MENU (generic)
        0xA0 => .shift_left, // VK_LSHIFT
        0xA1 => .shift_right, // VK_RSHIFT
        0xA2 => .control_left, // VK_LCONTROL
        0xA3 => .control_right, // VK_RCONTROL
        0xA4 => .alt_left, // VK_LMENU
        0xA5 => .alt_right, // VK_RMENU
        0x5B => .meta_left, // VK_LWIN
        0x5C => .meta_right, // VK_RWIN
        0x14 => .caps_lock, // VK_CAPITAL
        0x90 => .num_lock, // VK_NUMLOCK
        0x91 => .scroll_lock, // VK_SCROLL

        // Special
        0x2C => .print_screen, // VK_SNAPSHOT
        0x13 => .pause, // VK_PAUSE

        else => .unidentified,
    };
}

/// Extract modifier state from Windows GetKeyState results.
pub fn modsFromKeyState(comptime getKeyState: fn (i32) callconv(.winapi) i16) input.Mods {
    return .{
        .shift = (getKeyState(0x10) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0,
        .ctrl = (getKeyState(0x11) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0,
        .alt = (getKeyState(0x12) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0,
        .super = (getKeyState(0x5B) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0,
        .caps_lock = (getKeyState(0x14) & 1) != 0,
        .num_lock = (getKeyState(0x90) & 1) != 0,
    };
}

test "basic vk mapping" {
    const std = @import("std");
    try std.testing.expectEqual(input.Key.key_a, keyFromVirtualKey(0x41));
    try std.testing.expectEqual(input.Key.enter, keyFromVirtualKey(0x0D));
    try std.testing.expectEqual(input.Key.escape, keyFromVirtualKey(0x1B));
    try std.testing.expectEqual(input.Key.f1, keyFromVirtualKey(0x70));
    try std.testing.expectEqual(input.Key.unidentified, keyFromVirtualKey(0xFF));
}
