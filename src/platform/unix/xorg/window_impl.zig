const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const utils = @import("utils.zig");
const keyboard_and_mouse = common.keyboard_and_mouse;
const MonitorStore = @import("internals.zig").MonitorStore;
const X11Context = @import("global.zig").X11Context;
const WindowData = common.window_data.WindowData;
const Allocator = std.mem.Allocator;

pub const WindowError = error{
    FailedToCreateWindow,
    FailedToCopyTitle,
};

/// Holds all the refrences we use to communitcate with the WidowContext.
pub const WidowProps = struct {
    events_queue: *common.event.EventQueue,
    monitors: *MonitorStore,
};

pub const WindowImpl = struct {
    data: WindowData,
    widow: WidowProps,
    handle: libx11.Window,
    pub const WINDOW_DEFAULT_POSITION = common.geometry.WidowPoint2D{
        .x = 0,
        .y = 0,
    };
    const Self = @This();

    pub fn create(
        allocator: Allocator,
        window_title: []const u8,
        data: *WindowData,
        events_queue: *common.event.EventQueue,
        monitor_store: *MonitorStore,
    ) (Allocator.Error || WindowError)!*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);
        self.widow = WidowProps{
            .events_queue = events_queue,
            .monitors = monitor_store,
        };
        self.data = data.*;

        self.handle = try createPlatformWindow(data);

        self.setTitle(allocator, window_title);
        if (self.data.flags.is_visible) {
            self.show();
            if (self.data.flags.is_focused) {
                // instance.focus();
            }
        }

        return self;
    }

    /// Destroy the window
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        std.debug.assert(self.handle != 0);
        const x11cntxt = X11Context.singleton();
        _ = libx11.XUnmapWindow(x11cntxt.handles.xdisplay, self.handle);
        _ = libx11.XDestroyWindow(x11cntxt.handles.xdisplay, self.handle);
        self.handle = 0;
        allocator.destroy(self);
    }

    pub fn processEvents(self: *Self) void {
        var e: libx11.XEvent = undefined;
        const g_instance = X11Context.singleton();
        _ = libx11.XNextEvent(g_instance.handles.xdisplay, &e);
        // std.debug.print("\n processing \n", .{});
        // if (e.type == libx11.KeyPress) {
        //     if (e.xkey.keycode == 65) {
        //         const event = common.event.createCloseEvent(self.data.id);
        //         self.sendEvent(&event);
        //     }
        // }

        handleXEvent(&e, self);
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        std.debug.assert(self.handle != 0);
        if (self.data.flags.is_visible) {
            return;
        }
        const x11cntxt = X11Context.singleton();
        _ = libx11.XMapWindow(x11cntxt.handles.xdisplay, self.handle);
        self.data.flags.is_visible = true;
    }

    /// Hides the window.
    pub fn hide(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const x11cntxt = X11Context.singleton();
        _ = libx11.XUnmapWindow(x11cntxt.handles.xdisplay, self.handle);
        self.data.flags.is_visible = false;
    }

    /// Add an event to the events queue.
    pub fn sendEvent(self: *Self, event: *const common.event.Event) void {
        self.widow.events_queue.queueEvent(event);
    }

    /// Add an event to the X Server.
    pub fn sendXEvent(
        self: *const Self,
        msg_type: libx11.Atom,
        l0: c_long,
        l1: c_long,
        l2: c_long,
        l3: c_long,
        l4: c_long,
    ) void {
        const x11cntxt = X11Context.singleton();
        var event = libx11.XEvent{ .xclient = libx11.XClientMessageEvent{
            .type = libx11.ClientMessage,
            .display = x11cntxt.handles.xdisplay,
            .window = self.handle,
            .message_type = msg_type,
            .data = .{ .l = [5]c_long{ l0, l1, l2, l3, l4 } },
            .format = 32,
            .serial = 0,
            .send_event = libx11.True,
        } };
        // [https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#idm45717752103616]
        _ = libx11.XSendEvent(
            x11cntxt.handles.xdisplay,
            x11cntxt.handles.root_window,
            libx11.False,
            libx11.SubstructureNotifyMask | libx11.SubstructureRedirectMask,
            &event,
        );
    }

    pub fn waitEvent() void {
        const x11cntxt = X11Context.singleton();
        _ = libx11.XPending(x11cntxt.handles.xdisplay);
    }

    /// the window should belong to the thread calling this function.
    /// Waits for an input event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) bool {
        _ = timeout;
        _ = self;
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
        var size_hints = libx11.XAllocSizeHints();
        if (size_hints) |hints| {
            const x11cntxt = X11Context.singleton();
            var supplied: u32 = 0;
            _ = libx11.XGetWMNormalHints(x11cntxt.handle.xdisplay, self.handle, hints, &supplied);
            hints.flags &= ~(libx11.PMinSize | libx11.PMaxSize | libx11.PAspect);
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
            _ = libx11.XSetWMNormalHints(x11cntxt.handle.xdisplay, self.handle, hints);
            _ = libx11.XFree(hints);
        }
    }

    pub fn cursorPositon(self: *const Self) common.geometry.WidowPoint2D {
        _ = self;
    }

    pub fn setCursorPosition(self: *const Self, x: i32, y: i32) void {
        _ = y;
        _ = x;
        _ = self;
    }

    // pub fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
    // }

    /// Notify and flash the taskbar.
    /// Requires window manager support.
    /// returns true on success.
    pub fn flash(self: *const Self) bool {
        const x11cntxt = X11Context.singleton();
        if (x11cntxt.ewmh._NET_WM_STATE_DEMANDS_ATTENTION == 0) {
            // Silently return.
            return false;
        }
        // TODO: refactor.
        const _NET_WM_STATE_ADD = @as(c_long, 1);

        std.debug.print("\nFlashin\n", .{});
        self.sendXEvent(
            x11cntxt.ewmh._NET_WM_STATE,
            _NET_WM_STATE_ADD,
            @intCast(x11cntxt.ewmh._NET_WM_STATE_DEMANDS_ATTENTION),
            0,
            1,
            0,
        );
        return true;
    }

    /// Returns the position of the top left corner of the client area.
    pub fn clientPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.data.client_area.top_left;
    }

    /// Moves the client's top left corner
    /// to the specified screen coordinates.
    pub fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        const x11cntxt = X11Context.singleton();
        _ = libx11.XMoveWindow(x11cntxt.handles.xdisplay, self.handle, x, y);
        _ = libx11.XFlush(x11cntxt.handles.xdisplay);
    }

    /// Returns the Physical size of the window's client area
    pub fn clientPixelSize(self: *const Self) common.geometry.WidowSize {
        // TODO: set during event handling.
        return common.geometry.WidowSize{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
    }

    // /// Returns the logical size of the window's client area
    // pub fn clientSize(self: *const Self) common.geometry.WidowSize {
    // }

    /// Sets the new (width,height) of the window's client area
    pub fn setClientSize(self: *Self, size: *common.geometry.WidowSize) void {
        const x11cntxt = X11Context.singleton();
        if (!self.data.flags.is_fullscreen) {
            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                _ = self.scalingDPI(&scaler);
                size.scaleBy(scaler);
            }

            _ = libx11.XResizeWindow(
                x11cntxt.handles.xdisplay,
                self.handle,
                size.width,
                size.height,
            );

            _ = libx11.XFlush(x11cntxt.handles.xdisplay);
        }
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
                        .{ size.width, size.height, max_size.width, max_size.height },
                    );
                    return;
                }
            }

            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                _ = self.scalingDPI(&scaler);
                size.scaleBy(scaler);
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
                if (size.width < min_size.width or size.height < min_size.height) {
                    std.log.err(
                        "[Window] Specified maximum size(w:{},h:{}) is less than the minimum size(w:{},h:{})\n",
                        .{ size.width, size.height, min_size.width, min_size.height },
                    );
                    return;
                }
            }
            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                _ = self.scalingDPI(&scaler);
                size.scaleBy(scaler);
            }
            self.data.max_size = size;
        } else {
            self.data.max_size = null;
        }

        self.updateNormalHints();
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setResizable(self: *Self, value: bool) void {
        self.data.flags.is_resizable = value;
        self.updateNormalHints();
    }

    // /// Toggles window resizablitity on(true) or off(false).
    // pub fn setDecorated(self: *Self, value: bool) void {
    //     self.data.flags.is_decorated = value;
    //     self.updateStyles();
    // }

    /// Maximize the window.
    pub fn maximize(self: *const Self) void {
        self.data.flags.is_maximized = true;
    }

    /// Minimizes the window
    pub fn minimize(self: *const Self) void {
        const x11cntxt = X11Context.singleton();
        libx11.XIconifyWindow(
            x11cntxt.handles.xdisplay,
            self.handle,
            x11cntxt.handles.default_screen,
        );
        _ = libx11.XFlush(x11cntxt.handles.xdisplay);
        self.data.flags.is_minimized = true;
    }

    /// Restores the minimized or maximized window to a normal window.
    pub fn restore(self: *const Self) void {
        _ = self;
    }

    /// Changes the title of the window.
    /// the allocator parameter is accepted for compatibility reasons.
    pub fn setTitle(self: *Self, _: std.mem.Allocator, new_title: []const u8) void {
        const x11cntxt = X11Context.singleton();
        const name_atom = if (x11cntxt.ewmh._NET_WM_NAME != 0) x11cntxt.ewmh._NET_WM_NAME else x11cntxt.ewmh._NET_WM_VISIBLE_NAME;
        const icon_atom = if (x11cntxt.ewmh._NET_WM_ICON_NAME != 0) x11cntxt.ewmh._NET_WM_ICON_NAME else x11cntxt.ewmh._NET_WM_VISIBLE_ICON_NAME;
        libx11.XChangeProperty(
            x11cntxt.handles.xdisplay,
            self.handle,
            name_atom,
            x11cntxt.ewmh.UTF8_STRING,
            8,
            libx11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );

        libx11.XChangeProperty(
            x11cntxt.handles.xdisplay,
            self.handle,
            icon_atom,
            x11cntxt.ewmh.UTF8_STRING,
            8,
            libx11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );
        x11cntxt.flushXRequests();
    }

    /// Returns the title of the window.
    pub inline fn title(self: *const Self, allocator: Allocator) (WindowError || Allocator.Error)![]u8 {
        const x11cntxt = X11Context.singleton();
        var data: [*:0]u8 = undefined;
        const data_len = utils.x11WindowProperty(
            x11cntxt.handles.xdisplay,
            self.handle,
            x11cntxt.ewmh._NET_WM_NAME,
            x11cntxt.ewmh.UTF8_STRING,
            @ptrCast(&data),
        ) catch |e| {
            utils.debugPropError(e, x11cntxt.ewmh._NET_WM_NAME);
            return WindowError.FailedToCopyTitle;
        };
        defer _ = libx11.XFree(data);
        var window_title = try allocator.alloc(u8, data_len);
        @memcpy(window_title, data);
        return window_title;
    }

    /// Returns the window's current opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn opacity(self: *const Self) f64 {
        const x11cntxt = X11Context.singleton();
        var cardinal: ?*libx11.XID = null; // cardinal, and xid are the same bitwidth.
        const OPAQUE = @as(u32, 0xFFFFFFFF);
        _ = utils.x11WindowProperty(
            x11cntxt.handles.xdisplay,
            self.handle,
            x11cntxt.ewmh._NET_WM_WINDOW_OPACITY,
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
        const x11cntxt = X11Context.singleton();
        if (x11cntxt.ewmh._NET_WM_WINDOW_OPACITY == 0) {
            return false;
        }

        if (value == @as(f64, 1.0)) {
            // it's faster to just delete the property.
            libx11.XDeleteProperty(
                x11cntxt.handles.xdisplay,
                self.handle,
                x11cntxt.ewmh._NET_WM_WINDOW_OPACITY,
            );
        } else {
            const OPAQUE = @as(u32, 0xFFFFFFFF);
            const alpha: libx11.XID = @intFromFloat(value * @as(f64, @floatFromInt(OPAQUE)));
            libx11.XChangeProperty(
                x11cntxt.handles.xdisplay,
                self.handle,
                x11cntxt.ewmh._NET_WM_WINDOW_OPACITY,
                libx11.XA_CARDINAL,
                32,
                libx11.PropModeReplace,
                @ptrCast(&alpha),
                1,
            );
        }
        return true;
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
        self.data.aspect_ratio = ratio;
        self.updateNormalHints();
    }

    // /// Returns the fullscreen mode of the window;
    // pub fn setFullscreen(self: *Self, value: bool, video_mode: ?*common.video_mode.VideoMode) !void {
    //
    //     // The video mode switch should always be done first
    //     const monitor_handle = self.occupiedMonitor();
    //     try self.widow.monitors.setMonitorVideoMode(monitor_handle, video_mode);
    //
    //     if (self.data.flags.is_fullscreen != value) {
    //         if (value) {
    //             // save for when we exit the fullscreen mode
    //             self.win32.restore_frame = self.data.client_area;
    //
    //             self.data.flags.is_fullscreen = true;
    //             self.updateStyles();
    //             try self.acquireMonitor(monitor_handle);
    //         } else {
    //             try self.releaseMonitor(monitor_handle);
    //             self.requestRestore();
    //         }
    //     }
    // }
    //
    // pub fn requestRestore(self: *Self) void {
    //     self.data.flags.is_fullscreen = false;
    //     self.updateStyles();
    //     self.win32.restore_frame = null;
    // }
    //
    // pub fn acquireMonitor(self: *Self, monitor_handle: win32.HMONITOR) !void {
    //     var mon_area: common.geometry.WidowArea = undefined;
    //
    //     try self.widow.monitors.setMonitorWindow(
    //         monitor_handle,
    //         self,
    //         &mon_area,
    //     );
    //
    //     const POSITION_FLAGS: u32 = @intFromEnum(win32_window_messaging.SWP_NOZORDER) |
    //         @intFromEnum(win32_window_messaging.SWP_NOACTIVATE) |
    //         @intFromEnum(win32_window_messaging.SWP_NOCOPYBITS);
    //
    //     const top = if (self.data.flags.is_topmost)
    //         win32_window_messaging.HWND_TOPMOST
    //     else
    //         win32_window_messaging.HWND_NOTOPMOST;
    //
    //     setWindowPositionIntern(
    //         self.handle,
    //         top,
    //         POSITION_FLAGS,
    //         mon_area.top_left.x,
    //         mon_area.top_left.y,
    //         mon_area.size.width,
    //         mon_area.size.height,
    //     );
    // }
    //
    // pub fn releaseMonitor(self: *const Self, monitor_handle: win32.HMONITOR) !void {
    //     try self.widow.monitors.restoreMonitor(monitor_handle);
    // }
    //
    // pub inline fn occupiedMonitor(self: *const Self) win32.HMONITOR {
    //     return win32_gdi.MonitorFromWindow(self.handle, win32_gdi.MONITOR_DEFAULTTONEAREST).?;
    // }
    //
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
    //
    // pub fn setIcon(self: *Self, pixels: ?[]const u8, width: i32, height: i32) !void {
    //     const new_icon = try internals.createIcon(pixels, width, height);
    //     const handles = if (new_icon.sm_handle != null and new_icon.bg_handle != null)
    //         .{ @intFromPtr(new_icon.bg_handle.?), @intFromPtr(new_icon.sm_handle.?) }
    //     else blk: {
    //         const bg_icon = win32_window_messaging.GetClassLongPtrW(self.handle, win32_window_messaging.GCLP_HICON);
    //         const sm_icon = win32_window_messaging.GetClassLongPtrW(self.handle, win32_window_messaging.GCLP_HICONSM);
    //         break :blk .{ bg_icon, sm_icon };
    //     };
    //     _ = win32_window_messaging.SendMessageW(
    //         self.handle,
    //         win32_window_messaging.WM_SETICON,
    //         win32_window_messaging.ICON_BIG,
    //         @bitCast(handles[0]),
    //     );
    //     _ = win32_window_messaging.SendMessageW(
    //         self.handle,
    //         win32_window_messaging.WM_SETICON,
    //         win32_window_messaging.ICON_SMALL,
    //         @bitCast(handles[1]),
    //     );
    //     icon.destroyIcon(&self.win32.icon);
    //     self.win32.icon = new_icon;
    // }
    //
    // pub fn setCursor(self: *Self, pixels: ?[]const u8, width: i32, height: i32, xhot: u32, yhot: u32) !void {
    //     const new_cursor = try internals.createCursor(pixels, width, height, xhot, yhot);
    //     icon.destroyCursor(&self.win32.cursor);
    //     self.win32.cursor = new_cursor;
    //     if (self.data.flags.cursor_in_client) {
    //         updateCursorImage(&self.win32.cursor);
    //     }
    // }
    //
    // pub fn setStandardCursor(self: *Self, cursor_shape: common.cursor.StandardCursorShape) !void {
    //     const new_cursor = try internals.createStandardCursor(cursor_shape);
    //     icon.destroyCursor(&self.win32.cursor);
    //     self.win32.cursor = new_cursor;
    //     if (self.data.flags.cursor_in_client) {
    //         updateCursorImage(&self.win32.cursor);
    //     }
    // }

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
) WindowError!libx11.Window {
    const EVENT_MASK = libx11.KeyReleaseMask | libx11.KeyPressMask | libx11.ButtonPressMask |
        libx11.ButtonReleaseMask | libx11.EnterWindowMask | libx11.LeaveWindowMask |
        libx11.FocusChangeMask | libx11.VisibilityChangeMask | libx11.PointerMotionMask |
        libx11.StructureNotifyMask | libx11.PropertyChangeMask | libx11.ExposureMask;

    const x11cntxt = X11Context.singleton();
    const visual = libx11.DefaultVisual(x11cntxt.handles.xdisplay, x11cntxt.handles.default_screen);
    const depth = libx11.DefaultDepth(x11cntxt.handles.xdisplay, x11cntxt.handles.default_screen);
    var attrib: libx11.XSetWindowAttributes = std.mem.zeroes(libx11.XSetWindowAttributes);
    attrib.event_mask = EVENT_MASK;
    const handle = libx11.XCreateWindow(
        x11cntxt.handles.xdisplay,
        x11cntxt.handles.root_window,
        data.client_area.top_left.x,
        data.client_area.top_left.y,
        @intCast(data.client_area.size.width),
        @intCast(data.client_area.size.height),
        0,
        depth,
        libx11.InputOutput,
        visual,
        libx11.CWEventMask,
        @ptrCast(&attrib),
    );

    if (handle == 0) {
        return WindowError.FailedToCreateWindow;
    }

    return handle;
}

