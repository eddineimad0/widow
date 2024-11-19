const std = @import("std");
const wl_dyn = @import("wl/funcs.zig");
const wl_interfaces = @import("wl/ifaces.zig");
const drvr = @import("driver.zig");
const unix = @import("common").unix;
const log = std.log;

pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub fn initPlatform() !void {
    wl_dyn.initDynamicApi() catch |e| {
        log.err("[Wayland] {s}\n", .{unix.moduleErrorMsg()});
        return e;
    };
    wl_interfaces.loadIfaces() catch |e| {
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
