//! This file contains helper function to use on the linux platforms
const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const maxInt = std.math.maxInt;
const ScanCode = common.keyboard_and_mouse.ScanCode;

pub const DEFAULT_SCREEN_DPI: f32 = @as(f32, 96);

pub inline fn strCpy(src: [*:0]const u8, dst: [*]u8, count: usize) void {
    // TODO: is there any benefit in using libc strCpy.
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
    var mods = common.keyboard_and_mouse.KeyModifiers{
        .shift = (state & libx11.ShiftMask != 0),
        .ctrl = (state & libx11.ControlMask != 0),
        .alt = (state & libx11.Mod1Mask != 0),
        .num_lock = (state & libx11.Mod2Mask != 0),
        .meta = (state & libx11.Mod4Mask != 0),
        .caps_lock = (state & libx11.LockMask != 0),
    };
    return mods;
}
