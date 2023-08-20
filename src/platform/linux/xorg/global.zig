const std = @import("std");
const module = @import("module.zig");
const libx11 = @import("x11/xlib.zig");

const X11Handles = struct {
    xdisplay: *libx11.Display,
    root_window: libx11.Window,
    screen: u32,
    xlib: ?*anyopaque,
    xrandr: ?*anyopaque,
};

const XRRInterface = struct {
    const proc_XRRGetScreenResourcesCurrent = *const fn (*libx11.Display, libx11.Window) void;
    // fields
    XRRGetScreenResourcesCurrent: ?proc_XRRGetScreenResourcesCurrent,
};

const LoadedFunctions = struct {
    xrandr: XRRInterface,
};

pub const X11Context = struct {
    handles: X11Handles,
    functions: LoadedFunctions,
    var mutex: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;

    var globl_instance: X11Context = X11Context{
        .handles = X11Handles{
            .xdisplay = undefined,
            .root_window = undefined,
            .screen = undefined,
            .xrandr = null,
            .xlib = null,
        },
        .functions = LoadedFunctions{
            .xrandr = XRRInterface{
                .XRRGetScreenResourcesCurrent = null,
            },
        },
    };

    const Self = @This();

    pub fn initSingleton() !void {
        @setCold(true);

        Self.mutex.lock();
        defer mutex.unlock();

        if (!Self.g_init) {
            const g_instance = &Self.globl_instance;
            // Open a connection to the X server.
            g_instance.handles.xdisplay = libx11.XOpenDisplay(null) orelse {
                return error.FailedToConnectToXServer;
            };
            // grab the root window.
            g_instance.handles.screen = @intCast(libx11.DefaultScreen(g_instance.handles.xdisplay));
            g_instance.handles.root_window = libx11.RootWindow(g_instance.handles.xdisplay, g_instance.handles.screen);

            std.debug.print("[Debug]: Default screen {d}| root window {d}\n", .{ g_instance.handles.screen, g_instance.handles.root_window });
            @atomicStore(bool, &Self.g_init, true, .Release);
        }
    }

    pub fn deinitSingleton() void {
        @setCold(true);
        if (Self.g_init) {
            Self.g_init = false;
            _ = libx11.XCloseDisplay(globl_instance.handles.xdisplay);
        }
    }

    fn loadXExtensions(self: *Self) !void {
        _ = self;
    }

    // fn freeLibraries(_: *Self) void {}

    // Enfoce readonly.
    pub fn singleton() *const Self {
        std.debug.assert(g_init == true);
        return &Self.globl_instance;
    }
};

// test "X11Context Thread safety" {
//     const testing = std.testing;
//     const builtin = @import("builtin");
//     if (builtin.single_threaded) {
//         const singleton = X11Context.singleton();
//         const singleton2 = X11Context.singleton();
//         try testing.expect(singleton != null);
//         try testing.expect(singleton2 != null);
//     } else {
//         var threads: [10]std.Thread = undefined;
//         defer for (threads) |handle| handle.join();
//
//         for (&threads) |*handle| {
//             handle.* = try std.Thread.spawn(.{}, struct {
//                 fn thread_fn() void {
//                     _ = X11Context.singleton();
//                 }
//             }.thread_fn, .{});
//         }
//     }
// }

test "Win32Context init" {
    const testing = std.testing;
    const singleton = X11Context.singleton();
    try testing.expect(singleton != null);
    std.debug.print("Win32 execution context: {any}\n", .{singleton.?});
}
