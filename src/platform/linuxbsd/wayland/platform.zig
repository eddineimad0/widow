const std = @import("std");
const dyn_wl = @import("wl/funcs.zig");
const drvr = @import("driver.zig");
const unix = @import("common").unix;
const log = std.log;

pub fn initPlatform() !void {
    dyn_wl.initDynamicApi() catch |e| {
        log.err("[Wayland] {s}\n", .{unix.moduleErrorMsg()});
        return e;
    };

    try drvr.WlDriver.initSingleton();
}

pub fn deinitPlatform() void {
}




test "temp" {
    try initPlatform();
}