fn handleXEvent(ev: *const libx11.XEvent, window: *WindowImpl) void {
    switch (ev.type) {
        libx11.ButtonPress => {
            const button_event = switch (ev.xbutton.button) {
                libx11.Button1 => common.event.createMouseButtonEvent(
                    window.data.id,
                    keyboard_and_mouse.MouseButton.Left,
                    keyboard_and_mouse.MouseButtonState.Pressed,
                    utils.decodeKeyMods(ev.xbutton.state),
                ),
                libx11.Button2 => common.event.createMouseButtonEvent(
                    window.data.id,
                    keyboard_and_mouse.MouseButton.Middle,
                    keyboard_and_mouse.MouseButtonState.Pressed,
                    utils.decodeKeyMods(ev.xbutton.state),
                ),
                libx11.Button3 => common.event.createMouseButtonEvent(
                    window.data.id,
                    keyboard_and_mouse.MouseButton.Right,
                    keyboard_and_mouse.MouseButtonState.Pressed,
                    utils.decodeKeyMods(ev.xbutton.state),
                ),

                // TODO: check which wheel
                libx11.Button4 => common.event.createScrollEvent(window.data.id, keyboard_and_mouse.MouseWheel.VerticalWheel, 1.0),
                libx11.Button5 => common.event.createScrollEvent(window.data.id, keyboard_and_mouse.MouseWheel.VerticalWheel, -1.0),

                else => {
                    std.debug.print("\nbutton:{d}\n", .{ev.xbutton.button});
                    return;
                },
            };
            window.sendEvent(&button_event);
        },
        libx11.ButtonRelease => {
            const button_event = switch (ev.xbutton.button) {
                libx11.Button1 => common.event.createMouseButtonEvent(
                    window.data.id,
                    keyboard_and_mouse.MouseButton.Left,
                    keyboard_and_mouse.MouseButtonState.Released,
                    utils.decodeKeyMods(ev.xbutton.state),
                ),
                libx11.Button2 => common.event.createMouseButtonEvent(
                    window.data.id,
                    keyboard_and_mouse.MouseButton.Middle,
                    keyboard_and_mouse.MouseButtonState.Released,
                    utils.decodeKeyMods(ev.xbutton.state),
                ),
                libx11.Button3 => common.event.createMouseButtonEvent(
                    window.data.id,
                    keyboard_and_mouse.MouseButton.Right,
                    keyboard_and_mouse.MouseButtonState.Released,
                    utils.decodeKeyMods(ev.xbutton.state),
                ),

                else => {
                    std.debug.print("\nbutton:{d}\n", .{ev.xbutton.button});
                    return;
                },
            };
            window.sendEvent(&button_event);
        },
        libx11.EnterNotify => {
            const event = common.event.createMouseEnterEvent(window.data.id);
            window.sendEvent(&event);
            window.data.flags.cursor_in_client = true;
        },
        libx11.LeaveNotify => {
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseLeftEvent(window.data.id);
            window.sendEvent(&event);
        },
        libx11.DestroyNotify => {
            const event = common.event.createCloseEvent(window.data.id);
            window.sendEvent(&event);
        },
        else => {},
    }
}

test "local_window_test" {
    try X11Context.initSingleton();
    var window = WindowImpl{
        .data = WindowData{
            .client_area = common.geometry.WidowArea.init(0, 0, 800, 600),
            .id = 1,
            .flags = undefined,
            .input = undefined,
            .min_size = null,
            .max_size = null,
            .aspect_ratio = null,
        },
        .widow = undefined,
        .handle = 0,
    };
    _ = window;
    // try WindowImpl.setup(&window, std.testing.allocator, "Local Window");
    // window.close();
    // X11Context.deinitSingleton();
}
