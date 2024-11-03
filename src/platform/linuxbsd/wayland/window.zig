const std = @import("std");
const common = @import("common");
const libwayland = @import("wl/wl.zig");
const bopts = @import("build-options");

const debug = std.debug;
const mem = std.mem;
const unix = common.unix;
const WindowData = common.window_data.WindowData;
const FBConfig = common.fb.FBConfig;
const Allocator = std.mem.Allocator;

pub const WindowError = error{
    CreateFail,
    BadTitle,
    OutOfMemory,
    BadIcon,
    UnsupportedRenderBackend,
    GLError,
};

pub const Window = struct {
    ev_queue: ?*common.event.EventQueue,
    data: WindowData,
    // handle: libwayland.wl,
    // x11: struct {
    //     xdnd_req: struct {
    //         raw_data: ?[*]const u8,
    //         paths: std.ArrayList([]const u8),
    //         version: c_long,
    //         src: c_long,
    //         format: c_long,
    //     },
    //     cursor: cursor.CursorHints,
    //     xdnd_allow: bool,
    // },
    fb_cfg: FBConfig,

    pub const WINDOW_DEFAULT_POSITION = common.geometry.WidowPoint2D{
        .x = 0,
        .y = 0,
    };
    const Self = @This();

    pub fn init(
        allocator: Allocator,
        id: ?usize,
        window_title: []const u8,
        data: *WindowData,
        fb_cfg: *FBConfig,
    ) (Allocator.Error || WindowError)!*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.data = data.*;
        self.fb_cfg = fb_cfg.*;
        self.ev_queue = null;
        _ = window_title;
        _ = id;

        // X11 won't let us change the visual and depth later so decide now.
        // const drvr = X11Driver.singleton();
        // var visual: ?*libx11.Visual = null;
        // var depth: c_int = 0;
        // switch (fb_cfg.accel) {
        //     .opengl => {
        //         glx.initGLX() catch return WindowError.GLError;
        //         if (!glx.chooseVisualGLX(fb_cfg, &visual, &depth)) {
        //             return WindowError.VisualNone;
        //         }
        //     },
        //     else => {
        //         visual = libx11.DefaultVisual(
        //             drvr.handles.xdisplay,
        //             drvr.handles.default_screen,
        //         );
        //         depth = libx11.DefaultDepth(
        //             drvr.handles.xdisplay,
        //             drvr.handles.default_screen,
        //         );
        //     },
        // }
        //
        // self.handle = try createPlatformWindow(data, visual, depth);
        // self.data.id = if (id) |ident| ident else @intCast(self.handle);
        //
        // if (!drvr.addToXContext(self.handle, @ptrCast(self))) {
        //     return WindowError.CreateFail;
        // }
        //
        // try setInitialWindowPropeties(self.handle, data);
        //
        // self.setTitle(window_title);
        // if (!self.data.flags.is_decorated) {
        //     self.setDecorated(false);
        // }
        //
        // if (self.data.flags.is_visible) {
        //     self.show();
        //     if (self.data.flags.is_focused) {
        //         self.focus();
        //     }
        // }

        return self;
    }

    /// Destroy the window
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        std.debug.assert(self.handle != 0);
        // const drvr = X11Driver.singleton();
        // _ = libx11.XUnmapWindow(drvr.handles.xdisplay, self.handle);
        // _ = libx11.XDestroyWindow(drvr.handles.xdisplay, self.handle);
        // _ = drvr.removeFromXContext(self.handle);
        // self.freeDroppedFiles();
        // self.handle = 0;
        allocator.destroy(self);
    }

    pub fn setEventQueue(
        self: *Self,
        queue: ?*common.event.EventQueue,
    ) ?*common.event.EventQueue {
        const ret = self.ev_queue;
        self.ev_queue = queue;
        return ret;
    }

    pub fn getEventQueue(self: *const Self) ?*common.event.EventQueue {
        return self.ev_queue;
    }

    pub fn processEvents(self: *Self) WindowError!void {
        _ = self;
        // var e: libx11.XEvent = undefined;
        // const drvr = X11Driver.singleton();
        // drvr.flushXRequests();
        // while (drvr.nextXEvent(&e)) {
        //     const window: ?*Window = if (self.handle == e.xany.window)
        //         self
        //     else
        //         windowFromId(e.xany.window);
        //
        //     if (window) |w| {
        //         if (e.type == libx11.ClientMessage and
        //             e.xclient.message_type == X11Driver.CUSTOM_CLIENT_ERR)
        //         {
        //             return @as(WindowError, @errorCast(@errorFromInt(@as(
        //                 std.meta.Int(.unsigned, @bitSizeOf(anyerror)),
        //                 @intCast(e.xclient.data.l[0]),
        //             ))));
        //         }
        //         event_handler.handleWindowEvent(&e, w);
        //         if (w.x11.cursor.mode == .Hidden) {
        //             const half_w = @divExact(w.data.client_area.size.width, 2);
        //             const half_y = @divExact(w.data.client_area.size.height, 2);
        //             if (w.x11.cursor.pos.x != half_w or
        //                 w.x11.cursor.pos.y != half_y)
        //             {
        //                 w.setCursorPosition(half_w, half_y);
        //             }
        //         }
        //     } else {
        //         std.debug.print("Unknow window({}) is root={}\n", .{e.xany.window,e.xany.window == drvr.windowManagerId()});
        //         // TODO: what about event not sent for our window
        //     }
        // }
    }

    pub fn waitEvent(self: *Self) WindowError!void {
        _ = self;
        // Indefinetly wait for event
        // const drvr = X11Driver.singleton();
        // var ready: u32 = 0;
        // // start by flushing and checking for available events.
        // while (libx11.XPending(drvr.handles.xdisplay) == 0) {
        //     _ = unix.poll(
        //         libx11.ConnectionNumber(drvr.handles.xdisplay),
        //         unix.PollFlag.IORead,
        //         -1,
        //         &ready,
        //     );
        // }
        // try self.processEvents();
    }

    /// Waits for an event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) WindowError!bool {
        _ = self;
        _ = timeout;
        // const timeout_ns = timeout * std.time.ns_per_ms;
        // const drvr = X11Driver.singleton();
        // var ready: u32 = 0;
        // // start by flushing and checking for available events.
        // while (libx11.XPending(drvr.handles.xdisplay) == 0) {
        //     if (unix.poll(
        //         libx11.ConnectionNumber(drvr.handles.xdisplay),
        //         unix.PollFlag.IORead,
        //         timeout_ns,
        //         &ready,
        //     ) == false) {
        //         // timeout or error
        //         return false;
        //     }
        // }
        // try self.processEvents();
        // return true;
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        std.debug.assert(self.handle != 0);
        // const drvr = X11Driver.singleton();
        // _ = libx11.XMapWindow(drvr.handles.xdisplay, self.handle);
        // drvr.flushXRequests();
        // self.data.flags.is_visible = true;
    }

    /// Hide the window.
    pub fn hide(self: *Self) void {
        std.debug.assert(self.handle != 0);
        // const drvr = X11Driver.singleton();
        // _ = libx11.XUnmapWindow(drvr.handles.xdisplay, self.handle);
        // drvr.flushXRequests();
        // self.data.flags.is_visible = false;
    }
};

