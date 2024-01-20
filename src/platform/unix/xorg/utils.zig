//! This file contains helper function to use on the linux platforms
const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const maxInt = std.math.maxInt;

pub inline fn strCpy(src: [*:0]const u8, dst: [*]u8, count: usize) void {
    // TODO: is there any benefit in using libc strCpy.
    for (0..count) |i| {
        dst[i] = src[i];
    }
}

pub inline fn strLen(src: [*:0]const u8) usize {
    return std.mem.len(src);
}

/// returns true if both strings are equals.
pub inline fn strEquals(a: [*:0]const u8, b: [*:0]const u8) bool {
    return (std.mem.orderZ(u8, a, b) == std.math.Order.eq);
}

pub fn x11WindowProperty(
    display: *libx11.Display,
    w: libx11.Window,
    property: libx11.Atom,
    prop_type: libx11.Atom,
    value: ?[*]?[*]u8,
) u32 {
    const MAX_C_LONG = @as(c_long, maxInt(c_long));
    var actual_type: libx11.Atom = undefined;
    var actual_format: c_int = undefined;
    var nitems: c_ulong = 0;
    var bytes_after: c_ulong = undefined;
    _ = libx11.XGetWindowProperty(
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
    std.debug.assert(bytes_after == 0);
    return @intCast(nitems);
}
