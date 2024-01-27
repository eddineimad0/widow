const std = @import("std");
const posix = @import("common").posix;
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions.zig");
const utils = @import("utils.zig");

pub const XConnectionError = error{
    ConnectionFailed,
    XRandRNotFound,
    XContextNoMem,
};

const X11Handles = struct {
    xdisplay: *libx11.Display,
    root_window: libx11.Window,
    default_screen: c_int,
    xcontext: libx11.XContext,
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
    XRRQueryVersion: x11ext.XRRQueryVersionProc,
    XRRSetCrtcConfig: x11ext.XRRSetCrtcConfigProc,
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

/// holds the various hints a window manager can have.
/// https://specifications.freedesktop.org/wm-spec/wm-spce-1.3.html
const X11EWMH = struct {
    //########### Root Window Propeties ##############
    _NET_SUPPORTING_WM_CHECK: libx11.Atom,
    // gives the window of the active WM.
    _NET_SUPPORTED: libx11.Atom,
    // lists all the EWMH protocols supported by this WM.
    _NET_CURRENT_DESKTOP: libx11.Atom,
    // gives the index of the current desktop.
    _NET_ACTIVE_WINDOW: libx11.Atom,
    // gives the currently active window.
    _NET_WORKAREA: libx11.Atom,
    // contains a geometry for each desktop.

    // _NET_NUMBER_OF_DESKTOPS: libx11.Atom,
    // indicates the number of virtual desktops.
    // _NET_VIRTUAL_ROOTS: libx11.Atom,
    // if the WM supports virtual root windows.
    // _NET_DESKTOP_VIEWPORT: libx11.Atom,
    // defines the top left corner of each desktop.
    // _NET_CLIENT_LIST
    // lists all application windows managed by this WM.
    // _NET_DESKTOP_GEOMETRY
    //     defines the common size of all desktops.
    // _NET_DESKTOP_NAMES
    //     lists the names of all virtual desktops.
    // _NET_DESKTOP_LAYOUT
    //     shows the layout of the active pager.
    // _NET_SHOWING_DESKTOP
    //     is 1 for "showing the desktop" mode.

    //############ Client messages ###############
    _NET_WM_STATE: libx11.Atom,
    _NET_WM_STATE_DEMANDS_ATTENTION: libx11.Atom,

    //########### Application Window Properties ##########
    _NET_WM_NAME: libx11.Atom,
    _NET_WM_VISIBLE_NAME: libx11.Atom,
    _NET_WM_ICON_NAME: libx11.Atom,
    _NET_WM_VISIBLE_ICON_NAME: libx11.Atom,
    _NET_WM_DESKTOP: libx11.Atom,

    //########## Property Types ################
    UTF8_STRING: libx11.Atom,
};

pub const X11Context = struct {
    handles: X11Handles,
    extensions: X11Extensions,
    ewmh: X11EWMH,
    g_dpi: f32,
    g_scale: f32,
    last_error_code: u8,
    last_error_handler: ?*libx11.XErrorHandlerFunc,
    var g_init_mutex: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;

    var globl_instance: X11Context = X11Context{
        .handles = X11Handles{
            .xdisplay = undefined,
            .root_window = undefined,
            .default_screen = undefined,
            .xcontext = undefined,
            .xrandr = null,
            .xinerama = null,
        },
        .extensions = X11Extensions{
            .xrandr = XRRInterface{
                .is_v1point3 = false,
                .XRRGetCrtcInfo = undefined,
                .XRRFreeCrtcInfo = undefined,
                .XRRGetOutputInfo = undefined,
                .XRRFreeOutputInfo = undefined,
                .XRRGetOutputPrimary = undefined,
                .XRRGetScreenResourcesCurrent = undefined,
                .XRRGetScreenResources = undefined,
                .XRRFreeScreenResources = undefined,
                .XRRQueryVersion = undefined,
                .XRRSetCrtcConfig = undefined,
            },
            .xinerama = XrmInterface{
                .is_active = false,
                .IsActive = undefined,
                .QueryScreens = undefined,
            },
        },
        .ewmh = X11EWMH{
            ._NET_SUPPORTING_WM_CHECK = 0,
            ._NET_SUPPORTED = 0,
            ._NET_CURRENT_DESKTOP = 0,
            ._NET_ACTIVE_WINDOW = 0,
            ._NET_WORKAREA = 0,
            ._NET_WM_STATE = 0,
            ._NET_WM_STATE_DEMANDS_ATTENTION = 0,

            ._NET_WM_NAME = 0,
            ._NET_WM_VISIBLE_NAME = 0,
            ._NET_WM_ICON_NAME = 0,
            ._NET_WM_VISIBLE_ICON_NAME = 0,
            ._NET_WM_DESKTOP = 0,

            .UTF8_STRING = 0,
        },
        .g_dpi = 0.0,
        .g_scale = 0.0,
        .last_error_code = 0,
        .last_error_handler = null,
    };

    const Self = @This();

    pub fn initSingleton() XConnectionError!void {
        @setCold(true);

        Self.g_init_mutex.lock();
        defer g_init_mutex.unlock();
        if (!Self.g_init) {
            const g_instance = &Self.globl_instance;
            // Open a connection to the X server.
            _ = libx11.XInitThreads();
            g_instance.handles.xdisplay = libx11.XOpenDisplay(null) orelse {
                return XConnectionError.ConnectionFailed;
            };
            // Grab the default screen(monitor) and the root window on it.
            g_instance.handles.default_screen = libx11.DefaultScreen(g_instance.handles.xdisplay);
            g_instance.handles.root_window = libx11.RootWindow(g_instance.handles.xdisplay, g_instance.handles.default_screen);

            try g_instance.loadXExtensions();
            g_instance.readSystemGlobalDPI();

            // read root window properties
            g_instance.ewmh._NET_SUPPORTING_WM_CHECK = libx11.XInternAtom(
                g_instance.handles.xdisplay,
                "_NET_SUPPORTING_WM_CHECK",
                libx11.False,
            );
            g_instance.ewmh._NET_SUPPORTED = libx11.XInternAtom(
                g_instance.handles.xdisplay,
                "_NET_SUPPORTED",
                libx11.False,
            );

            g_instance.ewmh.UTF8_STRING = libx11.XInternAtom(
                g_instance.handles.xdisplay,
                "UTF8_STRING",
                libx11.False,
            );

            g_instance.queryEWMH();

            g_instance.handles.xcontext = libx11.XUniqueContext();
            if (g_instance.handles.xcontext == 0) {
                return XConnectionError.XContextNoMem;
            }

            Self.g_init = true;
        }
    }

    pub fn deinitSingleton() void {
        @setCold(true);
        Self.g_init_mutex.lock();
        defer Self.g_init_mutex.unlock();
        if (Self.g_init) {
            Self.g_init = false;
            _ = libx11.XCloseDisplay(globl_instance.handles.xdisplay);
            globl_instance.unloadXExtensions();
        }
    }

    fn loadXExtensions(self: *Self) XConnectionError!void {
        self.handles.xrandr = posix.loadPosixModule(libx11.XORG_LIBS_NAME[libx11.LIB_XRANDR_INDEX]);
        if (self.handles.xrandr) |handle| {
            self.extensions.xrandr.XRRGetCrtcInfo = @ptrCast(
                posix.moduleSymbol(handle, "XRRGetCrtcInfo"),
            );
            self.extensions.xrandr.XRRFreeCrtcInfo = @ptrCast(
                posix.moduleSymbol(handle, "XRRFreeCrtcInfo"),
            );
            self.extensions.xrandr.XRRGetOutputInfo = @ptrCast(
                posix.moduleSymbol(handle, "XRRGetOutputInfo"),
            );
            self.extensions.xrandr.XRRFreeOutputInfo = @ptrCast(
                posix.moduleSymbol(handle, "XRRFreeOutputInfo"),
            );
            self.extensions.xrandr.XRRGetOutputPrimary = @ptrCast(
                posix.moduleSymbol(handle, "XRRGetOutputPrimary"),
            );
            self.extensions.xrandr.XRRGetScreenResourcesCurrent = @ptrCast(
                posix.moduleSymbol(handle, "XRRGetScreenResourcesCurrent"),
            );
            self.extensions.xrandr.XRRGetScreenResources = @ptrCast(
                posix.moduleSymbol(handle, "XRRGetScreenResources"),
            );
            self.extensions.xrandr.XRRFreeScreenResources = @ptrCast(
                posix.moduleSymbol(handle, "XRRFreeScreenResources"),
            );
            self.extensions.xrandr.XRRQueryVersion = @ptrCast(
                posix.moduleSymbol(handle, "XRRQueryVersion"),
            );
            self.extensions.xrandr.XRRSetCrtcConfig = @ptrCast(
                posix.moduleSymbol(handle, "XRRSetCrtcConfig"),
            );
            var minor: i32 = 0;
            var major: i32 = 0;
            _ = self.extensions.xrandr.XRRQueryVersion(self.handles.xdisplay, &major, &minor);
            self.extensions.xrandr.is_v1point3 = (major >= 1 and minor >= 3);
        } else {
            std.log.err("[X11]: XRandR library not found.\n", .{});
            // Error out since a lot functionalties rely on xrandr.
            return XConnectionError.XRandRNotFound;
        }

        self.handles.xinerama = posix.loadPosixModule(libx11.XORG_LIBS_NAME[libx11.LIB_XINERAMA_INDEX]);
        if (self.handles.xinerama) |handle| {
            self.extensions.xinerama.IsActive = @ptrCast(
                posix.moduleSymbol(handle, "XineramaIsActive").?,
            );
            self.extensions.xinerama.QueryScreens = @ptrCast(
                posix.moduleSymbol(handle, "XineramaQueryScreens").?,
            );
            self.extensions.xinerama.is_active = (self.extensions.xinerama.IsActive(self.handles.xdisplay) != 0);
        } else {
            std.log.warn("[X11]: Xinerama library not found.\n", .{});
        }
    }

    fn unloadXExtensions(self: *Self) void {
        if (self.handles.xinerama) |handle| {
            posix.freePosixModule(handle);
            self.handles.xinerama = null;
        }

        if (self.handles.xrandr) |handle| {
            posix.freePosixModule(handle);
            self.handles.xrandr = null;
        }
    }

    fn readSystemGlobalDPI(self: *Self) void {
        // INFO:
        // there is no per monitor dpi property in X11, there is only a global dpi property.
        // the property is set by the user to a value that works best for his highest resolution monitor
        // using it should give the user the best experience.
        // https://dec05eba.com/2021/10/11/x11-multiple-monitor-dpi-trick/

        // if we fail dpi will default to 96.
        var dpi: f32 = 96.0;
        libx11.XrmInitialize();
        const res_str = libx11.XResourceManagerString(self.handles.xdisplay);
        if (res_str) |s| {
            const db = libx11.XrmGetStringDatabase(s);
            defer libx11.XrmDestroyDatabase(db);
            var value_type: ?[*:0]const u8 = null;
            var value: libx11.XrmValue = undefined;
            _ = libx11.XrmGetResource(db, "Xft.dpi", "Xft.Dpi", &value_type, &value);
            if (value_type) |t| {
                if (utils.strEquals(t, "String")) {
                    var src: []const u8 = undefined;
                    src.len = value.size;
                    src.ptr = value.addr.?;
                    dpi = std.fmt.parseFloat(f32, src) catch 96.0;
                }
            }
        }

        self.g_dpi = dpi;
        self.g_scale = dpi / 96.0;
    }

    /// changes the x server protocol error handler
    /// Note: 2 calls to this function must be separated by a call to
    /// unsetXErrorHandler,
    pub fn setXErrorHandler(self: *Self) void {
        std.debug.print("\nlast_error_handler:{?}\n", .{self.last_error_handler});
        std.debug.assert(self.last_error_handler == null);
        // clear last error.
        self.last_error_code = 0;
        self.last_error_handler = libx11.XSetErrorHandler(handleXError);
    }

    /// returns an error if the last error_code is not 0.
    pub fn unsetXErrorHandler(self: *Self) !void {
        libx11.XSync(self.handles.xdisplay, libx11.False);
        _ = libx11.XSetErrorHandler(self.last_error_handler);
        self.last_error_handler = null;
        if (self.last_error_code != 0) {
            // TODO:
            std.debug.print("\n[-] Error \n", .{});
            return error.ConnectionError;
        }
    }

    // TODO: report error
    // pub fn errorMsg()

    fn queryEWMH(self: *Self) void {

        // if the _NET_WM_SUPPORTING_WM_CHECK is missing client should
        // assume a non conforming window manager is present
        var window_ptr: ?*libx11.Window = null;
        if (utils.x11WindowProperty(
            self.handles.xdisplay,
            self.handles.root_window,
            self.ewmh._NET_SUPPORTING_WM_CHECK,
            libx11.XA_WINDOW,
            @ptrCast(&window_ptr),
        ) == 0) {
            // non conforming.
            return;
        }

        std.debug.assert(window_ptr != null);
        defer _ = libx11.XFree(window_ptr.?);

        // on success the window_ptr points to the id of the child window created by
        // the window manager.
        // this window must also have _NET_WM_SUPPORTING_WM_CHECK property
        // set to the same id(the id of the child window).

        var child_window_ptr: ?*libx11.Window = null;
        if (utils.x11WindowProperty(
            self.handles.xdisplay,
            window_ptr.?.*,
            self.ewmh._NET_SUPPORTING_WM_CHECK,
            libx11.XA_WINDOW,
            @ptrCast(&child_window_ptr),
        ) == 0) {
            return;
        }

        std.debug.assert(child_window_ptr != null);
        defer _ = libx11.XFree(child_window_ptr.?);

        if (window_ptr.?.* != child_window_ptr.?.*) {
            // breaks the rules.
            return;
        }

        // the window manager is EWMH-compliant we can get
        // a list of all supported features through the _NET_SUPPORTED
        // property on the root window.

        var supported: ?[*]libx11.Atom = null;
        const atom_count = utils.x11WindowProperty(
            self.handles.xdisplay,
            self.handles.root_window,
            self.ewmh._NET_SUPPORTED,
            libx11.XA_ATOM,
            @ptrCast(&supported),
        );

        if (atom_count == 0) {
            std.debug.print("\n 0 Supported atoms\n", .{});
            return;
        }

        std.debug.assert(supported != null);
        defer _ = libx11.XFree(supported.?);

        // Easy shortcut but require the field.name to be 0 terminated
        // since it will be passed to a c function.
        const MAX_NAME_LENGTH = 256;
        var field_name: [MAX_NAME_LENGTH]u8 = undefined;
        const info = @typeInfo(X11EWMH);
        inline for (info.Struct.fields) |*f| {
            // skip those that were already set
            if (comptime std.mem.eql(u8, "_NET_SUPPORTING_WM_CHECK", f.name)) {
                continue;
            }
            if (comptime std.mem.eql(u8, "_NET_SUPPORTED", f.name)) {
                continue;
            }
            if (comptime std.mem.eql(u8, "UTF8_STRING", f.name)) {
                continue;
            }
            if (comptime f.name.len > MAX_NAME_LENGTH - 1) {
                @compileError("EWMH Field name is greater than the maximum buffer length");
            }
            std.mem.copyForwards(u8, &field_name, f.name);
            field_name[f.name.len] = 0;
            @field(self.ewmh, f.name) = atomIfSupported(
                self.handles.xdisplay,
                supported.?,
                atom_count,
                @ptrCast(&field_name),
            );
        }
    }

    /// Sends all requests currently in the xlib output bufffer
    /// to the x server.
    /// doesn't block since it use XFlush.
    pub inline fn flushXRequests(self: *const Self) void {
        _ = libx11.XFlush(self.handles.xdisplay);
    }

    /// Attempts to read an event from the event queue without blocking
    /// and copys it to the event param.
    /// returns true if the event parameter was populated,
    /// false otherwise.
    pub inline fn nextXEvent(self: *const Self, e: *libx11.XEvent) bool {
        if (libx11.XQLength(self.handles.xdisplay) == 0) {
            return false;
        }
        _ = libx11.XNextEvent(self.handles.xdisplay, e);
        return true;
    }

    pub inline fn addToXContext(
        self: *const Self,
        window_id: libx11.Window,
        data: [*]u8,
    ) bool {
        return (libx11.XSaveContext(
            self.handles.xdisplay,
            window_id,
            self.handles.xcontext,
            data,
        ) == 0);
    }

    pub inline fn removeFromXContext(
        self: *const Self,
        window_id: libx11.Window,
    ) bool {
        return (libx11.XDeleteContext(
            self.handles.xdisplay,
            window_id,
            self.handles.xcontext,
        ) == 0);
    }

    pub inline fn findInXContext(
        self: *const Self,
        window_id: libx11.Window,
    ) ?[*]u8 {
        var data_return: ?[*]u8 = null;
        var result = libx11.XFindContext(
            self.handles.xdisplay,
            window_id,
            self.handles.xcontext,
            &data_return,
        );
        if (result != 0) {
            std.debug.assert(data_return == null);
        }
        return data_return;
    }

    // Enfoce readonly.
    pub fn singleton() *const Self {
        std.debug.assert(g_init == true);
        return &Self.globl_instance;
    }

    // TODO: find a better way to check for X11 errors.
    pub fn mutSingelton() *Self {
        std.debug.assert(g_init == true);
        return &Self.globl_instance;
    }
};

/// check the supported atoms for a specified atom name
/// if found it returns the atom
/// if not it returns 0.
fn atomIfSupported(display: ?*libx11.Display, supported: [*]libx11.Atom, atom_count: u32, atom_name: [*:0]const u8) libx11.Atom {
    const atom = libx11.XInternAtom(display, atom_name, libx11.False);

    for (0..atom_count) |i| {
        if (supported[i] == atom) {
            return atom;
        }
    }

    return 0;
}

fn handleXError(display: ?*libx11.Display, err: *libx11.XErrorEvent) callconv(.C) c_int {
    const x11cntxt = X11Context.mutSingelton();
    if (x11cntxt.handles.xdisplay != display) {
        return 0;
    }
    // TODO: saftey concerns ? of mutating the global constant.
    x11cntxt.last_error_code = err.error_code;
    return 0;
}

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

test "X11Context init" {
    try X11Context.initSingleton();
    const singleton = X11Context.singleton();
    std.debug.print("\nX11 execution context:\n", .{});
    std.debug.print("[+] DPI:{d},Scale:{d}\n", .{ singleton.g_dpi, singleton.g_scale });
    std.debug.print("[+] Handles: {any}\n", .{singleton.handles});
    std.debug.print("[+] XRRInterface: {any}\n", .{singleton.extensions.xrandr});
    std.debug.print("[+] XineramaIntef: {any}\n", .{singleton.extensions.xinerama});
    std.debug.print("[+] EWMH:{any}\n", .{singleton.ewmh});
    X11Context.deinitSingleton();
}

test "XContext management" {
    const testing = std.testing;
    try X11Context.initSingleton();
    const singleton = X11Context.singleton();
    var msg: [5]u8 = .{ 'H', 'E', 'L', 'L', 'O' };
    try testing.expect(singleton.addToXContext(1, &msg));
    var msg_alias_ptr = singleton.findInXContext(1);
    try testing.expect(msg_alias_ptr != null);
    std.debug.print("\nMSG={s}\n", .{@as(*[5]u8, @ptrCast(msg_alias_ptr.?)).*});
    try testing.expect(singleton.removeFromXContext(1));
    try testing.expect(!singleton.removeFromXContext(1));
    msg_alias_ptr = singleton.findInXContext(1);
    try testing.expect(msg_alias_ptr == null);
}
