const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const utils = @import("utils.zig");
const unix = common.unix;

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

const XRRInterface = struct {
    is_v1point3: bool,
    // TODO: should the functions pointers be optional ?
    XRRGetScreenResourcesCurrent: x11ext.XRRGetScreenResourcesCurrentProc,
    XRRGetScreenResources: x11ext.XRRGetScreenResourcesProc,
    XRRFreeScreenResources: x11ext.XRRFreeScreenResourcesProc,
    XRRGetCrtcInfo: x11ext.XRRGetCrtcInfoProc,
    XRRFreeCrtcInfo: x11ext.XRRFreeCrtcInfoProc,
    XRRGetOutputInfo: x11ext.XRRGetOutputInfoProc,
    XRRFreeOutputInfo: x11ext.XRRFreeOutputInfoProc,
    XRRGetOutputPrimary: x11ext.XRRGetOutputPrimaryProc,
    XRRQueryVersion: x11ext.XRRQueryVersionProc,
    XRRQueryExtension: x11ext.XRRQueryExtensionProc,
    XRRSetCrtcConfig: x11ext.XRRSetCrtcConfigProc,
    XRRSelectInput: x11ext.XRRSelectInputProc,
    XRRUpdateConfiguration: x11ext.XRRUpdateConfigurationProc,
    event_code: c_int,
};

const XrmInterface = struct {
    is_active: bool,
    IsActive: x11ext.XineramaIsActiveProc,
    QueryScreens: x11ext.XineramaQueryScreens,
};

const XkbInterface = struct {
    is_available: bool,
    is_auto_repeat_detectable: bool,
    event_code: c_int,
};

const X11Extensions = struct {
    xrandr: XRRInterface,
    xinerama: XrmInterface,
    xkb: XkbInterface,
};

/// holds the value of various hints a window manager can have.
/// https://specifications.freedesktop.org/wm-spec/wm-spce-1.3.html
const X11EWMH = struct {
    // true if the window manager is ewmh compliant.
    is_wm_emwh: bool,
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
    _NET_WM_STATE_ABOVE: libx11.Atom,
    _NET_WM_STATE_FULLSCREEN: libx11.Atom,
    _NET_WM_STATE_MAXIMIZED_VERT: libx11.Atom,
    _NET_WM_STATE_MAXIMIZED_HORZ: libx11.Atom,
    _NET_WM_STATE_DEMANDS_ATTENTION: libx11.Atom,

    //########### Application Window Properties ##########
    _NET_WM_VISIBLE_NAME: libx11.Atom,
    _NET_WM_VISIBLE_ICON_NAME: libx11.Atom,
    _NET_WM_DESKTOP: libx11.Atom,

    // ########## Protocols #################
    // list atoms that identifies a communication protocol between
    // the client and the window manager in which
    // the client is willing to participate.
    WM_PROTOCOLS: libx11.Atom,
    // ping is used to check if a window is still alive and responding.
    _NET_WM_PING: libx11.Atom,
    // delete used to notify window of a close requests.
    WM_DELETE_WINDOW: libx11.Atom,

    //########## Property Types ################
    UTF8_STRING: libx11.Atom,
    WM_STATE: libx11.Atom,
    _NET_SUPPORTING_WM_CHECK: libx11.Atom,
    // lists all the EWMH protocols supported by this WM.
    _NET_SUPPORTED: libx11.Atom,
    _NET_WM_ICON: libx11.Atom,
    _NET_WM_PID: libx11.Atom,
    _NET_WM_NAME: libx11.Atom,
    _NET_WM_ICON_NAME: libx11.Atom,
    _NET_WM_BYPASS_COMPOSITOR: libx11.Atom,
    _NET_WM_WINDOW_OPACITY: libx11.Atom,
    _MOTIF_WM_HINTS: libx11.Atom,
    _NET_WM_FULLSCREEN_MONITORS: libx11.Atom,
    _NET_WM_WINDOW_TYPE: libx11.Atom,
    _NET_WM_WINDOW_TYPE_NORMAL: libx11.Atom,
    // contains a geometry for each desktop.
    _NET_WORKAREA: libx11.Atom,
    // gives the index of the current desktop.
    _NET_CURRENT_DESKTOP: libx11.Atom,
    // gives the currently active window.
    _NET_ACTIVE_WINDOW: libx11.Atom,
    _NET_FRAME_EXTENTS: libx11.Atom,
    _NET_REQUEST_FRAME_EXTENTS: libx11.Atom,
    //TODO: document.
    // Custom
};

