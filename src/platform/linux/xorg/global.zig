const std = @import("std");
const module = @import("module.zig");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions.zig");

const X11Handles = struct {
    xdisplay: *libx11.Display,
    root_window: libx11.Window,
    default_screen: u32,
    xrandr: ?*anyopaque,
    xinerama: ?*anyopaque,
};

// XRandRInterf
const XRRInterface = struct {
    is_v1point3: bool,
    XRRGetScreenResourcesCurrent: x11ext.XRRGetScreenResourcesCurrentProc,
    XRRGetScreenResources: x11ext.XRRGetScreenResourcesProc,
    XRRFreeScreenResources: x11ext.XRRFreeScreenResourcesProc,
    XRRGetCrtcInfo: x11ext.XRRGetCrtcInfoProc,
    XRRFreeCrtcInfo: x11ext.XRRFreeCrtcInfoProc,
    XRRGetOutputInfo: x11ext.XRRGetOutputInfoProc,
    XRRFreeOutputInfo: x11ext.XRRFreeOutputInfoProc,
    XRRGetOutputPrimary: x11ext.XRRGetOutputPrimaryProc,
    XRRSelectInput: x11ext.XRRSelectInputProc,
    XRRQueryVersion: x11ext.XRRQueryVersionProc,
};

// XineramaIntef
const XrmInterface = struct {
    is_active: bool,
    IsActive: x11ext.XineramaIsActiveProc,
    QueryScreens: x11ext.XineramaQueryScreens,
};

const X11Extensions = struct {
    xrandr: XRRInterface,
    xinerama: XrmInterface,
};

