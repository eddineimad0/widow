const internals = @import("internals.zig");
const win32 = @import("win32_defs.zig");
const display = @import("display.zig");

pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;
pub const MonitorStore = internals.MonitorStore;
pub const Internals = internals.Internals;

pub const DisplayManager = display.DisplayManager;

// Platform handles
pub const DisplayHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

const PlatformDriver = @import("driver.zig").Win32Driver;

pub fn initPlatform() !void {
    try PlatformDriver.initSingleton();
}

pub fn deinitPlatform() void {
    PlatformDriver.deinitSingleton();
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