pub const X11Driver = struct {
    handles: X11Handles,
    extensions: X11Extensions,
    ewmh: X11EWMH,
    pid: i32,
    g_dpi: f32,
    g_screen_scale: f32,
    var driver_guard: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;
    pub var CUSTOM_CLIENT_ERR: libx11.Atom = 0;
    // var last_error_handler: ?*const libx11.XErrorHandlerFunc = null;

    var globl_instance: X11Driver = X11Driver{
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
                .XRRUpdateConfiguration = undefined,
                .XRRSelectInput = undefined,
                .XRRQueryExtension = undefined,
                .event_code = 0,
            },
            .xinerama = XrmInterface{
                .is_active = false,
                .IsActive = undefined,
                .QueryScreens = undefined,
            },
            .xkb = XkbInterface{
                .is_available = false,
                .is_auto_repeat_detectable = false,
                .event_code = 0,
            },
        },
        .ewmh = undefined,
        .pid = undefined,
        .g_dpi = 0.0,
        .g_screen_scale = 0.0,
        // .resource_name = "",
        // .resource_class = "",
    };

    const Self = @This();

    pub fn initSingleton() XConnectionError!void {
        @setCold(true);

        Self.driver_guard.lock();
        defer driver_guard.unlock();
        if (!Self.g_init) {
            const g_instance = &Self.globl_instance;
            // g_instance.resource_name = ""; // TODO:
            // g_instance.resource_class = ""; // TODO:
            _ = libx11.XInitThreads();
            // Open a connection to the X server.
            g_instance.handles.xdisplay = libx11.XOpenDisplay(null) orelse {
                return XConnectionError.ConnectionFailed;
            };
            // Grab the default screen(monitor) and the root window on it.
            g_instance.handles.default_screen = libx11.DefaultScreen(
                g_instance.handles.xdisplay,
            );
            g_instance.handles.root_window = libx11.RootWindow(
                g_instance.handles.xdisplay,
                g_instance.handles.default_screen,
            );

            try g_instance.loadXExtensions();
            g_instance.readSystemGlobalDPI();

            g_instance.ewmh = std.mem.zeroes(@TypeOf(g_instance.ewmh));
            g_instance.initEWMH();

            g_instance.handles.xcontext = libx11.XUniqueContext();
            if (g_instance.handles.xcontext == 0) {
                return XConnectionError.XContextNoMem;
            }

            g_instance.pid = unix.getpid();
            Self.g_init = true;
        }
    }

    pub fn deinitSingleton() void {
        @setCold(true);
        Self.driver_guard.lock();
        defer Self.driver_guard.unlock();
        if (Self.g_init) {
            Self.g_init = false;
            _ = libx11.XCloseDisplay(globl_instance.handles.xdisplay);
            globl_instance.unloadXExtensions();
        }
    }

    fn loadXExtensions(self: *Self) XConnectionError!void {
        var base_event_code: c_int = undefined;
        var base_error_code: c_int = undefined;
        self.handles.xrandr = unix.loadPosixModule(
            libx11.XORG_LIBS_NAME[libx11.LIB_XRANDR_NAME_INDEX],
        );

        if (self.handles.xrandr) |handle| {
            self.extensions.xrandr.XRRGetCrtcInfo = @ptrCast(
                unix.moduleSymbol(handle, "XRRGetCrtcInfo"),
            );
            self.extensions.xrandr.XRRFreeCrtcInfo = @ptrCast(
                unix.moduleSymbol(handle, "XRRFreeCrtcInfo"),
            );
            self.extensions.xrandr.XRRGetOutputInfo = @ptrCast(
                unix.moduleSymbol(handle, "XRRGetOutputInfo"),
            );
            self.extensions.xrandr.XRRFreeOutputInfo = @ptrCast(
                unix.moduleSymbol(handle, "XRRFreeOutputInfo"),
            );
            self.extensions.xrandr.XRRGetOutputPrimary = @ptrCast(
                unix.moduleSymbol(handle, "XRRGetOutputPrimary"),
            );
            self.extensions.xrandr.XRRGetScreenResourcesCurrent = @ptrCast(
                unix.moduleSymbol(handle, "XRRGetScreenResourcesCurrent"),
            );
            self.extensions.xrandr.XRRGetScreenResources = @ptrCast(
                unix.moduleSymbol(handle, "XRRGetScreenResources"),
            );
            self.extensions.xrandr.XRRFreeScreenResources = @ptrCast(
                unix.moduleSymbol(handle, "XRRFreeScreenResources"),
            );
            self.extensions.xrandr.XRRQueryVersion = @ptrCast(
                unix.moduleSymbol(handle, "XRRQueryVersion"),
            );
            self.extensions.xrandr.XRRQueryExtension = @ptrCast(
                unix.moduleSymbol(handle, "XRRQueryExtension"),
            );
            self.extensions.xrandr.XRRSetCrtcConfig = @ptrCast(
                unix.moduleSymbol(handle, "XRRSetCrtcConfig"),
            );
            self.extensions.xrandr.XRRSelectInput = @ptrCast(
                unix.moduleSymbol(handle, "XRRSelectInput"),
            );
            self.extensions.xrandr.XRRUpdateConfiguration = @ptrCast(
                unix.moduleSymbol(handle, "XRRUpdateConfiguration"),
            );
            var minor: i32 = 0;
            var major: i32 = 0;
            _ = self.extensions.xrandr.XRRQueryVersion(
                self.handles.xdisplay,
                &major,
                &minor,
            );
            self.extensions.xrandr.is_v1point3 = (major >= 1 and minor >= 3);
            _ = self.extensions.xrandr.XRRQueryExtension(
                self.handles.xdisplay,
                &base_event_code,
                &base_error_code,
            );
            self.extensions.xrandr.event_code = base_event_code;
            // select events to receive.
            self.extensions.xrandr.XRRSelectInput(
                self.handles.xdisplay,
                self.handles.root_window,
                x11ext.RROutputChangeNotifyMask,
            );
        } else {
            std.log.err("[X11]: XRandR library not found.\n", .{});
            // Error out since a lot functionalties rely on xrandr.
            return XConnectionError.XRandRNotFound;
        }

        self.handles.xinerama = unix.loadPosixModule(
            libx11.XORG_LIBS_NAME[libx11.LIB_XINERAMA_NAME_INDEX],
        );
        if (self.handles.xinerama) |handle| {
            self.extensions.xinerama.IsActive = @ptrCast(
                unix.moduleSymbol(handle, "XineramaIsActive").?,
            );
            self.extensions.xinerama.QueryScreens = @ptrCast(
                unix.moduleSymbol(handle, "XineramaQueryScreens").?,
            );
            self.extensions.xinerama.is_active = (self.extensions.xinerama.IsActive(self.handles.xdisplay) != 0);
        } else {
            std.log.warn("[X11]: Xinerama library not found.\n", .{});
        }

        var xkb_major: c_int = 1;
        var xkb_minor: c_int = 0;
        var opcode: c_int = undefined;
        self.extensions.xkb.is_available = libx11.XkbQueryExtension(
            self.handles.xdisplay,
            &opcode,
            &base_event_code,
            &base_error_code,
            &xkb_major,
            &xkb_minor,
        ) == libx11.True;

        if (self.extensions.xkb.is_available) {
            self.extensions.xkb.event_code = base_event_code;
            // enable key auto repeat.
            var auto_repeat_support: libx11.Bool = libx11.False;
            _ = libx11.XkbGetDetectableAutoRepeat(
                self.handles.xdisplay,
                &auto_repeat_support,
            );
            self.extensions.xkb.is_auto_repeat_detectable = auto_repeat_support == libx11.True;
            if (self.extensions.xkb.is_auto_repeat_detectable) {
                _ = libx11.XkbSetDetectableAutoRepeat(
                    self.handles.xdisplay,
                    libx11.True,
                    null,
                );
            }
            // select events to receive.
            _ = libx11.XkbSelectEventDetails(
                self.handles.xdisplay,
                x11ext.XkbUseCoreKbd,
                x11ext.XkbStateNotify,
                x11ext.XkbAllStateComponentsMask,
                x11ext.XkbGroupStateMask,
            );
        }
    }

    fn unloadXExtensions(self: *Self) void {
        if (self.handles.xinerama) |handle| {
            unix.freePosixModule(handle);
            self.handles.xinerama = null;
        }

        if (self.handles.xrandr) |handle| {
            unix.freePosixModule(handle);
            self.handles.xrandr = null;
        }
    }

    fn readSystemGlobalDPI(self: *Self) void {
        // INFO:
        // there is no per monitor dpi property in X11, there is only a global
        // dpi property. the property is set by the user to a value that works
        // best for his highest resolution monitor using it should give
        // the user the best experience.
        // https://dec05eba.com/2021/10/11/x11-multiple-monitor-dpi-trick/

        // if we fail dpi will default to 96.
        var dpi: f32 = utils.DEFAULT_SCREEN_DPI;
        libx11.XrmInitialize();
        const res_str = libx11.XResourceManagerString(self.handles.xdisplay);
        if (res_str) |s| {
            const db = libx11.XrmGetStringDatabase(s);
            defer libx11.XrmDestroyDatabase(db);
            var value_type: ?[*:0]const u8 = null;
            var value: libx11.XrmValue = undefined;
            _ = libx11.XrmGetResource(db, "Xft.dpi", "Xft.Dpi", &value_type, &value);
            if (value_type) |t| {
                if (utils.strZEquals(t, "String")) {
                    var src: []const u8 = undefined;
                    src.len = value.size;
                    src.ptr = value.addr.?;
                    dpi = std.fmt.parseFloat(f32, src) catch utils.DEFAULT_SCREEN_DPI;
                }
            }
        }

        self.g_dpi = dpi;
        self.g_screen_scale = dpi / utils.DEFAULT_SCREEN_DPI;
    }

    /// Changes the x server protocol error handler
    // /// if the handler parameter is null the function use the last_error_handler
    // /// inner variable.
    /// # Notes:
    /// The default x11 error handler quits the process upon receiving any error,
    /// it's beneficial to change it when we anticipate errors that we
    /// can recover from, then restoring it when we are done.
    pub fn setXErrorHandler(
        self: *const Self,
        handler: ?*const libx11.XErrorHandlerFunc,
    ) ?*const libx11.XErrorHandlerFunc {
        libx11.XSync(self.handles.xdisplay, libx11.False);
        return libx11.XSetErrorHandler(handler);
        // if (handler) |h| {
        //     Self.last_error_handler = libx11.XSetErrorHandler(h);
        // } else {
        //     _ = libx11.XSetErrorHandler(Self.last_error_handler);
        // }
    }

    fn initEWMH(self: *Self) void {
        const info = @typeInfo(@TypeOf(self.ewmh));
        const NAME_BUFFER_SIZE = 256;
        var name_buffer: [NAME_BUFFER_SIZE]u8 = undefined;
        inline for (info.Struct.fields) |*f| {
            // only set the atoms.
            if (f.type != libx11.Atom) {
                continue;
            }
            if (f.name.len > NAME_BUFFER_SIZE - 1) {
                @compileError("field name size is bigger than NAME_BUFFER_SIZE\n");
            }
            std.mem.copyForwards(u8, &name_buffer, f.name);
            // since we are using c functions the strings are expected to
            // be null terminated.
            name_buffer[f.name.len] = 0;
            @field(self.ewmh, f.name) = libx11.XInternAtom(
                self.handles.xdisplay,
                @ptrCast(&name_buffer),
                libx11.False,
            );
        }
        self.checkWindowManagerEwmhSupport();
        if (!self.ewmh.is_wm_emwh) {
            return;
        }
        // a list of all supported features through the _NET_SUPPORTED
        // property on the root window.
        var supported: ?[*]libx11.Atom = null;
        const atom_count = utils.x11WindowProperty(
            self.handles.xdisplay,
            self.handles.root_window,
            self.ewmh._NET_SUPPORTED,
            libx11.XA_ATOM,
            @ptrCast(&supported),
        ) catch unreachable;

        if (atom_count == 0) {
            return;
        }
        defer _ = libx11.XFree(supported.?);

        const REQUIRE_WM_SUPPORT = [_][*:0]const u8{
            "_NET_WM_STATE",
            "_NET_WM_STATE_ABOVE",
            "_NET_WM_STATE_FULLSCREEN",
            "_NET_WM_STATE_MAXIMIZED_VERT",
            "_NET_WM_STATE_MAXIMIZED_HORZ",
            "_NET_WM_STATE_DEMANDS_ATTENTION",
            "_NET_WM_FULLSCREEN_MONITORS",
            "_NET_WM_WINDOW_TYPE",
            "_NET_WM_WINDOW_TYPE_NORMAL",
            "_NET_WORKAREA",
            "_NET_CURRENT_DESKTOP",
            "_NET_ACTIVE_WINDOW",
            "_NET_FRAME_EXTENTS",
            "_NET_REQUEST_FRAME_EXTENTS",
        };

        inline for (REQUIRE_WM_SUPPORT) |atom_name| {
            @field(self.ewmh, std.mem.span(atom_name)) = atomIfSupported(
                supported.?,
                atom_count,
                @field(self.ewmh, std.mem.span(atom_name)),
            );
        }

        Self.CUSTOM_CLIENT_ERR = libx11.XInternAtom(
            self.handles.xdisplay,
            "CUSTOM_CLIENT_ERR",
            libx11.False,
        );
    }

    fn checkWindowManagerEwmhSupport(self: *Self) void {

        // if the _NET_WM_SUPPORTING_WM_CHECK is missing client should
        // assume a non conforming window manager is present
        var window_ptr: ?*libx11.Window = null;
        _ = utils.x11WindowProperty(
            self.handles.xdisplay,
            self.handles.root_window,
            self.ewmh._NET_SUPPORTING_WM_CHECK,
            libx11.XA_WINDOW,
            @ptrCast(&window_ptr),
        ) catch {
            // non conforming.
            return;
        };

        std.debug.assert(window_ptr != null);
        defer _ = libx11.XFree(window_ptr.?);

        // on success the window_ptr points to the id of the child window created by
        // the window manager.
        // this window must also have _NET_WM_SUPPORTING_WM_CHECK property
        // set to the same id(the id of the child window).

        const prev_handler = self.setXErrorHandler(
            X11ErrorFilter(libx11.BadWindow).filter,
        );

        var child_window_ptr: ?*libx11.Window = null;
        _ = utils.x11WindowProperty(
            self.handles.xdisplay,
            window_ptr.?.*,
            self.ewmh._NET_SUPPORTING_WM_CHECK,
            libx11.XA_WINDOW,
            @ptrCast(&child_window_ptr),
        ) catch {
            return;
        };

        _ = self.setXErrorHandler(prev_handler);

        std.debug.assert(child_window_ptr != null);
        defer _ = libx11.XFree(child_window_ptr.?);

        if (window_ptr.?.* != child_window_ptr.?.*) {
            // breaks the rules.
            return;
        }

        // the window manager is EWMH-compliant we can get
        self.ewmh.is_wm_emwh = true;
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

    pub inline fn sendXEvent(
        self: *const Self,
        e: *libx11.XEvent,
        destination: libx11.Window,
    ) void {
        // https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#idm45717752103616
        _ = libx11.XSendEvent(
            self.handles.xdisplay,
            destination,
            libx11.False,
            libx11.SubstructureNotifyMask | libx11.SubstructureRedirectMask,
            e,
        );
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

    pub inline fn windowManagerId(self: *const Self) libx11.Window {
        return self.handles.root_window;
    }

    pub inline fn findInXContext(
        self: *const Self,
        window_id: libx11.Window,
    ) ?[*]u8 {
        var data_return: ?[*]u8 = null;
        const result = libx11.XFindContext(
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
    // TODO: might require refrence counting.
    pub fn singleton() *const Self {
        std.debug.assert(g_init == true);
        return &Self.globl_instance;
    }
};

/// check the supported atoms for a specified atom name
/// if found it returns the atom
/// if not it returns 0.
fn atomIfSupported(
    supported: [*]libx11.Atom,
    atom_count: u32,
    atom: libx11.Atom,
) libx11.Atom {
    for (0..atom_count) |i| {
        if (supported[i] == atom) {
            return atom;
        }
    }
    return 0;
}

fn X11ErrorFilter(comptime filtered_error_code: u8) type {
    return struct {
        pub fn filter(
            display: ?*libx11.Display,
            err: *libx11.XErrorEvent,
        ) callconv(.C) c_int {
            const x11cntxt = X11Driver.singleton();
            if (x11cntxt.handles.xdisplay != display or
                err.error_code == filtered_error_code)
            {
                return 0;
            } else {
                // TODO: what to do here.
                return -1;
                // return X11Driver.last_error_handler.?(display, err);
            }
        }
    };
}

test "X11Driver init" {
    const dyn = @import("x11/dynamic.zig");
    try dyn.initDynamicApi();
    try X11Driver.initSingleton("", "");
    const singleton = X11Driver.singleton();
    std.debug.print("\nX11 execution context:\n", .{});
    std.debug.print("[+] DPI:{d},Scale:{d}\n", .{ singleton.g_dpi, singleton.g_screen_scale });
    std.debug.print("[+] Handles: {any}\n", .{singleton.handles});
    std.debug.print("[+] XRRInterface: {any}\n", .{singleton.extensions.xrandr});
    std.debug.print("[+] XineramaIntef: {any}\n", .{singleton.extensions.xinerama});
    std.debug.print("[+] EWMH:{any}\n", .{singleton.ewmh});
    X11Driver.deinitSingleton();
}

test "XContext management" {
    const testing = std.testing;
    const dyn = @import("x11/dynamic.zig");
    try dyn.initDynamicApi();
    try X11Driver.initSingleton("", "");
    const singleton = X11Driver.singleton();
    var msg: [5]u8 = .{ 'H', 'E', 'L', 'L', 'O' };
    try testing.expect(singleton.addToXContext(1, &msg));
    var msg_alias_ptr = singleton.findInXContext(1);
    try testing.expect(msg_alias_ptr != null);
    std.debug.print("\nMSG={s}\n", .{@as(*[5]u8, @ptrCast(msg_alias_ptr.?)).*});
    try testing.expect(singleton.removeFromXContext(1));
    try testing.expect(!singleton.removeFromXContext(1));
    msg_alias_ptr = singleton.findInXContext(1);
    try testing.expect(msg_alias_ptr == null);
    X11Driver.deinitSingleton();
}
