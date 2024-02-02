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
    const res_name = if (@hasField(@TypeOf(options), "xres_name"))
        @field(options, "xres_name")
    else
        std.c.getenv("RESOURCE_NAME") orelse "";

    const res_class = if (@hasField(@TypeOf(options), "xres_class"))
        @field(options, "xres_class")
    else
        "WIDOW_CLASS";

    dyn_x11.initDynamicApi() catch |e| {
        std.log.err("[X11] {s}\n", .{posix.moduleErrorMsg()});
        return e;
    };

    try X11Context.initSingleton(res_name, res_class);
}

pub fn deinitPlatform() void {
    X11Context.deinitSingleton();
    dyn_x11.deinitDynamicApi();
}

// TODO: these tests fails when the are all run, but only running one
// seems to succeed ?.

// test "X11Context Thread safety" {
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

// test "X11Context init" {
//     try initPlatform(.{});
//     defer deinitPlatform();
//     const singleton = X11Context.singleton();
//     std.debug.print("\nX11 execution context:\n", .{});
//     std.debug.print("[+] DPI:{d},Scale:{d}\n", .{ singleton.g_dpi, singleton.g_screen_scale });
//     std.debug.print("[+] Handles: {any}\n", .{singleton.handles});
//     std.debug.print("[+] XRRInterface: {any}\n", .{singleton.extensions.xrandr});
//     std.debug.print("[+] XineramaIntef: {any}\n", .{singleton.extensions.xinerama});
//     std.debug.print("[+] EWMH:{any}\n", .{singleton.ewmh});
// }

// test "XContext management" {
//     const testing = std.testing;
//     try initPlatform(.{});
//     defer deinitPlatform();
//     const singleton = X11Context.singleton();
//     var msg: [5]u8 = .{ 'H', 'E', 'L', 'L', 'O' };
//     try testing.expect(singleton.addToXContext(1, &msg));
//     var msg_alias_ptr = singleton.findInXContext(1);
//     try testing.expect(msg_alias_ptr != null);
//     std.debug.print("\nMSG={s}\n", .{@as(*[5]u8, @ptrCast(msg_alias_ptr.?)).*});
//     try testing.expect(singleton.removeFromXContext(1));
//     try testing.expect(!singleton.removeFromXContext(1));
//     msg_alias_ptr = singleton.findInXContext(1);
//     try testing.expect(msg_alias_ptr == null);
// }
