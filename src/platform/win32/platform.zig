const internals = @import("internals.zig");
const win32 = @import("win32_defs.zig");

pub const window_impl = @import("window_impl.zig");
pub const MonitorStore = internals.MonitorStore;
pub const Internals = internals.Internals;

// Platform handles
pub const MonitorHandle = win32.HMONITOR;
pub const WindowHandle = @import("std").os.windows.HWND;

const WidowContext = @import("global.zig").Win32Context;

pub fn initPlatform(options: anytype) !void {
    const window_class = if (@hasField(@TypeOf(options), "wnd_class"))
        @field(options, "wnd_class")
    else
        "WIDOW_CLASS";

    const res_icon = if (@hasField(@TypeOf(options), "res_icon"))
        @field(options, "res_icon")
    else
        null;

    try WidowContext.initSingleton(window_class, res_icon);
}

pub fn deinitPlatform() void {
    WidowContext.deinitSingleton();
}

test "Win32Context_Thread_safety" {
    const std = @import("std");
    const builtin = @import("builtin");
    if (builtin.single_threaded) {
        try initPlatform(.{});
        try initPlatform(.{});
        defer deinitPlatform();
    } else {
        var threads: [10]std.Thread = undefined;
        defer for (threads) |handle| handle.join();

        for (&threads) |*handle| {
            handle.* = try std.Thread.spawn(.{}, struct {
                fn thread_fn() !void {
                    try initPlatform(.{});
                }
            }.thread_fn, .{});
        }
    }
}
