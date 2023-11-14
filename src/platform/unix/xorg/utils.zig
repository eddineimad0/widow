//! This file contains helper function to use on the linux platforms
const std = @import("std");
const maxInt = std.math.maxInt;

pub const MAX_C_LONG = @as(c_long, maxInt(c_long));

/// Drop in replacement for strCpy.
pub inline fn strCpy(src: [*:0]const u8, dst: [*]u8, count: usize) void {
    // TODO: SIMD copy or just use libc copy.
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
