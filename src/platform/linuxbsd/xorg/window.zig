const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const glx = @import("glx.zig");
const gl = @import("gl");
const utils = @import("utils.zig");
const cursor = @import("cursor.zig");
const event_handler = @import("event_handler.zig");
const bopts = @import("build-options");

const debug = std.debug;
const mem = std.mem;
const unix = common.unix;
const WindowData = common.window_data.WindowData;
const FBConfig = common.fb.FBConfig;
const X11Driver = @import("driver.zig").X11Driver;
const Allocator = std.mem.Allocator;

const _NET_WM_STATE_REMOVE = 0;
const _NET_WM_STATE_ADD = 1;
const _NET_WM_STATE_TOGGLE = 2;

pub const WindowError = error{
    CreateFail,
    BadTitle,
    OutOfMemory,
    BadIcon,
    GLError,
    VisualNone,
};

pub const Window = struct {
    ev_queue: ?*common.event.EventQueue,
    data: WindowData,
    handle: libx11.Window,
    x11: struct {
        xdnd_req: struct {
            raw_data: ?[*]const u8,
            paths: std.ArrayList([]const u8),
            version: c_long,
            src: c_long,
            format: c_long,
        },
        cursor: cursor.CursorHints,
        xdnd_allow: bool,
    },
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
        self.x11 = .{
            .cursor = .{
                .mode = .Normal,
                .icon = libx11.None,
                .pos = .{ .x = 0, .y = 0 },
                .accum_pos = .{ .x = 0, .y = 0 },
            },
            .xdnd_req = .{
                .src = 0,
                .version = 0,
                .format = 0,
                .raw_data = null,
                .paths = .{
                    .items = undefined,
                    .allocator = undefined,
                    .capacity = 0,
                },
            },
            .xdnd_allow = false,
        };

        // X11 won't let us change the visual and depth later so decide now.
        const drvr = X11Driver.singleton();
        var visual: ?*libx11.Visual = null;
        var depth: c_int = 0;
        switch (fb_cfg.accel) {
            .opengl => {
                glx.initGLX() catch return WindowError.GLError;
                if (!glx.chooseVisualGLX(fb_cfg, &visual, &depth)) {
                    return WindowError.VisualNone;
                }
            },
            else => {
                visual = libx11.DefaultVisual(
                    drvr.handles.xdisplay,
                    drvr.handles.default_screen,
                );
                depth = libx11.DefaultDepth(
                    drvr.handles.xdisplay,
                    drvr.handles.default_screen,
                );
            },
        }

        self.handle = try createPlatformWindow(data, visual, depth);
        self.data.id = if (id) |ident| ident else @intCast(self.handle);

        if (!drvr.addToXContext(self.handle, @ptrCast(self))) {
            return WindowError.CreateFail;
        }

        try setInitialWindowPropeties(self.handle, data);

        self.setTitle(window_title);
        if (!self.data.flags.is_decorated) {
            self.setDecorated(false);
        }

        if (self.data.flags.is_visible) {
            self.show();
            if (self.data.flags.is_focused) {
                self.focus();
            }
        }

        return self;
    }

    /// Destroy the window
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        std.debug.assert(self.handle != 0);
        const drvr = X11Driver.singleton();
        _ = libx11.XUnmapWindow(drvr.handles.xdisplay, self.handle);
        _ = libx11.XDestroyWindow(drvr.handles.xdisplay, self.handle);
        _ = drvr.removeFromXContext(self.handle);
        self.freeDroppedFiles();
        self.handle = 0;
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
        var e: libx11.XEvent = undefined;
        const drvr = X11Driver.singleton();
        drvr.flushXRequests();
        while (drvr.nextXEvent(&e)) {
            const window: ?*Window = if (self.handle == e.xany.window)
                self
            else
                windowFromId(e.xany.window);

            if (window) |w| {
                if (e.type == libx11.ClientMessage and
                    e.xclient.message_type == X11Driver.CUSTOM_CLIENT_ERR)
                {
                    return @as(WindowError, @errorCast(@errorFromInt(@as(
                        std.meta.Int(.unsigned, @bitSizeOf(anyerror)),
                        @intCast(e.xclient.data.l[0]),
                    ))));
                }
                event_handler.handleWindowEvent(&e, w);
                if (w.x11.cursor.mode == .Hidden) {
                    const half_w = @divExact(w.data.client_area.size.width, 2);
                    const half_y = @divExact(w.data.client_area.size.height, 2);
                    if (w.x11.cursor.pos.x != half_w or
                        w.x11.cursor.pos.y != half_y)
                    {
                        w.setCursorPosition(half_w, half_y);
                    }
                }
            } else {
                // TODO: what about event not sent for our window
            }
        }
    }

    pub fn waitEvent(self: *Self) WindowError!void {
        // Indefinetly wait for event
        const drvr = X11Driver.singleton();
        var ready: u32 = 0;
        // start by flushing and checking for available events.
        while (libx11.XPending(drvr.handles.xdisplay) == 0) {
            _ = unix.poll(
                libx11.ConnectionNumber(drvr.handles.xdisplay),
                unix.PollFlag.IORead,
                -1,
                &ready,
            );
        }
        try self.processEvents();
    }

    /// Waits for an event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) WindowError!bool {
        const timeout_ns = timeout * std.time.ns_per_ms;
        const drvr = X11Driver.singleton();
        var ready: u32 = 0;
        // start by flushing and checking for available events.
        while (libx11.XPending(drvr.handles.xdisplay) == 0) {
            if (unix.poll(
                libx11.ConnectionNumber(drvr.handles.xdisplay),
                unix.PollFlag.IORead,
                timeout_ns,
                &ready,
            ) == false) {
                // timeout or error
                return false;
            }
        }
        try self.processEvents();
        return true;
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const drvr = X11Driver.singleton();
        _ = libx11.XMapWindow(drvr.handles.xdisplay, self.handle);
        drvr.flushXRequests();
        self.data.flags.is_visible = true;
    }

    /// Hide the window.
    pub fn hide(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const drvr = X11Driver.singleton();
        _ = libx11.XUnmapWindow(drvr.handles.xdisplay, self.handle);
        drvr.flushXRequests();
        self.data.flags.is_visible = false;
    }

    /// Add an event to the events queue.
    pub fn sendEvent(
        self: *Self,
        event: *const common.event.Event,
    ) void {
        if (self.ev_queue) |q| {
            q.queueEvent(event) catch |err| {
                const drvr = X11Driver.singleton();
                var ev: libx11.XEvent = undefined;
                ev.type = libx11.ClientMessage;
                ev.xclient.window = self.handle;
                ev.xclient.message_type = X11Driver.CUSTOM_CLIENT_ERR;
                ev.xclient.format = 32;
                ev.xclient.data.l[0] = @intFromError(err);
                std.debug.assert(ev.xclient.message_type != 0);
                drvr.sendXEvent(&ev, self.handle);
            };
        }
    }

    /// Updates the size hints to match the the window current state.
    /// the window's size, minimum size and maximum size should be
    /// updated with the desired value before calling this function.
    /// Note:
    /// If the window is fullscreen the function returns immmediately.
    fn updateSizeHints(self: *Self) void {
        if (self.data.flags.is_fullscreen) {
            return;
        }
        const size_hints = libx11.XAllocSizeHints();
        if (size_hints) |hints| {
            const drvr = X11Driver.singleton();
            var supplied: c_long = 0;
            _ = libx11.XGetWMNormalHints(
                drvr.handles.xdisplay,
                self.handle,
                hints,
                &supplied,
            );
            hints.flags &= ~@as(c_long, libx11.PMinSize |
                libx11.PMaxSize |
                libx11.PAspect);
            if (self.data.flags.is_resizable) {
                if (self.data.min_size) |size| {
                    hints.flags |= libx11.PMinSize;
                    hints.min_width = size.width;
                    hints.min_height = size.height;
                }
                if (self.data.max_size) |size| {
                    hints.flags |= libx11.PMaxSize;
                    hints.max_width = size.width;
                    hints.max_height = size.height;
                }
                if (self.data.aspect_ratio) |ratio| {
                    hints.flags |= libx11.PAspect;
                    hints.min_aspect.x = ratio.x;
                    hints.min_aspect.y = ratio.y;
                    hints.max_aspect.x = ratio.x;
                    hints.max_aspect.y = ratio.y;
                }
            } else {
                hints.flags |= (libx11.PMinSize | libx11.PMaxSize);
                hints.min_width = self.data.client_area.size.width;
                hints.min_height = self.data.client_area.size.height;
                hints.max_width = self.data.client_area.size.width;
                hints.max_height = self.data.client_area.size.height;
            }
            _ = libx11.XSetWMNormalHints(
                drvr.handles.xdisplay,
                self.handle,
                @ptrCast(hints),
            );
            _ = libx11.XFree(hints);
        }
    }

    /// Notify and flash the taskbar.
    /// Requires window manager support.
    /// returns true on success.
    pub fn flash(self: *const Self) bool {
        const drvr = X11Driver.singleton();
        if (drvr.ewmh._NET_WM_STATE_DEMANDS_ATTENTION == 0 or
            drvr.ewmh._NET_WM_STATE == 0)
        {
            // unsupported by the current window manager.
            return false;
        }

        var event = libx11.XEvent{
            .xclient = libx11.XClientMessageEvent{
                .type = libx11.ClientMessage,
                .display = drvr.handles.xdisplay,
                .window = self.handle,
                .message_type = drvr.ewmh._NET_WM_STATE,
                .format = 32,
                .serial = 0,
                .send_event = 0,
                .data = .{ .l = [5]c_long{
                    _NET_WM_STATE_ADD,
                    @intCast(drvr.ewmh._NET_WM_STATE_DEMANDS_ATTENTION),
                    0,
                    1,
                    0,
                } },
            },
        };
        drvr.sendXEvent(&event, drvr.windowManagerId());
        drvr.flushXRequests();
        return true;
    }

    pub fn focus(self: *Self) void {
        const drvr = X11Driver.singleton();
        if (drvr.ewmh._NET_ACTIVE_WINDOW != 0) {
            var ev = libx11.XEvent{
                .xclient = libx11.XClientMessageEvent{
                    .type = libx11.ClientMessage,
                    .display = drvr.handles.xdisplay,
                    .window = self.handle,
                    .format = 32,
                    .serial = 0,
                    .send_event = 0,
                    .message_type = drvr.ewmh._NET_ACTIVE_WINDOW,
                    .data = .{
                        .l = .{
                            _NET_WM_STATE_ADD,
                            0,
                            0,
                            0,
                            0,
                        },
                    },
                },
            };
            drvr.sendXEvent(&ev, drvr.windowManagerId());
        } else {
            libx11.XRaiseWindow(drvr.handles.xdisplay, self.handle);
            libx11.XSetInputFocus(
                drvr.handles.xdisplay,
                self.handle,
                libx11.RevertToParent,
                libx11.CurrentTime,
            );
        }
        drvr.flushXRequests();
    }

    /// Returns the position of the top left corner of the client area.
    pub fn clientPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.data.client_area.top_left;
    }

    /// Moves the client's top left corner
    /// to the specified screen coordinates.
    pub fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        const drvr = X11Driver.singleton();
        _ = libx11.XMoveWindow(
            drvr.handles.xdisplay,
            self.handle,
            @intCast(x),
            @intCast(y),
        );
        drvr.flushXRequests();
    }

    /// Returns the Physical size of the window's client area
    pub fn clientPixelSize(self: *const Self) common.geometry.WidowSize {
        return .{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
    }

    /// Returns the logical size of the window's client area
    pub fn clientSize(self: *const Self) common.geometry.WidowSize {
        var attribs: libx11.XWindowAttributes = undefined;
        const drvr = X11Driver.singleton();
        _ = libx11.XGetWindowAttributes(
            drvr.handles.xdisplay,
            self.handle,
            &attribs,
        );

        return .{
            .width = @intCast(attribs.width),
            .height = @intCast(attribs.height),
        };
    }

    /// Sets the new (width,height) of the window's client area
    pub fn setClientSize(self: *Self, size: *common.geometry.WidowSize) void {
        if (self.data.flags.is_maximized) {
            // un-maximize the window
            self.restore();
        }

        self.data.client_area.size = size.*;
        if (self.data.flags.is_dpi_aware) {
            const drvr = X11Driver.singleton();
            self.data.client_area.size.scaleBy(drvr.g_screen_scale);
        }

        const drvr = X11Driver.singleton();
        if (!self.data.flags.is_resizable) {
            // we need to update the maxwidth and maxheight
            // size hints.
            self.updateSizeHints();
        }

        _ = libx11.XResizeWindow(
            drvr.handles.xdisplay,
            self.handle,
            @intCast(size.width),
            @intCast(size.height),
        );

        drvr.flushXRequests();
    }

    pub fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
        if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
            // No need to do anything.
            return;
        }

        if (min_size != null) {
            var size = min_size.?;
            // min size shouldn't be negative.
            std.debug.assert(size.width > 0);
            std.debug.assert(size.height > 0);

            if (self.data.max_size) |*max_size| {
                // the min size shouldn't be superior to the max size.
                if (max_size.width < size.width or max_size.height < size.height) {
                    std.log.err(
                        "[Window] Specified minimum size(w:{},h:{}) is less than the maximum size(w:{},h:{})\n",
                        .{
                            size.width,
                            size.height,
                            max_size.width,
                            max_size.height,
                        },
                    );
                    return;
                }
            }

            if (self.data.flags.is_dpi_aware) {
                const drvr = X11Driver.singleton();
                size.scaleBy(drvr.g_screen_scale);
            }

            self.data.min_size = size;
        } else {
            self.data.min_size = null;
        }

        self.updateSizeHints();
    }

    pub fn setMaxSize(self: *Self, max_size: ?common.geometry.WidowSize) void {
        if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
            // No need to do anything.
            return;
        }

        if (max_size != null) {
            var size = max_size.?;
            // max size shouldn't be negative.
            std.debug.assert(size.width > 0);
            std.debug.assert(size.height > 0);
            if (self.data.min_size) |*min_size| {
                // the max size should be superior or equal to the min size.
                if (size.width < min_size.width or
                    size.height < min_size.height)
                {
                    std.log.err(
                        "[Window] Specified maximum size(w:{},h:{}) is less than the minimum size(w:{},h:{})\n",
                        .{
                            size.width,
                            size.height,
                            min_size.width,
                            min_size.height,
                        },
                    );
                    return;
                }
            }
            if (self.data.flags.is_dpi_aware) {
                const drvr = X11Driver.singleton();
                size.scaleBy(drvr.g_screen_scale);
            }
            self.data.max_size = size;
        } else {
            self.data.max_size = null;
        }

        self.updateSizeHints();
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.WidowAspectRatio) void {
        self.data.aspect_ratio = ratio;
        self.updateSizeHints();
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setResizable(self: *Self, value: bool) void {
        self.data.flags.is_resizable = value;
        self.updateSizeHints();
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setDecorated(self: *Self, value: bool) void {
        const MWM_HINTS_DECORATIONS = 1 << 1;
        const MWM_DECOR_ALL = 1 << 0;
        const PROP_MOTIF_WM_HINTS_ELEMENTS = 5;
        const drvr = X11Driver.singleton();
        self.data.flags.is_decorated = value;
        var motif_hints: extern struct {
            flags: c_ulong,
            functions: c_ulong,
            decorations: c_ulong,
            input_mode: c_long,
            status: c_ulong,
        } = undefined;

        motif_hints.flags = MWM_HINTS_DECORATIONS;
        motif_hints.decorations = if (value) MWM_DECOR_ALL else 0;

        libx11.XChangeProperty(
            drvr.handles.xdisplay,
            self.handle,
            drvr.ewmh._MOTIF_WM_HINTS,
            drvr.ewmh._MOTIF_WM_HINTS,
            32,
            libx11.PropModeReplace,
            @ptrCast(&motif_hints),
            PROP_MOTIF_WM_HINTS_ELEMENTS,
        );
    }

    /// Maximize the window.
    pub fn maximize(self: *const Self) void {
        const drvr = X11Driver.singleton();
        if (drvr.ewmh._NET_WM_STATE != 0 and
            drvr.ewmh._NET_WM_STATE_MAXIMIZED_VERT != 0 and
            drvr.ewmh._NET_WM_STATE_MAXIMIZED_HORZ != 0)
        {
            var ev = libx11.XEvent{
                .xclient = libx11.XClientMessageEvent{
                    .type = libx11.ClientMessage,
                    .display = drvr.handles.xdisplay,
                    .window = self.handle,
                    .format = 32,
                    .serial = 0,
                    .send_event = 0,
                    .message_type = drvr.ewmh._NET_WM_STATE,
                    .data = .{
                        .l = .{
                            _NET_WM_STATE_ADD,
                            drvr.ewmh._NET_WM_STATE_MAXIMIZED_VERT,
                            drvr.ewmh._NET_WM_STATE_MAXIMIZED_HORZ,
                            1,
                            0,
                        },
                    },
                },
            };
            drvr.sendXEvent(&ev, drvr.windowManagerId());
        }
    }

    /// Minimizes the window.
    pub fn minimize(self: *Self) void {
        const drvr = X11Driver.singleton();
        _ = libx11.XIconifyWindow(
            drvr.handles.xdisplay,
            self.handle,
            drvr.handles.default_screen,
        );
        drvr.flushXRequests();
        self.data.flags.is_minimized = true;
    }

    /// Restores the minimized or maximized window to a normal window.
    pub fn restore(self: *const Self) void {
        const drvr = X11Driver.singleton();
        if (drvr.ewmh._NET_WM_STATE != 0 and
            drvr.ewmh._NET_WM_STATE_MAXIMIZED_VERT != 0 and
            drvr.ewmh._NET_WM_STATE_MAXIMIZED_HORZ != 0)
        {
            var ev = libx11.XEvent{
                .xclient = libx11.XClientMessageEvent{
                    .type = libx11.ClientMessage,
                    .display = drvr.handles.xdisplay,
                    .window = self.handle,
                    .format = 32,
                    .serial = 0,
                    .send_event = 0,
                    .message_type = drvr.ewmh._NET_WM_STATE,
                    .data = .{
                        .l = .{
                            _NET_WM_STATE_REMOVE,
                            @intCast(drvr.ewmh._NET_WM_STATE_MAXIMIZED_VERT),
                            @intCast(drvr.ewmh._NET_WM_STATE_MAXIMIZED_HORZ),
                            1,
                            0,
                        },
                    },
                },
            };
            drvr.sendXEvent(&ev, drvr.windowManagerId());
        }
        drvr.flushXRequests();
    }

    /// Changes the title of the window.
    pub fn setTitle(self: *Self, new_title: []const u8) void {
        const drvr = X11Driver.singleton();
        const name_atom = if (drvr.ewmh._NET_WM_NAME != 0)
            drvr.ewmh._NET_WM_NAME
        else
            drvr.ewmh._NET_WM_VISIBLE_NAME;
        const icon_atom = if (drvr.ewmh._NET_WM_ICON_NAME != 0)
            drvr.ewmh._NET_WM_ICON_NAME
        else
            drvr.ewmh._NET_WM_VISIBLE_ICON_NAME;

        libx11.XChangeProperty(
            drvr.handles.xdisplay,
            self.handle,
            name_atom,
            drvr.ewmh.UTF8_STRING,
            8,
            libx11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );

        libx11.XChangeProperty(
            drvr.handles.xdisplay,
            self.handle,
            icon_atom,
            drvr.ewmh.UTF8_STRING,
            8,
            libx11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );
        drvr.flushXRequests();
    }

    /// Returns the title of the window.
    pub fn title(
        self: *const Self,
        allocator: std.mem.Allocator,
    ) (Allocator.Error.OutOfMemory || WindowError)![]u8 {
        const drvr = X11Driver.singleton();
        const name_atom = if (drvr.ewmh._NET_WM_NAME != 0)
            drvr.ewmh._NET_WM_NAME
        else
            drvr.ewmh._NET_WM_VISIBLE_NAME;

        var data: [*]u8 = undefined;
        const data_len = utils.x11WindowProperty(
            drvr.handles.xdisplay,
            self.handle,
            name_atom,
            drvr.ewmh.UTF8_STRING,
            @ptrCast(&data),
        ) catch {
            return WindowError.BadTitle;
        };

        defer _ = libx11.XFree(data);
        const window_title = try allocator.alloc(u8, data_len);
        @memcpy(window_title, data);
        return window_title;
    }

    /// Returns the window's current opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn opacity(self: *const Self) f64 {
        const drvr = X11Driver.singleton();
        var cardinal: ?*libx11.XID = null; // cardinal, and xid are the same bitwidth.
        const OPAQUE = @as(u32, 0xFFFFFFFF);
        _ = utils.x11WindowProperty(
            drvr.handles.xdisplay,
            self.handle,
            drvr.ewmh._NET_WM_WINDOW_OPACITY,
            libx11.XA_CARDINAL,
            &cardinal,
        ) catch return 1.0;
        std.debug.assert(cardinal != null);
        defer _ = libx11.XFree(cardinal.?);
        return (@as(f64, @floatFromInt(cardinal.?.*)) / @as(f64, @floatFromInt(OPAQUE)));
    }

    /// Sets the window's opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn setOpacity(self: *Self, value: f64) bool {
        const drvr = X11Driver.singleton();
        if (drvr.ewmh._NET_WM_WINDOW_OPACITY == 0) {
            return false;
        }

        if (value == @as(f64, 1.0)) {
            // it's faster to just delete the property.
            libx11.XDeleteProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh._NET_WM_WINDOW_OPACITY,
            );
        } else {
            const OPAQUE = @as(u32, 0xFFFFFFFF);
            const alpha: libx11.XID = @intFromFloat(value * @as(f64, @floatFromInt(OPAQUE)));
            libx11.XChangeProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh._NET_WM_WINDOW_OPACITY,
                libx11.XA_CARDINAL,
                32,
                libx11.PropModeReplace,
                @ptrCast(&alpha),
                1,
            );
        }
        return true;
    }

    /// Switch the window to fullscreen mode and back;
    pub fn setFullscreen(
        self: *Self,
        value: bool,
    ) bool {
        const drvr = X11Driver.singleton();
        if (drvr.ewmh._NET_WM_STATE_FULLSCREEN == 0 or
            drvr.ewmh._NET_WM_STATE == 0)
        {
            // unsupported by the current window manager.
            return false;
        }

        var event = libx11.XEvent{
            .xclient = libx11.XClientMessageEvent{
                .type = libx11.ClientMessage,
                .display = drvr.handles.xdisplay,
                .window = self.handle,
                .message_type = drvr.ewmh._NET_WM_STATE,
                .format = 32,
                .serial = 0,
                .send_event = 0,
                .data = .{ .l = [5]c_long{
                    if (value) _NET_WM_STATE_ADD else _NET_WM_STATE_REMOVE,
                    @intCast(drvr.ewmh._NET_WM_STATE_FULLSCREEN),
                    0,
                    0,
                    0,
                } },
            },
        };

        drvr.sendXEvent(&event, drvr.windowManagerId());
        drvr.flushXRequests();
        return true;
    }

    pub fn setDragAndDrop(
        self: *Self,
        allocator: mem.Allocator,
        accepted: bool,
    ) void {
        const version: i32 = libx11.XDND_VER;
        const drvr = X11Driver.singleton();

        if (accepted == self.x11.xdnd_allow) {
            return;
        }
        self.x11.xdnd_allow = accepted;

        if (accepted) {
            self.x11.xdnd_req.paths = std.ArrayList([]const u8).init(allocator);
            libx11.XChangeProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh.XdndAware,
                libx11.XA_ATOM,
                32,
                libx11.PropModeReplace,
                @ptrCast(&version),
                1,
            );
        } else {
            libx11.XDeleteProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh.XdndAware,
            );
            self.freeDroppedFiles();
        }
        drvr.flushXRequests();
    }

    // /// Returns a cached slice that contains the path(s) to the last dropped file(s).
    pub fn droppedFiles(self: *const Self) [][]const u8 {
        return self.x11.xdnd_req.paths.items;
    }

    /// Frees the allocated memory used to hold the file(s) path(s).
    pub fn freeDroppedFiles(self: *Self) void {
        // Avoid double free.
        if (self.x11.xdnd_req.raw_data) |rd| {
            _ = libx11.XFree(@constCast(rd));
        }
        if (self.x11.xdnd_req.paths.capacity != 0) {
            self.x11.xdnd_req.paths.clearAndFree();
        }
    }

    pub fn cursorPosition(self: *const Self) common.geometry.WidowPoint2D {
        const drvr = X11Driver.singleton();
        var root: libx11.Window = undefined;
        var child: libx11.Window = undefined;
        var root_x: c_int, var root_y: c_int = .{ undefined, undefined };
        var win_x: c_int, var win_y: c_int = .{ undefined, undefined };
        var mask: c_uint = undefined;
        _ = libx11.XQueryPointer(
            drvr.handles.xdisplay,
            self.handle,
            &root,
            &child,
            &root_x,
            &root_y,
            &win_x,
            &win_y,
            &mask,
        );

        return .{ .x = win_x, .y = win_y };
    }

    pub fn setCursorPosition(self: *Self, x: i32, y: i32) void {
        self.x11.cursor.pos = .{ .x = x, .y = y };
        const drvr = X11Driver.singleton();
        _ = libx11.XWarpPointer(
            drvr.handles.xdisplay,
            libx11.None,
            self.handle,
            0,
            0,
            0,
            0,
            @intCast(x),
            @intCast(y),
        );
        drvr.flushXRequests();
    }

    pub fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
        self.x11.cursor.mode = mode;
        cursor.applyCursorHints(&self.x11.cursor, self.handle);
        if (self.data.flags.has_raw_mouse) {
            if (mode == .Hidden) {
                _ = enableRawMouseMotion();
            } else {
                _ = disableRawMouseMotion();
            }
        }
    }

    pub fn setCursorIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        xhot: u32,
        yhot: u32,
    ) WindowError!void {
        var new_cursor: libx11.Cursor = 0;
        if (pixels) |p| {
            new_cursor = cursor.createX11Cursor(
                p,
                width,
                height,
                xhot,
                yhot,
            ) catch |err| {
                return switch (err) {
                    cursor.IconError.BadIcon => WindowError.BadIcon,
                    else => WindowError.OutOfMemory,
                };
            };
        }
        cursor.destroyCursorIcon(&self.x11.cursor);
        self.x11.cursor.icon = new_cursor;
        if (self.data.flags.cursor_in_client) {
            cursor.applyCursorHints(&self.x11.cursor, self.handle);
        }
    }

    pub fn setNativeCursorIcon(
        self: *Self,
        cursor_shape: common.cursor.NativeCursorShape,
    ) WindowError!void {
        const new_cursor = cursor.createNativeCursor(cursor_shape) catch {
            return WindowError.OutOfMemory;
        };
        cursor.destroyCursorIcon(&self.x11.cursor);
        self.x11.cursor.icon = new_cursor.icon;
        self.x11.cursor.mode = new_cursor.mode;
        if (self.data.flags.cursor_in_client) {
            cursor.applyCursorHints(&self.x11.cursor, self.handle);
        }
    }

    pub fn setIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        allocator: std.mem.Allocator,
    ) WindowError!void {
        const drvr = X11Driver.singleton();
        if (pixels) |p| {
            const pixl_data_size = width * height;
            var icon_buffer = try allocator.alloc(c_long, 2 + @as(usize, @intCast(pixl_data_size)));
            defer allocator.free(icon_buffer);
            icon_buffer[0] = @intCast(width);
            icon_buffer[1] = @intCast(height);
            for (0..@as(usize, @intCast(pixl_data_size))) |i| {
                icon_buffer[2 + i] = ((@as(c_long, p[(4 * i) + 3]) << 24) |
                    (@as(c_long, p[(4 * i) + 0]) << 16) |
                    (@as(c_long, p[(4 * i) + 1]) << 8) |
                    @as(c_long, p[(4 * i) + 2]));
            }
            libx11.XChangeProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh._NET_WM_ICON,
                libx11.XA_CARDINAL,
                32,
                libx11.PropModeReplace,
                @ptrCast(icon_buffer.ptr),
                @intCast(2 + pixl_data_size),
            );
        } else {
            libx11.XDeleteProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh._NET_WM_ICON,
            );
        }
        drvr.flushXRequests();
    }

    fn windowFrameSize(
        self: *const Self,
        left: *i32,
        top: *i32,
        right: *i32,
        bottom: *i32,
    ) bool {
        const drvr = X11Driver.singleton();
        if (self.data.flags.is_fullscreen or
            !self.data.flags.is_decorated or
            drvr.ewmh._NET_REQUEST_FRAME_EXTENTS == 0)
        {
            left.* = 0;
            right.* = 0;
            top.* = 0;
            bottom.* = 0;
            return true;
        }

        var ev = libx11.XEvent{
            .xclient = libx11.XClientMessageEvent{
                .type = libx11.ClientMessage,
                .display = drvr.handles.xdisplay,
                .window = self.handle,
                .format = 32,
                .serial = 0,
                .send_event = 0,
                .message_type = drvr.ewmh._NET_REQUEST_FRAME_EXTENTS,
                .data = .{
                    .l = .{
                        0,
                        0,
                        0,
                        0,
                        0,
                    },
                },
            },
        };
        drvr.sendXEvent(&ev, drvr.windowManagerId());
        drvr.flushXRequests();

        var extents: ?[*]c_long = null;

        const length = utils.x11WindowProperty(
            drvr.handles.xdisplay,
            self.handle,
            drvr.ewmh._NET_FRAME_EXTENTS,
            libx11.XA_CARDINAL,
            @ptrCast(&extents),
        ) catch return false;

        if (extents) |ex| {
            defer _ = libx11.XFree(@ptrCast(ex));
            if (length != 4) {
                return false;
            }

            left.* = @intCast(ex[0]);
            right.* = @intCast(ex[1]);
            top.* = @intCast(ex[2]);
            bottom.* = @intCast(ex[3]);
            return true;
        }

        return false;
    }

    pub fn setRawMouseMotion(self: *Self, active: bool) bool {
        const drvr = X11Driver.singleton();
        if (!drvr.extensions.xi2.is_v2point0) {
            return false;
        }

        if (self.data.flags.has_raw_mouse == active) {
            return true;
        }

        self.data.flags.has_raw_mouse = active;
        if (active) {
            return enableRawMouseMotion();
        } else {
            return disableRawMouseMotion();
        }
    }

    pub fn getGLContext(self: *const Self) WindowError!glx.GLContext {
        switch (self.fb_cfg.accel) {
            .opengl => return glx.GLContext.init(self.handle, &self.fb_cfg) catch {
                return WindowError.GLError;
            },
            else => return WindowError.GLError, // TODO: better error.
        }
    }

    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (common.IS_DEBUG_BUILD) {
            std.debug.print("0==========================0\n", .{});
            if (size) {
                std.debug.print("\nWindow #{}\n", .{self.data.id});
                const cs = self.clientSize();
                std.debug.print(
                    "physical client Size (w:{},h:{}) | logical client size (w:{},h:{})\n",
                    .{
                        self.data.client_area.size.width,
                        self.data.client_area.size.height,
                        cs.width,
                        cs.height,
                    },
                );
                if (self.data.min_size) |*value| {
                    std.debug.print("Min Size: {}\n", .{value.*});
                } else {
                    std.debug.print("No Min Size:\n", .{});
                }
                if (self.data.max_size) |*value| {
                    std.debug.print("Max Size: {}\n", .{value.*});
                } else {
                    std.debug.print("No Max Size:\n", .{});
                }
                if (self.data.aspect_ratio) |*value| {
                    std.debug.print("Aspect Ratio: {}/{}\n", .{ value.x, value.y });
                } else {
                    std.debug.print("No Aspect Ratio:\n", .{});
                }
            }
            if (flags) {
                std.debug.print("Flags Mode: {}\n", .{self.data.flags});
            }
        }
    }
};

