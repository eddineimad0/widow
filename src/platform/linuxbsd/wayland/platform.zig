const std = @import("std");
const log = std.log;
const dyn_wl = @import("wl/func.zig");
const unix = @import("common").unix;

pub fn initPlatform() !void {
    dyn_wl.initDynamicApi() catch |e| {
        log.err("[X11] {s}\n", .{unix.moduleErrorMsg()});
        return e;
    };

}

pub fn deinitPlatform() void {
}

