const std = @import("std");
const X11Context = @import("global.zig").X11Context;
pub const internals = @import("internals.zig");
pub const window_impl = @import("window_impl.zig");
const monitor_impl = @import("monitor_impl.zig");

pub fn initPlatform(options: anytype) !void {
    _ = options;
    try X11Context.initSingleton();
}

pub fn deinitPlatform() void {
    X11Context.deinitSingleton();
}