fn createPlatformWindow(
    data: *const WindowData,
    visual: ?*libx11.Visual,
    depth: c_int,
) WindowError!libx11.Window {
    const EVENT_MASK = libx11.KeyReleaseMask |
        libx11.KeyPressMask |
        libx11.ButtonPressMask |
        libx11.ButtonReleaseMask |
        libx11.EnterWindowMask |
        libx11.LeaveWindowMask |
        libx11.FocusChangeMask |
        libx11.VisibilityChangeMask |
        libx11.PointerMotionMask |
        libx11.StructureNotifyMask |
        libx11.PropertyChangeMask |
        libx11.ExposureMask;

    var attribs: libx11.XSetWindowAttributes = std.mem.zeroes(
        libx11.XSetWindowAttributes,
    );

    attribs.event_mask = EVENT_MASK;
    const drvr = X11Driver.singleton();
    attribs.colormap = libx11.XCreateColormap(
        drvr.handles.xdisplay,
        drvr.windowManagerId(),
        visual,
        libx11.AllocNone,
    );

    var window_size = data.client_area.size;
    if (data.flags.is_dpi_aware) {
        window_size.scaleBy(drvr.g_screen_scale);
    }

    const handle = libx11.XCreateWindow(
        drvr.handles.xdisplay,
        drvr.windowManagerId(),
        data.client_area.top_left.x,
        data.client_area.top_left.y,
        @intCast(window_size.width),
        @intCast(window_size.height),
        0,
        depth,
        libx11.InputOutput,
        visual,
        libx11.CWEventMask | libx11.CWBorderPixel | libx11.CWColormap,
        @ptrCast(&attribs),
    );

    if (handle == 0) {
        return WindowError.CreateFail;
    }

    // TODO: handle non is_fullscreen = true,

    return handle;
}

