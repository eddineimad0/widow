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
    handle: libwayland.wl_surface,
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

fn createPlatformWindow(
    _: *const WindowData,
) WindowError!libwayland.wl_surface{
    // TODO: handle non is_fullscreen = true,
}
