//! This file contains helper function to use on the linux platforms
const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const maxInt = std.math.maxInt;
const ScanCode = common.keyboard_and_mouse.ScanCode;

pub const DEFAULT_SCREEN_DPI: f32 = @as(f32, 96);

pub inline fn strCpy(src: [*:0]const u8, dst: [*]u8, count: usize) void {
    for (0..count) |i| {
        dst[i] = src[i];
    }
}

pub inline fn strZLen(src: [*:0]const u8) usize {
    return std.mem.len(src);
}

/// returns true if both strings are equals.
pub inline fn strZEquals(a: [*:0]const u8, b: [*:0]const u8) bool {
    return (std.mem.orderZ(u8, a, b) == std.math.Order.eq);
}

/// Takes 2 many-items-pointers and compares the first `n` items
/// the caller should make sure that n isn't outside the pointers bounds.
pub inline fn bytesCmp(a: [*]const u8, b: [*]const u8, n: usize) bool {
    for (0..n) |i| {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

pub const WindowPropError = error{
    BadPropType,
    PropNotFound,
};

pub fn x11WindowProperty(
    display: *libx11.Display,
    w: libx11.Window,
    property: libx11.Atom,
    prop_type: libx11.Atom,
    value: ?[*]?[*]u8,
) WindowPropError!u32 {
    const MAX_C_LONG = @as(c_long, maxInt(c_long));
    var actual_type: libx11.Atom = undefined;
    var actual_format: c_int = undefined;
    var nitems: c_ulong = 0;
    var bytes_after: c_ulong = undefined;
    const result = libx11.XGetWindowProperty(
        display,
        w,
        property,
        0,
        MAX_C_LONG,
        libx11.False,
        prop_type,
        &actual_type,
        &actual_format,
        &nitems,
        &bytes_after,
        value,
    );

    if (result != libx11.Success) {
        if (actual_type != libx11.None and actual_type != prop_type) {
            return WindowPropError.BadPropType;
        }
        return WindowPropError.PropNotFound;
    }
    // make sure no bytes are left behind.
    std.debug.assert(bytes_after == 0);
    return @intCast(nitems);
}

/// Returns the state of the Key Modifiers for the current event,
/// by decoding the state field.
pub fn decodeKeyMods(state: c_uint) common.keyboard_and_mouse.KeyModifiers {
    return .{
        .shift = ((state & libx11.ShiftMask != 0)),
        .ctrl = ((state & libx11.ControlMask != 0)),
        .alt = ((state & libx11.Mod1Mask != 0)),
        .num_lock = ((state & libx11.Mod2Mask != 0)),
        .meta = ((state & libx11.Mod4Mask != 0)),
        .caps_lock = ((state & libx11.LockMask != 0)),
    };
}

pub fn fixKeyMods(
    mods: *common.keyboard_and_mouse.KeyModifiers,
    keycode: common.keyboard_and_mouse.KeyCode,
    key_state: common.keyboard_and_mouse.KeyState,
) void {
    //INFO:
    // whenever a modifier key is pressed it's bit in the modifiers state won't be set
    // when the event is reported by x11 and when it's released it the it's bit will be set
    // in the modifiers state that we recieve from the event it's like some kind of lag,
    // this differs from the behaviour found on windows in order to have matching behaviour
    // on both platforms we check the keycode and set the flags accordingly.
    if (key_state == .Pressed) {
        mods.shift = (mods.shift or keycode == .Shift);
        mods.ctrl = (mods.ctrl or keycode == .Control);
        mods.alt = (mods.alt or keycode == .Alt);
        mods.num_lock = (mods.num_lock or keycode == .NumLock);
        mods.meta = (mods.meta or keycode == .Meta);
        mods.caps_lock = (mods.caps_lock or keycode == .CapsLock);
    } else {
        mods.shift = (mods.shift and keycode != .Shift);
        mods.ctrl = (mods.ctrl and keycode != .Control);
        mods.alt = (mods.alt and keycode != .Alt);
        mods.num_lock = (mods.num_lock and keycode != .NumLock);
        mods.meta = (mods.meta and keycode != .Meta);
        mods.caps_lock = (mods.caps_lock and keycode != .CapsLock);
    }
}
