const std = @import("std");
const monitor_impl = @import("display.zig");
const dyn_x11 = @import("x11/dynamic.zig");
const unix = @import("common").unix;
const X11Driver = @import("driver.zig").X11Driver;
const KeyMaps = @import("keymaps.zig").KeyMaps;

pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub fn initPlatform() !void {
    dyn_x11.initDynamicApi() catch |e| {
        std.log.err("[X11] {s}\n", .{unix.moduleErrorMsg()});
        return e;
    };

    try X11Driver.initSingleton();
    KeyMaps.initSingleton();
}

pub fn deinitPlatform() void {
    X11Driver.deinitSingleton();
    KeyMaps.deinitSingleton();
}

// test "initPlatform Thread safety" {
//     const builtin = @import("builtin");
//     if (builtin.single_threaded) {
//         try initPlatform(.{});
//         try initPlatform(.{});
//         deinitPlatform();
//     } else {
//         var threads: [10]std.Thread = undefined;
//         defer for (threads) |handle| handle.join();
//
//         for (&threads) |*handle| {
//             handle.* = try std.Thread.spawn(.{}, struct {
//                 fn thread_fn() !void {
//                     try initPlatform(.{});
//                     defer deinitPlatform();
//                 }
//             }.thread_fn, .{});
//         }
//     }
// }