// fn createPlatformWindow(
//     data: *const WindowData,
//     visual: ?*libx11.Visual,
//     depth: c_int,
// ) WindowError!libx11.Window {
//     const EVENT_MASK = libx11.KeyReleaseMask |
//         libx11.KeyPressMask |
//         libx11.ButtonPressMask |
//         libx11.ButtonReleaseMask |
//         libx11.EnterWindowMask |
//         libx11.LeaveWindowMask |
//         libx11.FocusChangeMask |
//         libx11.VisibilityChangeMask |
//         libx11.PointerMotionMask |
//         libx11.StructureNotifyMask |
//         libx11.PropertyChangeMask |
//         libx11.ExposureMask;
//
//     var attribs: libx11.XSetWindowAttributes = std.mem.zeroes(
//         libx11.XSetWindowAttributes,
//     );
//
//     attribs.event_mask = EVENT_MASK;
//     const drvr = X11Driver.singleton();
//     attribs.colormap = libx11.XCreateColormap(
//         drvr.handles.xdisplay,
//         drvr.windowManagerId(),
//         visual,
//         libx11.AllocNone,
//     );
//
//     var window_size = data.client_area.size;
//     if (data.flags.is_dpi_aware) {
//         window_size.scaleBy(drvr.g_screen_scale);
//     }
//
//     const handle = libx11.XCreateWindow(
//         drvr.handles.xdisplay,
//         drvr.windowManagerId(),
//         data.client_area.top_left.x,
//         data.client_area.top_left.y,
//         @intCast(window_size.width),
//         @intCast(window_size.height),
//         0,
//         depth,
//         libx11.InputOutput,
//         visual,
//         libx11.CWEventMask | libx11.CWBorderPixel | libx11.CWColormap,
//         @ptrCast(&attribs),
//     );
//
//     if (handle == 0) {
//         return WindowError.CreateFail;
//     }
//
//     // TODO: handle non is_fullscreen = true,
//
//     return handle;
// }
//
// fn setInitialWindowPropeties(
//     window: libx11.Window,
//     data: *const WindowData,
// ) WindowError!void {
//     // communication protocols
//     const drvr = X11Driver.singleton();
//     var protocols = [2]libx11.Atom{
//         // this allows us to recieve close request from the window manager.
//         // instead of it closing the socket and crashing our app
//         drvr.ewmh.WM_DELETE_WINDOW,
//         // this allows the window manager to check if a window is still alive and responding
//         drvr.ewmh._NET_WM_PING,
//     };
//     _ = libx11.XSetWMProtocols(
//         drvr.handles.xdisplay,
//         window,
//         &protocols,
//         protocols.len,
//     );
//
//     libx11.XChangeProperty(
//         drvr.handles.xdisplay,
//         window,
//         drvr.ewmh._NET_WM_PID,
//         libx11.XA_CARDINAL,
//         32,
//         libx11.PropModeReplace,
//         @ptrCast(&drvr.pid),
//         1,
//     );
//
//     // if supported declare window type.
//     if (drvr.ewmh._NET_WM_WINDOW_TYPE != 0 and
//         drvr.ewmh._NET_WM_WINDOW_TYPE_NORMAL != 0)
//     {
//         libx11.XChangeProperty(
//             drvr.handles.xdisplay,
//             window,
//             drvr.ewmh._NET_WM_WINDOW_TYPE,
//             libx11.XA_ATOM,
//             32,
//             libx11.PropModeReplace,
//             @ptrCast(&drvr.ewmh._NET_WM_WINDOW_TYPE_NORMAL),
//             1,
//         );
//     }
//
//     // WMHints.
//
//     var hints = libx11.XAllocWMHints() orelse return WindowError.CreateFail;
//     defer _ = libx11.XFree(hints);
//     hints.flags = libx11.StateHint;
//     hints.initial_state = libx11.NormalState;
//     _ = libx11.XSetWMHints(drvr.handles.xdisplay, window, @ptrCast(hints));
//
//     // resizablitity
//     var size_hints = libx11.XAllocSizeHints() orelse
//         return WindowError.CreateFail;
//
//     defer _ = libx11.XFree(size_hints);
//     size_hints.flags |= libx11.PWinGravity;
//     size_hints.win_gravity = libx11.StaticGravity;
//
//     var window_size = data.client_area.size;
//     if (data.flags.is_dpi_aware) {
//         window_size.scaleBy(drvr.g_screen_scale);
//     }
//
//     if (!data.flags.is_resizable) {
//         size_hints.flags |= (libx11.PMinSize | libx11.PMaxSize);
//         size_hints.max_width = window_size.width;
//         size_hints.min_width = window_size.width;
//         size_hints.max_height = window_size.height;
//         size_hints.min_height = window_size.height;
//     }
//
//     _ = libx11.XSetWMNormalHints(
//         drvr.handles.xdisplay,
//         window,
//         @ptrCast(size_hints),
//     );
//
//     // WMClassHints
//     var class_hints = libx11.XAllocClassHint() orelse
//         return WindowError.CreateFail;
//     defer _ = libx11.XFree(class_hints);
//     class_hints.res_name = bopts.X11_RES_NAME.ptr;
//     class_hints.res_class = bopts.X11_CLASS_NAME.ptr;
//
//     _ = libx11.XSetClassHint(
//         drvr.handles.xdisplay,
//         window,
//         @ptrCast(class_hints),
//     );
// }
//
// fn windowFromId(window_id: libx11.Window) ?*Window {
//     const drvr = X11Driver.singleton();
//     const window = drvr.findInXContext(window_id);
//     return @ptrCast(@alignCast(window));
// }
//
// pub inline fn enableRawMouseMotion() bool {
//     const drvr = X11Driver.singleton();
//     const MASK_LEN = comptime x11ext.XIMaskLen(x11ext.XI_RawMotion);
//     var mask: [MASK_LEN]u8 = [1]u8{0} ** MASK_LEN;
//     var ev_mask = x11ext.XIEventMask{
//         .deviceid = x11ext.XIAllMasterDevices,
//         .mask_len = MASK_LEN,
//         .mask = &mask,
//     };
//     x11ext.XISetMask(&mask, x11ext.XI_RawMotion);
//     return drvr.extensions.xi2.XISelectEvents(
//         drvr.handles.xdisplay,
//         drvr.windowManagerId(),
//         @ptrCast(&ev_mask),
//         1,
//     ) == libx11.Success;
// }
//
// pub inline fn disableRawMouseMotion() bool {
//     const drvr = X11Driver.singleton();
//     const MASK_LEN = 1;
//     var mask: [MASK_LEN]u8 = [1]u8{0} ** MASK_LEN;
//     var ev_mask = x11ext.XIEventMask{
//         .deviceid = x11ext.XIAllMasterDevices,
//         .mask_len = MASK_LEN,
//         .mask = &mask,
//     };
//     x11ext.XISetMask(&mask, x11ext.XI_RawMotion);
//     return drvr.extensions.xi2.XISelectEvents(
//         drvr.handles.xdisplay,
//         drvr.windowManagerId(),
//         @ptrCast(&ev_mask),
//         1,
//     ) == libx11.Success;
// }
