const std = @import("std");
const X11Context = @import("global.zig").X11Context;

pub fn initPlatform(options: anytype) !void {
    _ = options;
    std.debug.print("X11 init\n", .{});
    try X11Context.initSingleton();
}

pub fn deinitPlatform() void {
    X11Context.deinitSingleton();
}
