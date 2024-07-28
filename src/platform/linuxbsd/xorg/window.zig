const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const utils = @import("utils.zig");
const cursor = @import("cursor.zig");
const event_handler = @import("event_handler.zig");
const bopts = @import("build-options");

const debug = std.debug;
const unix = common.unix;
const WindowData = common.window_data.WindowData;
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
};

pub const Window = struct {
    data: WindowData,
    handle: libx11.Window,
    ev_queue: ?*common.event.EventQueue,
    x11: struct {
        cursor: cursor.CursorHints,
    },

    pub const WINDOW_DEFAULT_POSITION = common.geometry.WidowPoint2D{
        .x = 0,
        .y = 0,
    };
    const Self = @This();

    pub fn init(
        allocator: Allocator,
        window_title: []const u8,
        data: *WindowData,
    ) (Allocator.Error || WindowError)!*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.data = data.*;
        self.ev_queue = null;
        self.x11 = .{
            .cursor = .{
                .mode = .Normal,
                .icon = libx11.None,
                .pos = .{ .x = 0, .y = 0 },
            },
        };

        const drvr = X11Driver.singleton();
        self.handle = try createPlatformWindow(data, drvr);

        if (!drvr.addToXContext(self.handle, @ptrCast(self))) {
            return WindowError.CreateFail;
        }

        try setInitialWindowPropeties(self.handle, data);

        self.setTitle(window_title);
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

    pub fn processEvents(self: *const Self) WindowError!void {
        _ = self;
        var e: libx11.XEvent = undefined;
        const drvr = X11Driver.singleton();
        drvr.flushXRequests();
        while (drvr.nextXEvent(&e)) {
            const window = windowFromId(e.xany.window);
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
    fn updateNormalHints(self: *Self) void {
        if (self.data.flags.is_fullscreen) {
            return;
        }
        const size_hints = libx11.XAllocSizeHints();
        if (size_hints) |hints| {
            const drvr = X11Driver.singleton();
            var supplied: u32 = 0;
            _ = libx11.XGetWMNormalHints(
                drvr.handle.xdisplay,
                self.handle,
                hints,
                &supplied,
            );
            hints.flags &= ~(libx11.PMinSize |
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
                drvr.handle.xdisplay,
                self.handle,
                hints,
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
                .send_event = libx11.True,
                .data = .{ .l = [5]c_long{
                    _NET_WM_STATE_ADD,
                    drvr.ewmh._NET_WM_STATE_DEMANDS_ATTENTION,
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
        libx11.XRaiseWindow(drvr.handles.xdisplay, self.handle);
        libx11.XSetInputFocus(
            drvr.handles.xdisplay,
            self.handle,
            libx11.RevertToParent,
            libx11.CurrentTime,
        );
    }

    /// Returns the position of the top left corner of the client area.
    pub fn clientPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.data.client_area.top_left;
    }

    /// Moves the client's top left corner
    /// to the specified screen coordinates.
    pub fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        const drvr = X11Driver.singleton();
        libx11.XMoveWindow(drvr.handles.xdisplay, self.handle, @intCast(x), @intCast(y));
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

        if (self.data.flags.is_dpi_aware) {
            const drvr = X11Driver.singleton();
            size.scaleBy(drvr.g_screen_scale);
        }
        const drvr = X11Driver.singleton();
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

        self.updateNormalHints();
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

        self.updateNormalHints();
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
        self.data.aspect_ratio = ratio;
        self.updateNormalHints();
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setResizable(self: *Self, value: bool) void {
        self.data.flags.is_resizable = value;
        self.updateNormalHints();
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setDecorated(self: *Self, value: bool) void {
        const drvr = X11Driver.singleton();
        self.data.flags.is_decorated = value;
        var deco_hints: extern struct {
            flags: c_ulong,
            functins: c_ulong,
            decorations: c_ulong,
            input_mode: c_long,
            status: c_ulong,
        } = undefined;

        deco_hints = std.mem.zeroes(@TypeOf(deco_hints));

        deco_hints.flags = 2;
        deco_hints.decorations = if (value) 1 else 0;

        libx11.XChangeProperty(
            drvr.handles.xdisplay,
            self.handle,
            drvr.ewmh._MOTIF_WM_HINTS,
            drvr.ewmh._MOTIF_WM_HINTS,
            32,
            libx11.PropModeReplace,
            @ptrCast(&deco_hints),
            @intCast(@sizeOf(@TypeOf(deco_hints)) / @sizeOf(c_long)),
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
                .xclient = .{
                    .window = self.handle,
                    .format = 32,
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
                .xclient = .{
                    .window = self.handle,
                    .format = 32,
                    .message_type = drvr.ewmh._NET_WM_STATE,
                    .data = .{
                        .l = .{
                            _NET_WM_STATE_REMOVE,
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
    pub inline fn title(
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

    // /// Returns a cached slice that contains the path(s) to the last dropped file(s).
    // pub fn droppedFiles(self: *const Self) [][]const u8 {
    //     return self.win32.dropped_files.items;
    // }
    //
    // pub inline fn setDragAndDrop(self: *Self, accepted: bool) void {
    //     const accept = if (accepted)
    //         win32.TRUE
    //     else blk: {
    //         self.freeDroppedFiles();
    //         break :blk win32.FALSE;
    //     };
    //     DragAcceptFiles(self.handle, accept);
    // }
    //
    // /// Frees the allocated memory used to hold the file(s) path(s).
    // pub fn freeDroppedFiles(self: *Self) void {
    //     // Avoid double free.
    //     if (self.win32.dropped_files.capacity == 0) {
    //         return;
    //     }
    //     const allocator = self.win32.dropped_files.allocator;
    //     for (self.win32.dropped_files.items) |item| {
    //         allocator.free(item);
    //     }
    //     self.win32.dropped_files.clearAndFree();
    // }

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

    pub fn setCursorPosition(self: *const Self, x: i32, y: i32) void {
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

    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (common.IS_DEBUG) {
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
    drvr: *const X11Driver,
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

    const visual = libx11.DefaultVisual(
        drvr.handles.xdisplay,
        drvr.handles.default_screen,
    );
    const depth = libx11.DefaultDepth(
        drvr.handles.xdisplay,
        drvr.handles.default_screen,
    );

    var attribs: libx11.XSetWindowAttributes = std.mem.zeroes(
        libx11.XSetWindowAttributes,
    );

    attribs.event_mask = EVENT_MASK;

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
        libx11.CWEventMask,
        @ptrCast(&attribs),
    );

    if (handle == 0) {
        return WindowError.CreateFail;
    }

    // TODO: handle non is_decorated = false,
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
