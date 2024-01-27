const std = @import("std");
const posix = @import("common").posix;
const X11Context = @import("global.zig").X11Context;
const internals = @import("internals.zig");
const monitor_impl = @import("monitor_impl.zig");
const dyn_x11 = @import("x11/dynamic.zig");

pub const Internals = internals.Internals;
pub const MonitorStore = internals.MonitorStore;
pub const window_impl = @import("window_impl.zig");

pub fn initPlatform(options: anytype) !void {
    // TODO: Check for possible customization.
    _ = options;
    dyn_x11.initDynamicApi() catch |e| {
        std.log.err("[X11] {s}\n", .{posix.moduleErrorMsg()});
        return e;
    };
    try X11Context.initSingleton();
}

pub fn deinitPlatform() void {
    X11Context.deinitSingleton();
    dyn_x11.deinitDynamicApi();
}
