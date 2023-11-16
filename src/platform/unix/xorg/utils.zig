//! This file contains helper function to use on the linux platforms
const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const common = @import("common");
const maxInt = std.math.maxInt;

pub const MAX_C_LONG = @as(c_long, maxInt(c_long));

/// Drop in replacement for strCpy.
pub inline fn strCpy(src: [*:0]const u8, dst: [*]u8, count: usize) void {
    for (0..count) |i| {
        dst[i] = src[i];
    }
}

/// Drop in replacement for strLen.
pub inline fn strLen(src: [*:0]const u8) usize {
    return std.mem.len(src);
}

/// Drop in replacement for strCmp == 0
/// returns true if both strings are equals.
pub inline fn strEquals(a: [*:0]const u8, b: [*:0]const u8) bool {
    return (std.mem.orderZ(u8, a, b) == std.math.Order.eq);
}

pub const WindowPropError = error{
    BadPropType,
    PropNotFound,
};
/// a helper function for simplifying reading x11 windows properties
pub fn x11WindowProperty(display: ?*libx11.Display, w: libx11.Window, property: libx11.Atom, prop_type: libx11.Atom, value: ?[*]?[*]u8) WindowPropError!u32 {
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
    // make sure no bytes are left behind.
    if (result != libx11.Success) {
        if (actual_type != libx11.None and actual_type != prop_type) {
            return WindowPropError.BadPropType;
        }
        return WindowPropError.PropNotFound;
    }
    std.debug.assert(bytes_after == 0);
    std.debug.assert(nitems > 0);
    return @intCast(nitems);
}

pub fn debugPropError(e: WindowPropError, property: libx11.Atom) void {
    if (common.IS_DEBUG) {
        switch (e) {
            WindowPropError.PropNotFound => std.log.debug("Property:{} not found\n", .{property}),
            WindowPropError.BadPropType => std.log.debug("Specified type for property:{} doesn't match the actual type\n", .{property}),
        }
    }
}