fn setInitialWindowPropeties(
    window: libx11.Window,
    data: *const WindowData,
) WindowError!void {
    // communication protocols
    const drvr = X11Driver.singleton();
    var protocols = [2]libx11.Atom{
        // this allows us to recieve close request from the window manager.
        // instead of it closing the socket and crashing our app
        drvr.ewmh.WM_DELETE_WINDOW,
        // this allows the window manager to check if a window is still alive and responding
        drvr.ewmh._NET_WM_PING,
    };
    _ = libx11.XSetWMProtocols(
        drvr.handles.xdisplay,
        window,
        &protocols,
        protocols.len,
    );

    libx11.XChangeProperty(
        drvr.handles.xdisplay,
        window,
        drvr.ewmh._NET_WM_PID,
        libx11.XA_CARDINAL,
        32,
        libx11.PropModeReplace,
        @ptrCast(&drvr.pid),
        1,
    );

    // if supported declare window type.
    if (drvr.ewmh._NET_WM_WINDOW_TYPE != 0 and
        drvr.ewmh._NET_WM_WINDOW_TYPE_NORMAL != 0)
    {
        libx11.XChangeProperty(
            drvr.handles.xdisplay,
            window,
            drvr.ewmh._NET_WM_WINDOW_TYPE,
            libx11.XA_ATOM,
            32,
            libx11.PropModeReplace,
            @ptrCast(&drvr.ewmh._NET_WM_WINDOW_TYPE_NORMAL),
            1,
        );
    }

    // WMHints.

    var hints = libx11.XAllocWMHints() orelse return WindowError.CreateFail;
    defer _ = libx11.XFree(hints);
    hints.flags = libx11.StateHint;
    hints.initial_state = libx11.NormalState;
    _ = libx11.XSetWMHints(drvr.handles.xdisplay, window, @ptrCast(hints));

    // resizablitity
    var size_hints = libx11.XAllocSizeHints() orelse
        return WindowError.CreateFail;

    defer _ = libx11.XFree(size_hints);
    size_hints.flags |= libx11.PWinGravity;
    size_hints.win_gravity = libx11.StaticGravity;

    var window_size = data.client_area.size;
    if (data.flags.is_dpi_aware) {
        window_size.scaleBy(drvr.g_screen_scale);
    }

    if (!data.flags.is_resizable) {
        size_hints.flags |= (libx11.PMinSize | libx11.PMaxSize);
        size_hints.max_width = window_size.width;
        size_hints.min_width = window_size.width;
        size_hints.max_height = window_size.height;
        size_hints.min_height = window_size.height;
    }

    _ = libx11.XSetWMNormalHints(
        drvr.handles.xdisplay,
        window,
        @ptrCast(size_hints),
    );

    // WMClassHints
    var class_hints = libx11.XAllocClassHint() orelse
        return WindowError.CreateFail;
    defer _ = libx11.XFree(class_hints);
    class_hints.res_name = bopts.X11_RES_NAME.ptr;
    class_hints.res_class = bopts.X11_CLASS_NAME.ptr;

    _ = libx11.XSetClassHint(
        drvr.handles.xdisplay,
        window,
        @ptrCast(class_hints),
    );
}

