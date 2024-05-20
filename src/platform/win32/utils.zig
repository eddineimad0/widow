const std = @import("std");
const common = @import("common");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const wndw = @import("window.zig");
const mem = std.mem;
const kbd_mouse = zigwin32.ui.input.keyboard_and_mouse;
const foundation = zigwin32.foundation;
const ScanCode = common.keyboard_mouse.ScanCode;
const KeyCode = common.keyboard_mouse.KeyCode;
const KeyState = common.keyboard_mouse.KeyState;

/// For comparing wide c strings.
pub fn wideStrZCmp(str_a: [*:0]const u16, str_b: [*:0]const u16) bool {
    var i: usize = 0;
    while (str_a[i] != 0 and str_b[i] != 0) {
        if (str_a[i] != str_b[i]) {
            return false;
        }
        i += 1;
    }
    // assert that we reached the end of both strings.
    if (str_a[i] != str_b[i]) {
        return false;
    }
    return true;
}

pub inline fn strCmp(str_a: []const u8, str_b: []const u8) bool {
    return std.mem.eql(u8, str_a, str_b);
}

/// Returns a slice to well formed Utf16 null terminated string.
/// for use with windows `W(ide)` api functions.
/// # Note
/// The returned slice should be freed by the caller.
pub inline fn utf8ToWideZ(allocator: mem.Allocator, utf8_str: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeAllocZ(allocator, utf8_str);
}

/// Returns a slice to a well formed utf8 string.
pub inline fn wideToUtf8(allocator: mem.Allocator, wide_str: []const u16) ![]u8 {
    return std.unicode.utf16LeToUtf8Alloc(allocator, wide_str);
}

/// Returns a slice to a well formed utf8 string.
/// # Note
/// The returned slice should be freed by the caller.
/// If this function gets passed a non null terminated wide string,
/// it will end up removing the last character.
pub fn wideZToUtf8(allocator: std.mem.Allocator, wide_str: []const u16) ![]u8 {
    var zero_indx: usize = 0;
    while (wide_str.ptr[zero_indx] != 0) {
        zero_indx += 1;
    }
    // utf16leToUtf8Alloc will allocate space for the null terminator,
    // and anything that comes after it in the slice
    // to save some memory indicate the new start and end of the slice
    return wideToUtf8(allocator, wide_str.ptr[0..zero_indx]);
}

/// Replacement for the `MAKEINTATOM` macro in the windows api.
pub inline fn MAKEINTATOM(atom: u16) ?win32.LPCWSTR {
    return @ptrFromInt(atom);
}

/// Replacement for the `MAKEINTRESOURCESA` macro in the windows api.
pub inline fn MAKEINTRESOURCESA(comptime r: u16) ?[*:0]const u8 {
    return @ptrFromInt(r);
}

// Some usefule windows.h Macros.
pub inline fn hiWord(bits: usize) u16 {
    return @truncate((bits >> 16) & 0xFFFF);
}

pub inline fn loWord(bits: usize) u16 {
    return @truncate((bits & 0xFFFF));
}

pub inline fn getXLparam(bits: usize) i16 {
    return @bitCast(loWord(bits));
}

pub inline fn getYLparam(bits: usize) i16 {
    return @bitCast(hiWord(bits));
}

pub inline fn isBitSet(bitset: isize, comptime pos: comptime_int) bool {
    return (bitset & (1 << pos)) != 0;
}

pub inline fn isHighSurrogate(surrogate: u16) bool {
    return (surrogate >= 0xD800 and surrogate <= 0xDBFF);
}

pub inline fn isLowSurrogate(surrogate: u16) bool {
    return (surrogate >= 0xDC00 and surrogate <= 0xDFFF);
}

pub inline fn getLastError() win32.WIN32_ERROR {
    return foundation.GetLastError();
}

pub inline fn clearThreadError() void {
    foundation.SetLastError(win32.WIN32_ERROR.NO_ERROR); // 0
}

pub fn getKeyModifiers() common.keyboard_mouse.KeyModifiers {
    var mods = common.keyboard_mouse.KeyModifiers{
        .shift = false,
        .ctrl = false,
        .alt = false,
        .meta = false,
        .caps_lock = false,
        .num_lock = false,
    };
    if (isBitSet(
        kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_SHIFT)),
        15,
    )) {
        mods.shift = true;
    }
    if (isBitSet(
        kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_CONTROL)),
        15,
    )) {
        mods.ctrl = true;
    }
    if (isBitSet(kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_MENU)), 15)) {
        mods.alt = true;
    }
    if (isBitSet(
        (kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_LWIN)) |
            kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_RWIN))),
        15,
    )) {
        mods.meta = true;
    }
    if (isBitSet(kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_CAPITAL)), 0)) {
        mods.caps_lock = true;
    }
    if (isBitSet(kbd_mouse.GetKeyState(@intFromEnum(kbd_mouse.VK_NUMLOCK)), 0)) {
        mods.num_lock = true;
    }
    return mods;
}

/// Clean the Key_state array of the window and emit the corresponding events.
/// insight taken from glfw library.
pub fn clearStickyKeys(window: *wndw.Window) void {
    // Windows doesn't emit a keyup event for the modifiers and this causes
    // confusion and misinput for the user.
    // Solution clean the key_state and queue the necessary events at every event poll.
    const codes = comptime [4]ScanCode{
        ScanCode.LShift,
        ScanCode.RShift,
        ScanCode.LMeta,
        ScanCode.RMeta,
    };

    const virtual_keys = comptime [4]kbd_mouse.VIRTUAL_KEY{
        kbd_mouse.VK_LSHIFT,
        kbd_mouse.VK_RSHIFT,
        kbd_mouse.VK_LWIN,
        kbd_mouse.VK_RWIN,
    };

    const virtual_codes = comptime [4]KeyCode{
        KeyCode.Shift,
        KeyCode.Shift,
        KeyCode.Meta,
        KeyCode.Meta,
    };

    for (0..4) |index| {
        if (window.data.input.keys[@intCast(@intFromEnum(codes[index]))] == KeyState.Pressed) {
            const is_key_up = !isBitSet(
                kbd_mouse.GetKeyState(@intFromEnum(virtual_keys[index])),
                15,
            );
            if (is_key_up) {
                window.data.input.keys[@intCast(@intFromEnum(codes[index]))] = KeyState.Released;
                const fake_event = common.event.createKeyboardEvent(
                    window.data.id,
                    virtual_codes[index],
                    codes[index],
                    KeyState.Released,
                    getKeyModifiers(),
                );
                window.sendEvent(&fake_event);
            }
        }
    }
}

pub inline fn getMousePosition(lparam: win32.LPARAM) common.geometry.WidowPoint2D {
    const xpos = getXLparam(@bitCast(lparam));
    const ypos = getYLparam(@bitCast(lparam));
    return common.geometry.WidowPoint2D{ .x = xpos, .y = ypos };
}
