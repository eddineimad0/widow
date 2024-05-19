const internals = @import("internals.zig");
const win32 = @import("win32_defs.zig");

pub const window = @import("window.zig");
pub const MonitorStore = internals.MonitorStore;
pub const Internals = internals.Internals;

// Platform handles
pub const MonitorHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

const WidowContext = @import("driver.zig").Win32Driver;

pub fn initPlatform() !void {
    try WidowContext.initSingleton();
}

pub fn deinitPlatform() void {
    WidowContext.deinitSingleton();
}

// test "Win32Context_Thread_safety" {
//     const std = @import("std");
//     const builtin = @import("builtin");
//     if (builtin.single_threaded) {
//         try initPlatform(.{});
//         try initPlatform(.{});
//         defer deinitPlatform();
//     } else {
//         var threads: [10]std.Thread = undefined;
//         defer for (threads) |handle| handle.join();
//
//         for (&threads) |*handle| {
//             handle.* = try std.Thread.spawn(.{}, struct {
//                 fn thread_fn() !void {
//                     try initPlatform(.{});
//                 }
//             }.thread_fn, .{});
//         }
//     }
// }

test "Platform" {
    @import("std").testing.refAllDecls(@import("display.zig"));
    @import("std").testing.refAllDecls(@import("module.zig"));
}