fn windowFromId(window_id: libx11.Window) ?*Window {
    const drvr = X11Driver.singleton();
    const window = drvr.findInXContext(window_id);
    return @ptrCast(@alignCast(window));
}

pub inline fn enableRawMouseMotion() bool {
    const drvr = X11Driver.singleton();
    const MASK_LEN = comptime x11ext.XIMaskLen(x11ext.XI_RawMotion);
    var mask: [MASK_LEN]u8 = [1]u8{0} ** MASK_LEN;
    var ev_mask = x11ext.XIEventMask{
        .deviceid = x11ext.XIAllMasterDevices,
        .mask_len = MASK_LEN,
        .mask = &mask,
    };
    x11ext.XISetMask(&mask, x11ext.XI_RawMotion);
    return drvr.extensions.xi2.XISelectEvents(
        drvr.handles.xdisplay,
        drvr.windowManagerId(),
        @ptrCast(&ev_mask),
        1,
    ) == libx11.Success;
}

pub inline fn disableRawMouseMotion() bool {
    const drvr = X11Driver.singleton();
    const MASK_LEN = 1;
    var mask: [MASK_LEN]u8 = [1]u8{0} ** MASK_LEN;
    var ev_mask = x11ext.XIEventMask{
        .deviceid = x11ext.XIAllMasterDevices,
        .mask_len = MASK_LEN,
        .mask = &mask,
    };
    x11ext.XISetMask(&mask, x11ext.XI_RawMotion);
    return drvr.extensions.xi2.XISelectEvents(
        drvr.handles.xdisplay,
        drvr.windowManagerId(),
        @ptrCast(&ev_mask),
        1,
    ) == libx11.Success;
}
