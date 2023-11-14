const std = @import("std");
const common = @import("common");
const libX11 = @import("x11/xlib.zig");
const MonitorStore = @import("internals.zig").MonitorStore;
const WindowData = common.window_data.WindowData;
const X11Context = @import("global.zig").X11Context;
const Allocator = std.mem.Allocator;

pub const WindowError = error{
    WindowCreationFailure,
};

/// Holds all the refrences we use to communitcate with the WidowContext.
pub const WidowProps = struct {
    events_queue: *common.event.EventQueue,
    monitors: *MonitorStore,
};

pub const WindowImpl = struct {
    data: WindowData,
    widow: WidowProps,
    handle: libX11.Window,
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

        self.setTitle(window_title);
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
        _ = libX11.XUnmapWindow(x11cntxt.handles.xdisplay, self.handle);
        _ = libX11.XDestroyWindow(x11cntxt.handles.xdisplay, self.handle);
        self.handle = 0;
        allocator.destroy(self);
    }

    pub fn processEvents(self: *Self) void {
        var e: libX11.XEvent = undefined;
        const g_instance = X11Context.singleton();
        _ = libX11.XNextEvent(g_instance.handles.xdisplay, &e);
        if (e.type == libX11.KeyPress) {
            // Temp for breaking.
            // A
            if (e.xkey.keycode == 65) {
                self.hide();
            }
            _ = self.flash();
        }
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const x11cntxt = X11Context.singleton();
        _ = libX11.XMapWindow(x11cntxt.handles.xdisplay, self.handle);
        self.data.flags.is_visible = true;
    }

    /// Hide the window.
    pub fn hide(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const x11cntxt = X11Context.singleton();
        _ = libX11.XUnmapWindow(x11cntxt.handles.xdisplay, self.handle);
        self.data.flags.is_visible = false;
    }

    /// Add an event to the events queue.
    pub fn sendEvent(self: *Self, event: *const common.event.Event) void {
        self.widow.events_queue.queueEvent(event);
    }

    /// Add an event to the X Server.
    pub fn sendXEvent(
        self: *const Self,
        msg_type: libX11.Atom,
        l0: c_long,
        l1: c_long,
        l2: c_long,
        l3: c_long,
        l4: c_long,
    ) void {
        const x11cntxt = X11Context.singleton();
        var event = libX11.XEvent{ .xclient = libX11.XClientMessageEvent{
            .type = libX11.ClientMessage,
            .display = x11cntxt.handles.xdisplay,
            .window = self.handle,
            .message_type = msg_type,
            .data = .{ .l = [5]c_long{ l0, l1, l2, l3, l4 } },
            .format = 32,
            .serial = 0,
            .send_event = libX11.True,
        } };
        // [https://specifications.freedesktop.org/wm-spec/wm-spec-1.3.html#idm45717752103616]
        _ = libX11.XSendEvent(
            x11cntxt.handles.xdisplay,
            x11cntxt.handles.root_window,
            libX11.False,
            libX11.SubstructureNotifyMask | libX11.SubstructureRedirectMask,
            &event,
        );
    }

    pub fn waitEvent() void {
        const x11cntxt = X11Context.singleton();
        _ = libX11.XPending(x11cntxt.handles.xdisplay);
    }

    /// the window should belong to the thread calling this function.
    /// Waits for an input event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) bool {
        _ = timeout;
        _ = self;
    }

    /// Updates the registered window styles to match the current window config.
    fn updateStyles(self: *Self) void {
        _ = self;
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
        _ = y;
        _ = x;
        _ = self;
    }

    /// Returns the Physical size of the window's client area
    pub fn clientPixelSize(self: *const Self) common.geometry.WidowSize {
        return common.geometry.WidowSize{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
    }

    // /// Returns the logical size of the window's client area
    // pub fn clientSize(self: *const Self) common.geometry.WidowSize {
    // }

    // /// Sets the new (width,height) of the window's client area
    // pub fn setClientSize(self: *Self, size: *common.geometry.WidowSize) void {
    //     if (!self.data.flags.is_fullscreen) {
    //         var dpi: ?u32 = null;
    //         if (self.data.flags.is_dpi_aware) {
    //             var scaler: f64 = undefined;
    //             dpi = self.scalingDPI(&scaler);
    //             size.scaleBy(scaler);
    //         }
    //
    //         var new_client_rect = win32_foundation.RECT{
    //             .left = 0,
    //             .top = 0,
    //             .right = size.width,
    //             .bottom = size.height,
    //         };
    //
    //         adjustWindowRect(
    //             &new_client_rect,
    //             windowStyles(&self.data.flags),
    //             windowExStyles(&self.data.flags),
    //             dpi,
    //         );
    //         if (self.data.flags.is_maximized) {
    //             // un-maximize the window
    //             self.restore();
    //         }
    //
    //         const POSITION_FLAGS: u32 = comptime @intFromEnum(win32_window_messaging.SWP_NOACTIVATE) |
    //             @intFromEnum(win32_window_messaging.SWP_NOREPOSITION) |
    //             @intFromEnum(win32_window_messaging.SWP_NOZORDER) |
    //             @intFromEnum(win32_window_messaging.SWP_NOMOVE);
    //
    //         const top = if (self.data.flags.is_topmost)
    //             win32_window_messaging.HWND_TOPMOST
    //         else
    //             win32_window_messaging.HWND_NOTOPMOST;
    //
    //         setWindowPositionIntern(
    //             self.handle,
    //             top,
    //             POSITION_FLAGS,
    //             0,
    //             0,
    //             new_client_rect.right - new_client_rect.left,
    //             new_client_rect.bottom - new_client_rect.top,
    //         );
    //     }
    // }
    //
    // pub fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
    //     if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
    //         // No need to do anything.
    //         return;
    //     }
    //
    //     if (min_size != null) {
    //         var size = min_size.?;
    //         // min size shouldn't be negative.
    //         std.debug.assert(size.width > 0);
    //         std.debug.assert(size.height > 0);
    //
    //         if (self.data.max_size) |*max_size| {
    //             // the min size shouldn't be superior to the max size.
    //             if (max_size.width < size.width or max_size.height < size.height) {
    //                 std.log.err(
    //                     "[Window] Specified minimum size(w:{},h:{}) is less than the maximum size(w:{},h:{})\n",
    //                     .{ size.width, size.height, max_size.width, max_size.height },
    //                 );
    //                 return;
    //             }
    //         }
    //
    //         if (self.data.flags.is_dpi_aware) {
    //             var scaler: f64 = undefined;
    //             _ = self.scalingDPI(&scaler);
    //             size.scaleBy(scaler);
    //         }
    //
    //         self.data.min_size = size;
    //     } else {
    //         self.data.min_size = null;
    //     }
    //
    //     const POSITION_FLAGS: u32 = comptime @intFromEnum(win32_window_messaging.SWP_NOACTIVATE) |
    //         @intFromEnum(win32_window_messaging.SWP_NOREPOSITION) |
    //         @intFromEnum(win32_window_messaging.SWP_NOZORDER) |
    //         @intFromEnum(win32_window_messaging.SWP_NOMOVE);
    //
    //     const size = windowSize(self.handle);
    //
    //     const top = if (self.data.flags.is_topmost)
    //         win32_window_messaging.HWND_TOPMOST
    //     else
    //         win32_window_messaging.HWND_NOTOPMOST;
    //     // We need the system to post a WM_MINMAXINFO.
    //     // in order for the new size limits to be applied,
    //     setWindowPositionIntern(
    //         self.handle,
    //         top,
    //         POSITION_FLAGS,
    //         0,
    //         0,
    //         size.width,
    //         size.height,
    //     );
    // }
    //
    // pub fn setMaxSize(self: *Self, max_size: ?common.geometry.WidowSize) void {
    //     if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
    //         // No need to do anything.
    //         return;
    //     }
    //
    //     if (max_size != null) {
    //         var size = max_size.?;
    //         // max size shouldn't be negative.
    //         std.debug.assert(size.width > 0);
    //         std.debug.assert(size.height > 0);
    //         if (self.data.min_size) |*min_size| {
    //             // the max size should be superior or equal to the min size.
    //             if (size.width < min_size.width or size.height < min_size.height) {
    //                 std.log.err(
    //                     "[Window] Specified maximum size(w:{},h:{}) is less than the minimum size(w:{},h:{})\n",
    //                     .{ size.width, size.height, min_size.width, min_size.height },
    //                 );
    //                 return;
    //             }
    //         }
    //         if (self.data.flags.is_dpi_aware) {
    //             var scaler: f64 = undefined;
    //             _ = self.scalingDPI(&scaler);
    //             size.scaleBy(scaler);
    //         }
    //         self.data.max_size = size;
    //     } else {
    //         self.data.max_size = null;
    //     }
    //
    //     const POSITION_FLAGS: u32 = comptime @intFromEnum(win32_window_messaging.SWP_NOACTIVATE) |
    //         @intFromEnum(win32_window_messaging.SWP_NOREPOSITION) |
    //         @intFromEnum(win32_window_messaging.SWP_NOZORDER) |
    //         @intFromEnum(win32_window_messaging.SWP_NOMOVE);
    //
    //     const size = windowSize(self.handle);
    //
    //     const top = if (self.data.flags.is_topmost)
    //         win32_window_messaging.HWND_TOPMOST
    //     else
    //         win32_window_messaging.HWND_NOTOPMOST;
    //     // We need the system to post a WM_MINMAXINFO.
    //     // in order for the new size limits to be applied,
    //     setWindowPositionIntern(
    //         self.handle,
    //         top,
    //         POSITION_FLAGS,
    //         0,
    //         0,
    //         size.width,
    //         size.height,
    //     );
    // }
    //
    // /// Hides the window, this is different from minimizing it.
    // pub fn hide(self: *Self) void {
    //     _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_HIDE);
    //     self.data.flags.is_visible = false;
    // }
    //
    // /// Toggles window resizablitity on(true) or off(false).
    // pub fn setResizable(self: *Self, value: bool) void {
    //     self.data.flags.is_resizable = value;
    //     self.updateStyles();
    // }
    //
    // /// Toggles window resizablitity on(true) or off(false).
    // pub fn setDecorated(self: *Self, value: bool) void {
    //     self.data.flags.is_decorated = value;
    //     self.updateStyles();
    // }
    //
    // /// Maximize the window.
    // pub fn maximize(self: *const Self) void {
    //     _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_MAXIMIZE);
    // }
    //
    // /// Minimizes the window.
    // pub fn minimize(self: *const Self) void {
    //     _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_MINIMIZE);
    // }
    //
    // /// Restores the minimized or maximized window to a normal window.
    // pub fn restore(self: *const Self) void {
    //     _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_RESTORE);
    // }

    /// Changes the title of the window.
    pub fn setTitle(self: *Self, new_title: []const u8) void {
        const x11cntxt = X11Context.singleton();
        const name_atom = if (x11cntxt.ewmh._NET_WM_NAME != 0) x11cntxt.ewmh._NET_WM_NAME else x11cntxt.ewmh._NET_WM_VISIBLE_NAME;
        const icon_atom = if (x11cntxt.ewmh._NET_WM_ICON_NAME != 0) x11cntxt.ewmh._NET_WM_ICON_NAME else x11cntxt.ewmh._NET_WM_VISIBLE_ICON_NAME;
        libX11.XChangeProperty(
            x11cntxt.handles.xdisplay,
            self.handle,
            name_atom,
            x11cntxt.ewmh.UTF8_STRING,
            8,
            libX11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );

        libX11.XChangeProperty(
            x11cntxt.handles.xdisplay,
            self.handle,
            icon_atom,
            x11cntxt.ewmh.UTF8_STRING,
            8,
            libX11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );
        x11cntxt.flushXRequests();
    }

    /// Returns the title of the window.
    pub inline fn title(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        _ = allocator;
        _ = self;
        return WindowError.FailedToCopyTitle;
    }

    // /// Returns the window's current opacity
    // /// # Note
    // /// The value is between 1.0 and 0.0
    // /// with 1 being opaque and 0 being full transparent.
    // pub fn opacity(self: *const Self) f32 {
    //     const ex_styles = win32_window_messaging.GetWindowLongPtrW(self.handle, win32_window_messaging.GWL_EXSTYLE);
    //     if ((ex_styles & @intFromEnum(win32_window_messaging.WS_EX_LAYERED)) != 0) {
    //         var alpha: u8 = undefined;
    //         var flags: win32_window_messaging.LAYERED_WINDOW_ATTRIBUTES_FLAGS = undefined;
    //         _ = win32_window_messaging.GetLayeredWindowAttributes(self.handle, null, &alpha, &flags);
    //         if ((@intFromEnum(flags) & @intFromEnum(win32_window_messaging.LWA_ALPHA)) != 0) {
    //             const falpha: f32 = @floatFromInt(alpha);
    //             return (falpha / 255.0);
    //         }
    //     }
    //     return 1.0;
    // }
    //
    // /// Sets the window's opacity
    // /// # Note
    // /// The value is between 1.0 and 0.0
    // /// with 1 being opaque and 0 being full transparent.
    // pub fn setOpacity(self: *Self, value: f32) void {
    //     var ex_styles: usize = @bitCast(win32_window_messaging.GetWindowLongPtrW(
    //         self.handle,
    //         win32_window_messaging.GWL_EXSTYLE,
    //     ));
    //
    //     if (value == @as(f32, 1.0)) {
    //         ex_styles &= ~@intFromEnum(win32_window_messaging.WS_EX_LAYERED);
    //     } else {
    //         const alpha: u32 = @intFromFloat(value * 255.0);
    //
    //         if ((ex_styles & @intFromEnum(win32_window_messaging.WS_EX_LAYERED)) == 0) {
    //             ex_styles |= @intFromEnum(win32_window_messaging.WS_EX_LAYERED);
    //         }
    //
    //         _ = win32_window_messaging.SetLayeredWindowAttributes(
    //             self.handle,
    //             0,
    //             @truncate(alpha),
    //             win32_window_messaging.LWA_ALPHA,
    //         );
    //     }
    //     _ = win32_window_messaging.SetWindowLongPtrW(
    //         self.handle,
    //         win32_window_messaging.GWL_EXSTYLE,
    //         @bitCast(ex_styles),
    //     );
    // }
    //
    // pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
    //     // shamlessly copied from GLFW library.
    //     self.data.aspect_ratio = ratio;
    //     if (ratio != null) {
    //         var rect: win32.RECT = undefined;
    //         _ = win32_window_messaging.GetWindowRect(self.handle, &rect);
    //         self.applyAspectRatio(&rect, win32_window_messaging.WMSZ_BOTTOMLEFT);
    //         _ = win32_window_messaging.MoveWindow(
    //             self.handle,
    //             rect.left,
    //             rect.top,
    //             rect.right - rect.left,
    //             rect.bottom - rect.top,
    //             win32.TRUE,
    //         );
    //     }
    // }
    //
    // pub fn applyAspectRatio(self: *const Self, client: *win32_foundation.RECT, edge: u32) void {
    //     const faspect_x: f64 = @floatFromInt(self.data.aspect_ratio.?.x);
    //     const faspect_y: f64 = @floatFromInt(self.data.aspect_ratio.?.y);
    //     const ratio: f64 = faspect_x / faspect_y;
    //
    //     var rect = win32_foundation.RECT{
    //         .left = 0,
    //         .top = 0,
    //         .right = 0,
    //         .bottom = 0,
    //     };
    //
    //     adjustWindowRect(
    //         &rect,
    //         windowStyles(&self.data.flags),
    //         windowExStyles(&self.data.flags),
    //         self.scalingDPI(null),
    //     );
    //
    //     switch (edge) {
    //         win32_window_messaging.WMSZ_LEFT, win32_window_messaging.WMSZ_RIGHT, win32_window_messaging.WMSZ_BOTTOMLEFT, win32_window_messaging.WMSZ_BOTTOMRIGHT => {
    //             client.bottom = client.top + (rect.bottom - rect.top);
    //             const fborder_width: f64 = @floatFromInt((client.right - client.left) - (rect.right - rect.left));
    //             client.bottom += @intFromFloat(fborder_width / ratio);
    //         },
    //         win32_window_messaging.WMSZ_TOPLEFT, win32_window_messaging.WMSZ_TOPRIGHT => {
    //             client.top = client.bottom - (rect.bottom - rect.top);
    //             const fborder_width: f64 = @floatFromInt((client.right - client.left) - (rect.right - rect.left));
    //             client.top -= @intFromFloat(fborder_width / ratio);
    //         },
    //         win32_window_messaging.WMSZ_TOP, win32_window_messaging.WMSZ_BOTTOM => {
    //             client.right = client.left + (rect.right - rect.left);
    //             const fborder_height: f64 = @floatFromInt((client.bottom - client.top) - (rect.bottom - rect.top));
    //             client.bottom += @intFromFloat(fborder_height * ratio);
    //         },
    //         else => unreachable,
    //     }
    // }
    //
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
) WindowError!libX11.Window {
    const EVENT_MASK = libX11.KeyReleaseMask | libX11.KeyPressMask | libX11.ButtonPressMask |
        libX11.ButtonReleaseMask | libX11.EnterWindowMask | libX11.LeaveWindowMask |
        libX11.FocusChangeMask | libX11.VisibilityChangeMask | libX11.PointerMotionMask |
        libX11.StructureNotifyMask | libX11.PropertyChangeMask | libX11.ExposureMask;

    const x11cntxt = X11Context.singleton();
    const visual = libX11.DefaultVisual(x11cntxt.handles.xdisplay, x11cntxt.handles.default_screen);
    const depth = libX11.DefaultDepth(x11cntxt.handles.xdisplay, x11cntxt.handles.default_screen);
    var attrib: libX11.XSetWindowAttributes = std.mem.zeroes(libX11.XSetWindowAttributes);
    attrib.event_mask = EVENT_MASK;
    const handle = libX11.XCreateWindow(
        x11cntxt.handles.xdisplay,
        x11cntxt.handles.root_window,
        data.client_area.top_left.x,
        data.client_area.top_left.y,
        @intCast(data.client_area.size.width),
        @intCast(data.client_area.size.height),
        0,
        depth,
        libX11.InputOutput,
        visual,
        libX11.CWEventMask,
        @ptrCast(&attrib),
    );

    if (handle == 0) {
        return WindowError.WindowCreationFailure;
    }

    return handle;
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