pub const X11Context = struct {
    handles: X11Handles,
    extensions: X11Extensions,
    var mutex: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;

    var globl_instance: X11Context = X11Context{
        .handles = X11Handles{
            .xdisplay = undefined,
            .root_window = undefined,
            .default_screen = undefined,
            .xrandr = null,
            .xinerama = null,
        },
        .extensions = X11Extensions{
            .xrandr = XRRInterface{
                .is_v1point3 = false,
                .XRRGetCrtcInfo = undefined,
                .XRRSelectInput = undefined,
                .XRRFreeCrtcInfo = undefined,
                .XRRGetOutputInfo = undefined,
                .XRRFreeOutputInfo = undefined,
                .XRRGetOutputPrimary = undefined,
                .XRRGetScreenResourcesCurrent = undefined,
                .XRRGetScreenResources = undefined,
                .XRRFreeScreenResources = undefined,
                .XRRQueryVersion = undefined,
            },
            .xinerama = XrmInterface{
                .is_active = false,
                .IsActive = undefined,
                .QueryScreens = undefined,
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
            libx11.XrmInitialize();
            // Grab the default screen(monitor) and the root window on it.
            g_instance.handles.default_screen = @intCast(libx11.DefaultScreen(g_instance.handles.xdisplay));
            g_instance.handles.root_window = libx11.RootWindow(g_instance.handles.xdisplay, g_instance.handles.default_screen);

            g_instance.loadXExtensions();
            Self.g_init = true;
        }
    }

    pub fn deinitSingleton() void {
        @setCold(true);
        Self.mutex.lock();
        defer Self.mutex.unlock();
        if (Self.g_init) {
            Self.g_init = false;
            _ = libx11.XCloseDisplay(globl_instance.handles.xdisplay);
            globl_instance.unloadXExtensions();
        }
    }

    fn loadXExtensions(self: *Self) void {
        self.handles.xinerama = module.loadPosixModule("libXinerama.so.1");
        if (self.handles.xinerama) |handle| {
            self.extensions.xinerama.IsActive = @ptrCast(module.moduleSymbol(handle, "XineramaIsActive").?);
            self.extensions.xinerama.QueryScreens = @ptrCast(module.moduleSymbol(
                handle,
                "XineramaQueryScreens",
            ).?);
            self.extensions.xinerama.is_active = (self.extensions.xinerama.IsActive(self.handles.xdisplay) != 0);
        } else {
            std.log.warn("[X11]: Xinerama library not found.\n", .{});
        }

        self.handles.xrandr = module.loadPosixModule("libXrandr.so.2");
        if (self.handles.xrandr) |handle| {
            self.extensions.xrandr.XRRGetCrtcInfo = @ptrCast(module.moduleSymbol(handle, "XRRGetCrtcInfo"));
            self.extensions.xrandr.XRRFreeCrtcInfo = @ptrCast(module.moduleSymbol(handle, "XRRFreeCrtcInfo"));
            self.extensions.xrandr.XRRGetOutputInfo = @ptrCast(module.moduleSymbol(handle, "XRRGetOutputInfo"));
            self.extensions.xrandr.XRRSelectInput = @ptrCast(module.moduleSymbol(handle, "XRRSelectInput"));
            self.extensions.xrandr.XRRFreeOutputInfo = @ptrCast(module.moduleSymbol(
                handle,
                "XRRFreeOutputInfo",
            ));
            self.extensions.xrandr.XRRGetOutputPrimary = @ptrCast(
                module.moduleSymbol(handle, "XRRGetOutputPrimary"),
            );
            self.extensions.xrandr.XRRGetScreenResourcesCurrent = @ptrCast(
                module.moduleSymbol(handle, "XRRGetScreenResourcesCurrent"),
            );
            self.extensions.xrandr.XRRGetScreenResources = @ptrCast(
                module.moduleSymbol(handle, "XRRGetScreenResources"),
            );
            self.extensions.xrandr.XRRFreeScreenResources = @ptrCast(
                module.moduleSymbol(handle, "XRRFreeScreenResources"),
            );
            self.extensions.xrandr.XRRQueryVersion = @ptrCast(
                module.moduleSymbol(handle, "XRRQueryVersion"),
            );
            var minor: i32 = 0;
            var major: i32 = 0;
            _ = self.extensions.xrandr.XRRQueryVersion(self.handles.xdisplay, &major, &minor);
            self.extensions.xrandr.is_v1point3 = (major >= 1 and minor >= 3);
        } else {
            std.log.warn("[X11]: XRandR library not found.\n", .{});
        }
    }

    fn unloadXExtensions(self: *Self) void {
        if (self.handles.xinerama) |handle| {
            module.freePosixModule(handle);
            self.handles.xinerama = null;
        }

        if (self.handles.xrandr) |handle| {
            module.freePosixModule(handle);
            self.handles.xrandr = null;
        }
    }

    // Enfoce readonly.
    pub fn singleton() *const Self {
        std.debug.assert(g_init == true);
        return &Self.globl_instance;
    }
};

test "X11Context Thread safety" {
    const testing = std.testing;
    _ = testing;
    const builtin = @import("builtin");
    if (builtin.single_threaded) {
        try X11Context.initSingleton();
        try X11Context.initSingleton();
        defer X11Context.deinitSingleton();
    } else {
        var threads: [10]std.Thread = undefined;
        defer for (threads) |handle| handle.join();

        for (&threads) |*handle| {
            handle.* = try std.Thread.spawn(.{}, struct {
                fn thread_fn() !void {
                    try X11Context.initSingleton();
                    defer X11Context.deinitSingleton();
                }
            }.thread_fn, .{});
        }
    }
}

test "Win32Context init" {
    try X11Context.initSingleton();
    const singleton = X11Context.singleton();
    std.debug.print("\nX11 execution context:\n", .{});
    std.debug.print("[+] Handles: {any}\n", .{singleton.handles});
    std.debug.print("[+] XRRInterface: {any}\n", .{singleton.extensions.xrandr});
    std.debug.print("[+] XineramaIntef: {any}\n", .{singleton.extensions.xinerama});
    X11Context.deinitSingleton();
}
