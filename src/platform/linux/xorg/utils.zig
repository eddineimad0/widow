//! This file contains helper function to use on the linux platforms
const std = @import("std");
pub inline fn strCpy(src: [*:0]const u8, dst: [*]u8, count: usize) void {
    // TODO: SIMD copy or just use libc copy.
    for (0..count) |i| {
        dst[i] = src[i];
    }
}

pub inline fn strLen(src: [*:0]const u8) usize {
    return std.mem.len(src);
}
