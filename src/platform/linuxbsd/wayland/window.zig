const std = @import("std");
const common = @import("common");
const libwayland = @import("wl/wl.zig");
const bopts = @import("build-options");
const WlDriver = @import("driver.zig").WlDriver;
const WlRegistry = @import("driver.zig").WlRegistry;

const debug = std.debug;
const mem = std.mem;
const unix = common.unix;
const WindowData = common.window_data.WindowData;
const FBConfig = common.fb.FBConfig;
const Allocator = mem.Allocator;

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
    handle: *libwayland.wl_surface,
    // wl: struct {
    //     cursor: cursor.CursorHints,
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
        self.handle = try createPlatformWindow();
        self.data.id = if (id) |ident| ident else @intFromPtr(self.handle);

        return self;
    }

    /// Destroy the window
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        libwayland.wl_surface_destroy(self.handle);
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

    pub fn sendEvent(self:*Self,event:*const common.event.Event) void {
        if(self.ev_queue)|q|{
            q.queueEvent(event) catch  {
                // TODO:
            };
        }
    }
};

fn createPlatformWindow(
) WindowError!*libwayland.wl_surface{
    const drvr = WlDriver.getSingleton();
    const reg = WlRegistry.acquireSingleton();
    defer WlRegistry.releaseSingleton(reg);

    const handle = libwayland.wl_compositor_create_surface(reg.compositor.?) orelse return WindowError.CreateFail; 
    libwayland.wl_proxy_set_tag(@ptrCast(handle), &drvr.wl_tag);
    return handle;
}
