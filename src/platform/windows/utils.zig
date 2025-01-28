const std = @import("std");
const common = @import("common");
const wndw = @import("window.zig");
const win32_gfx = @import("win32api/graphics.zig");
const win32_macros = @import("win32api/macros.zig");
const win32_input = @import("win32api/input.zig");
const win32 = std.os.windows;
const mem = std.mem;
const geometry = common.geometry;
const ScanCode = common.keyboard_mouse.ScanCode;
const KeyCode = common.keyboard_mouse.KeyCode;
const KeyState = common.keyboard_mouse.KeyState;
const KeyModifiers = common.keyboard_mouse.KeyModifiers;
const event = common.event;

/// For comparing wide c strings.
pub fn wideStrZCmp(noalias str_a: [*:0]const u16, noalias str_b: [*:0]const u16) bool {
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

pub inline fn isBitSet(bitset: isize, comptime pos: comptime_int) bool {
    return (bitset & (1 << pos)) != 0;
}

pub fn getKeyModifiers() KeyModifiers {
    var mods = KeyModifiers{
        .shift = false,
        .ctrl = false,
        .alt = false,
        .meta = false,
        .caps_lock = false,
        .num_lock = false,
    };
    if (isBitSet(
        win32_input.GetKeyState(win32_input.VK_SHIFT),
        15,
    )) {
        mods.shift = true;
    }
    if (isBitSet(
        win32_input.GetKeyState(win32_input.VK_CONTROL),
        15,
    )) {
        mods.ctrl = true;
    }
    if (isBitSet(win32_input.GetKeyState(win32_input.VK_MENU), 15)) {
        mods.alt = true;
    }
    if (isBitSet(
        (win32_input.GetKeyState(win32_input.VK_LWIN) |
            win32_input.GetKeyState(win32_input.VK_RWIN)),
        15,
    )) {
        mods.meta = true;
    }
    if (isBitSet(win32_input.GetKeyState(win32_input.VK_CAPITAL), 0)) {
        mods.caps_lock = true;
    }
    if (isBitSet(win32_input.GetKeyState(win32_input.VK_NUMLOCK), 0)) {
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

    const virtual_keys = comptime [4]win32_input.VIRTUAL_KEY{
        win32_input.VK_LSHIFT,
        win32_input.VK_RSHIFT,
        win32_input.VK_LWIN,
        win32_input.VK_RWIN,
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
                win32_input.GetKeyState(virtual_keys[index]),
                15,
            );
            if (is_key_up) {
                window.data.input.keys[@intCast(@intFromEnum(codes[index]))] = KeyState.Released;
                const fake_event = event.createKeyboardEvent(
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

pub inline fn getMousePosition(lparam: win32.LPARAM) geometry.Point2D {
    const xpos = win32_macros.getXLparam(@bitCast(lparam));
    const ypos = win32_macros.getYLparam(@bitCast(lparam));
    return geometry.Point2D{ .x = xpos, .y = ypos };
}

/// Posts a zig error code to the window's thread queue.
pub inline fn postWindowErrorMsg(e: wndw.WindowError, window: win32.HWND) void {
    const ret = win32_gfx.PostMessageW(
        window,
        wndw.WM_ERROR_REPORT,
        @intFromError(e),
        0,
    );

    if (ret == win32.FALSE) {
        // This should only happen if we flood system thread queue
        // with messages which is highly unlikley since the default
        // size allows for 10_000, if that happens our app should
        // just panic.
        @panic("Fatal error, exhausted system ressources");
    }
}
