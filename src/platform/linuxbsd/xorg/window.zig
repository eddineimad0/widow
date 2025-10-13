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
const WidowContext = @import("platform.zig").WidowContext;
const Allocator = std.mem.Allocator;

const _NET_WM_STATE_REMOVE = 0;
const _NET_WM_STATE_ADD = 1;
const _NET_WM_STATE_TOGGLE = 2;

pub const WindowError = error{
    CreateFail,
    BadTitle,
    OutOfMemory,
    BadIcon,
    UnsupportedRenderBackend,
    GLError,
    VisualNone,
};

pub const BlitContext = struct {
    xdisplay: *libx11.Display,
    drawable: *Window,
    framebuffer: []u8,
    const Self = @This();

    pub fn init(w: *Window) mem.Allocator.Error!Self {
        debug.assert(w.x11.visual != null);
        debug.assert(w.x11.gc == null);
        debug.assert(w.x11.ximage == null);

        var gcv: libx11.XGCValues = undefined;
        { // GC creation
            gcv.graphics_exposures = libx11.False;
            w.x11.gc = libx11.dyn_api.XCreateGC(
                w.ctx.driver.handles.xdisplay,
                w.handle,
                libx11.GCGraphicsExposures,
                &gcv,
            );
            if (w.x11.gc == null) {
                @panic("TODO fail path can't create graphics context");
            }
        }

        var vinfo: libx11.XVisualInfo = undefined;
        { // visual info

            vinfo.visualid = libx11.dyn_api.XVisualIDFromVisual(w.x11.visual);
            var num_visuals: c_int = 0;
            const vi = libx11.dyn_api.XGetVisualInfo(
                w.ctx.driver.handles.xdisplay,
                libx11.VisualIDMask,
                &vinfo,
                &num_visuals,
            );

            if (vi == null) {
                @panic("TODO fail path cant get visual info");
            }

            vinfo = vi.?.*;
            _ = libx11.dyn_api.XFree(@ptrCast(vi.?));

            if (vinfo.class == libx11.DirectColor or vinfo.class == libx11.TrueColor) {
                if (vinfo.depth != 32) {
                    @panic("Unsupported");
                }
            } else {
                @panic("Unsupported");
            }
        }

        var cl_sz: common.window_data.WindowSize = undefined;
        w.getClientSize(&cl_sz);
        const BYTES_PER_PIXEL = 4; // TODO: Grab this from the visuals
        const stride: u32 = @as(u32, @intCast(cl_sz.physical_width)) * BYTES_PER_PIXEL;
        const stride_padded = (stride + 3) & ~3;
        const pixels = try w.ctx.allocator.alloc(
            u8,
            @as(u32, @intCast(cl_sz.physical_height)) * stride_padded,
        );
        w.x11.ximage = libx11.dyn_api.XCreateImage(
            w.ctx.driver.handles.xdisplay,
            w.x11.visual,
            vinfo.depth,
            libx11.ZPixmap,
            0,
            pixels.ptr,
            @intCast(cl_sz.physical_width),
            @intCast(cl_sz.physical_height),
            32,
            0,
        );

        if (w.x11.ximage == null) {
            @panic("TODO fail path cant create ximage");
        }
        w.x11.ximage.?.byte_order = libx11.LSBFirst;

        return Self{
            .xdisplay = w.ctx.driver.handles.xdisplay,
            .drawable = w,
            .framebuffer = pixels,
        };
    }

    pub fn blit(self: *Self) void {
        debug.assert(self.drawable.x11.ximage != null);
        debug.assert(self.drawable.x11.gc != null);

        var cl_sz: common.window_data.WindowSize = undefined;
        self.drawable.getClientSize(&cl_sz);
        libx11.dyn_api.XPutImage(
            self.ctx.driver.handles.xdisplay,
            self.drawable.handle,
            self.drawable.x11.gc.?,
            self.drawable.x11.ximage.?,
            0,
            0,
            0,
            0,
            @intCast(cl_sz.physical_width),
            @intCast(cl_sz.physical_height),
        );

        libx11.dyn_api.XSync(
            self.xdisplay,
            libx11.False,
        );
    }

    pub fn deinit(self: *Self) void {
        debug.assert(self.ximage != null);
        debug.assert(self.gc != null);
        debug.assert(
            self.frame_buffer.ptr == self.drawable.x11.ximage.?.data,
        );

        self.drawable.ctx.allocator.free(self.framebuffer);
        self.drawable.x11.ximage.?.data = null;
        libx11.dyn_api.XDestroyImage(self.drawable.x11.ximage.?);
        self.drawable.x11.ximage = null;
        libx11.dyn_api.XFreeGC(self.xdisplay, self.drawable.x11.gc.?);
        self.drawable.x11.gc = null;
    }
};

pub const Window = struct {
    ev_queue: ?*common.event.EventQueue,
    ctx: *WidowContext,
    handle: libx11.Window,
    data: WindowData,
    fb_cfg: FBConfig,
    x11: struct {
        xdnd_req: struct {
            raw_data: ?[*]const u8,
            paths: std.ArrayListUnmanaged([]const u8),
            version: c_long,
            src: c_long,
            format: c_long,
        },
        cursor: cursor.CursorHints,
        xdnd_allow: bool,
        windowed_area: common.geometry.Rect,
        visual: ?*libx11.Visual,
        gc: libx11.GC,
        ximage: ?*libx11.XImage,
    },

    pub const WINDOW_DEFAULT_POSITION = common.geometry.Point2D{
        .x = 0,
        .y = 0,
    };
    const Self = @This();

    pub fn init(
        ctx: *WidowContext,
        id: ?usize,
        window_title: []const u8,
        data: *WindowData,
        fb_cfg: *FBConfig,
    ) (Allocator.Error || WindowError)!*Self {
        var self = try ctx.allocator.create(Self);
        errdefer ctx.allocator.destroy(self);

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
                .paths = .empty,
            },
            .xdnd_allow = false,
            .windowed_area = data.client_area,
            .gc = null,
            .ximage = null,
            .visual = null,
        };
        self.ctx = ctx;

        //NOTE:  X11 won't let us change the visual and depth later so decide now.
        var visual: ?*libx11.Visual = null;
        var depth: c_int = 0;
        switch (fb_cfg.accel) {
            .opengl => {
                glx.initGLX(ctx.driver) catch return WindowError.GLError;
                if (!glx.chooseVisualGLX(ctx.driver, fb_cfg, &visual, &depth)) {
                    return WindowError.VisualNone;
                }
            },
            else => {
                visual = libx11.DefaultVisual(
                    ctx.driver.handles.xdisplay,
                    ctx.driver.handles.default_screen,
                );
                depth = libx11.DefaultDepth(
                    ctx.driver.handles.xdisplay,
                    ctx.driver.handles.default_screen,
                );
            },
        }

        self.handle = try createPlatformWindow(ctx.driver, data, visual, depth);
        self.x11.visual = visual;
        self.data.id = if (id) |ident| ident else @intCast(self.handle);

        if (!ctx.driver.addToXContext(self.handle, @ptrCast(self))) {
            return WindowError.CreateFail;
        }

        try setInitialWindowPropeties(ctx.driver, self.handle, data);

        self.setTitle(window_title);
        self.setClientPosition(data.client_area.top_left.x, data.client_area.top_left.y);
        self.setClientSize(&data.client_area.size);
        self.processEvents() catch return WindowError.CreateFail;

        if (!self.data.flags.is_decorated) {
            self.setDecorated(false);
        }

        if (self.data.flags.is_fullscreen) {
            _ = libx11.dyn_api.XMapRaised(ctx.driver.handles.xdisplay, self.handle);
            const ok = waitForWindowVisibility(ctx.driver.handles.xdisplay, self.handle);
            self.data.flags.is_fullscreen = false;
            if (!ok or !self.setFullscreen(true)) return WindowError.CreateFail;
        } else {
            if (self.data.flags.is_visible) {
                self.show();

                if (self.data.flags.is_focused) {
                    self.focus();
                }
            }
        }

        return self;
    }

    /// Destroy the window
    pub fn deinit(self: *Self) void {
        std.debug.assert(self.handle != 0);
        self.ev_queue = null;
        if (self.data.flags.is_fullscreen) _ = self.setFullscreen(false);
        self.setCursorMode(.Normal);
        _ = libx11.dyn_api.XUnmapWindow(self.ctx.driver.handles.xdisplay, self.handle);
        _ = libx11.dyn_api.XDestroyWindow(self.ctx.driver.handles.xdisplay, self.handle);
        _ = self.ctx.driver.removeFromXContext(self.handle);
        self.freeDroppedFiles();
        self.handle = 0;
        const ctx = self.ctx;
        ctx.allocator.destroy(self);
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
        self.ctx.driver.flushXRequests();
        while (self.ctx.driver.nextXEvent(&e)) {
            const window: ?*Window = if (self.handle == e.xany.window)
                self
            else
                windowFromId(self.ctx.driver, e.xany.window);

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
                event_handler.handleNonWindowEvent(&e, self.ctx);
            }
        }
    }

    pub fn waitEvent(self: *Self) WindowError!void {
        // indefinetly wait
        const ok = waitOnX11Socket(self.ctx.driver.handles.xdisplay, -1);
        debug.assert(ok);
        try self.processEvents();
    }

    /// Waits for an event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) WindowError!bool {
        const ok = waitOnX11Socket(self.ctx.driver.handles.xdisplay, timeout);
        if (ok) {
            try self.processEvents();
        }
        return ok;
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const drvr = self.ctx.driver;
        _ = libx11.dyn_api.XMapWindow(self.ctx.driver.handles.xdisplay, self.handle);
        drvr.flushXRequests();
        self.data.flags.is_visible = true;
    }

    /// Hide the window.
    pub fn hide(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const drvr = self.ctx.driver;
        _ = libx11.dyn_api.XUnmapWindow(self.ctx.driver.handles.xdisplay, self.handle);
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
                var ev: libx11.XEvent = undefined;
                ev.type = libx11.ClientMessage;
                ev.xclient.window = self.handle;
                ev.xclient.message_type = X11Driver.CUSTOM_CLIENT_ERR;
                ev.xclient.format = 32;
                ev.xclient.data.l[0] = @intFromError(err);
                std.debug.assert(ev.xclient.message_type != 0);
                self.ctx.driver.sendXEvent(&ev, self.handle);
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

        const size_hints = libx11.dyn_api.XAllocSizeHints();
        if (size_hints) |hints| {
            defer _ = libx11.dyn_api.XFree(hints);
            var supplied: c_long = 0;
            _ = libx11.dyn_api.XGetWMNormalHints(
                self.ctx.driver.handles.xdisplay,
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
            _ = libx11.dyn_api.XSetWMNormalHints(
                self.ctx.driver.handles.xdisplay,
                self.handle,
                @ptrCast(hints),
            );
        }
    }

    fn updateStyles(self: *const Self) bool {
        if (self.ctx.driver.ewmh._NET_WM_STATE != 0 and
            self.ctx.driver.ewmh._NET_WM_STATE_FULLSCREEN != 0)
        {
            // NOTE: if the window isn't resizable the window manager
            // might not do anything in response to this message.
            var event = libx11.XEvent{
                .xclient = libx11.XClientMessageEvent{
                    .type = libx11.ClientMessage,
                    .display = null,
                    .window = self.handle,
                    .message_type = self.ctx.driver.ewmh._NET_WM_STATE,
                    .format = 32,
                    .serial = 0,
                    .send_event = 0,
                    .data = .{ .l = [5]c_long{
                        if (self.data.flags.is_fullscreen) _NET_WM_STATE_ADD else _NET_WM_STATE_REMOVE,
                        @intCast(self.ctx.driver.ewmh._NET_WM_STATE_FULLSCREEN),
                        0,
                        0,
                        0,
                    } },
                },
            };
            self.ctx.driver.sendXEvent(&event, self.ctx.driver.windowManagerId());
            return true;
        } else {
            return false;
        }
    }

    /// Notify and flash the taskbar.
    /// Requires window manager support.
    /// returns true on success.
    pub fn flash(self: *const Self) bool {
        if (self.ctx.driver.ewmh._NET_WM_STATE_DEMANDS_ATTENTION == 0 or
            self.ctx.driver.ewmh._NET_WM_STATE == 0)
        {
            // unsupported by the current window manager.
            return false;
        }

        var event = libx11.XEvent{
            .xclient = libx11.XClientMessageEvent{
                .type = libx11.ClientMessage,
                .display = self.ctx.driver.handles.xdisplay,
                .window = self.handle,
                .message_type = self.ctx.driver.ewmh._NET_WM_STATE,
                .format = 32,
                .serial = 0,
                .send_event = 0,
                .data = .{ .l = [5]c_long{
                    _NET_WM_STATE_ADD,
                    @intCast(self.ctx.driver.ewmh._NET_WM_STATE_DEMANDS_ATTENTION),
                    0,
                    1,
                    0,
                } },
            },
        };
        self.ctx.driver.sendXEvent(&event, self.ctx.driver.windowManagerId());
        self.ctx.driver.flushXRequests();
        return true;
    }

    pub fn focus(self: *Self) void {
        const drvr = self.ctx.driver;
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
            libx11.dyn_api.XRaiseWindow(drvr.handles.xdisplay, self.handle);
            libx11.dyn_api.XSetInputFocus(
                drvr.handles.xdisplay,
                self.handle,
                libx11.RevertToParent,
                libx11.CurrentTime,
            );
        }
        drvr.flushXRequests();
    }

    /// Returns the position of the top left corner of the client area.
    pub fn getClientPosition(self: *const Self) common.geometry.Point2D {
        return self.data.client_area.top_left;
    }

    /// Moves the client's top left corner
    /// to the specified screen coordinates.
    pub fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        const drvr = self.ctx.driver;
        _ = libx11.dyn_api.XMoveWindow(
            drvr.handles.xdisplay,
            self.handle,
            @intCast(x),
            @intCast(y),
        );
        drvr.flushXRequests();
    }

    pub fn getClientSize(self: *const Self, out: *common.window_data.WindowSize) void {
        var attribs: libx11.XWindowAttributes = undefined;
        const drvr = self.ctx.driver;
        _ = libx11.dyn_api.XGetWindowAttributes(
            drvr.handles.xdisplay,
            self.handle,
            &attribs,
        );

        var scale = @as(f64, 0);
        self.getDpi(null, null, &scale);

        out.* = .{
            .physical_width = self.data.client_area.size.width,
            .physical_height = self.data.client_area.size.height,
            .scale = scale,
            .logical_width = @intCast(attribs.width),
            .logical_height = @intCast(attribs.height),
        };
    }

    /// Sets the new (width,height) of the window's client area
    pub fn setClientSize(self: *Self, size: *common.geometry.RectSize) void {
        if (self.data.flags.is_maximized) {
            // un-maximize the window
            self.restore();
        }

        self.data.client_area.size = size.*;
        if (self.data.flags.is_dpi_aware) {
            const drvr = self.ctx.driver;
            self.data.client_area.size.scaleBy(drvr.g_screen_scale);
        }

        const drvr = self.ctx.driver;
        if (!self.data.flags.is_resizable) {
            // we need to update the maxwidth and maxheight
            // size hints.
            self.updateSizeHints();
        }

        _ = libx11.dyn_api.XResizeWindow(
            drvr.handles.xdisplay,
            self.handle,
            @intCast(size.width),
            @intCast(size.height),
        );

        drvr.flushXRequests();
    }

    pub fn setMinSize(self: *Self, min_size: ?common.geometry.RectSize) void {
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
                const drvr = self.ctx.driver;
                size.scaleBy(drvr.g_screen_scale);
            }

            self.data.min_size = size;
        } else {
            self.data.min_size = null;
        }

        self.updateSizeHints();
    }

    pub fn setMaxSize(self: *Self, max_size: ?common.geometry.RectSize) void {
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
                const drvr = self.ctx.driver;
                size.scaleBy(drvr.g_screen_scale);
            }
            self.data.max_size = size;
        } else {
            self.data.max_size = null;
        }

        self.updateSizeHints();
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
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
        const drvr = self.ctx.driver;
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

        libx11.dyn_api.XChangeProperty(
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
        const drvr = self.ctx.driver;
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
    }

    /// Minimizes the window.
    pub fn minimize(self: *Self) void {
        const drvr = self.ctx.driver;
        _ = libx11.dyn_api.XIconifyWindow(
            drvr.handles.xdisplay,
            self.handle,
            drvr.handles.default_screen,
        );
        drvr.flushXRequests();
        self.data.flags.is_minimized = true;
    }

    /// Restores the minimized or maximized window to a normal window.
    pub fn restore(self: *const Self) void {
        const drvr = self.ctx.driver;
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
        const drvr = self.ctx.driver;
        const name_atom = if (drvr.ewmh._NET_WM_NAME != 0)
            drvr.ewmh._NET_WM_NAME
        else
            drvr.ewmh._NET_WM_VISIBLE_NAME;
        const icon_atom = if (drvr.ewmh._NET_WM_ICON_NAME != 0)
            drvr.ewmh._NET_WM_ICON_NAME
        else
            drvr.ewmh._NET_WM_VISIBLE_ICON_NAME;

        libx11.dyn_api.XChangeProperty(
            drvr.handles.xdisplay,
            self.handle,
            name_atom,
            drvr.ewmh.UTF8_STRING,
            8,
            libx11.PropModeReplace,
            new_title.ptr,
            @intCast(new_title.len),
        );

        libx11.dyn_api.XChangeProperty(
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
    pub fn getTitle(
        self: *const Self,
        allocator: std.mem.Allocator,
    ) (Allocator.Error || WindowError)![]u8 {
        const drvr = self.ctx.driver;
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

        defer _ = libx11.dyn_api.XFree(data);
        const window_title = try allocator.alloc(u8, data_len);
        @memcpy(window_title, data);
        return window_title;
    }

    /// Returns the window's current opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn getOpacity(self: *const Self) f32 {
        const drvr = self.ctx.driver;
        var value: ?*libx11.CARD32 = null; // cardinal, and xid are the same bitwidth.
        const OPAQUE = @as(u32, 0xFFFFFFFF);
        _ = utils.x11WindowProperty(
            drvr.handles.xdisplay,
            self.handle,
            drvr.ewmh._NET_WM_WINDOW_OPACITY,
            libx11.XA_CARDINAL,
            @ptrCast(&value),
        ) catch return 1.0;
        if (value) |v| {
            defer _ = libx11.dyn_api.XFree(v);
            const curr_opacity: f64 = (@as(f64, @floatFromInt(v.*)) / @as(f64, @floatFromInt(OPAQUE)));
            return @floatCast(curr_opacity);
        } else {
            return 1.0;
        }
    }

    /// Sets the window's opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn setOpacity(self: *Self, value: f32) bool {
        const drvr = self.ctx.driver;
        if (drvr.ewmh._NET_WM_WINDOW_OPACITY == 0) {
            return false;
        }

        if (value == @as(f64, 1.0)) {
            // it's faster to just delete the property.
            libx11.dyn_api.XDeleteProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh._NET_WM_WINDOW_OPACITY,
            );
        } else {
            const OPAQUE = @as(u32, 0xFFFFFFFF);
            const alpha: libx11.XID = @intFromFloat(@as(f64, value) * @as(f64, @floatFromInt(OPAQUE)));
            libx11.dyn_api.XChangeProperty(
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
        const drvr = self.ctx.driver;
        var display_area: common.geometry.Rect = undefined;
        var new_window_area: *common.geometry.Rect = &display_area;

        if (self.data.flags.is_fullscreen != value) {
            const d = self.ctx.display_mgr.findWindowDisplay(self) catch return false;
            d.getFullArea(&display_area, drvr);

            if (value) {
                if (!self.data.flags.is_resizable) {
                    const size_hints = libx11.dyn_api.XAllocSizeHints();
                    if (size_hints) |hints| {
                        defer _ = libx11.dyn_api.XFree(hints);
                        var supplied: c_long = 0;
                        _ = libx11.dyn_api.XGetWMNormalHints(
                            self.ctx.driver.handles.xdisplay,
                            self.handle,
                            hints,
                            &supplied,
                        );

                        hints.flags &= ~(@as(@TypeOf(hints.flags), libx11.PMinSize) |
                            @as(@TypeOf(hints.flags), libx11.PMaxSize));

                        _ = libx11.dyn_api.XSetWMNormalHints(
                            self.ctx.driver.handles.xdisplay,
                            self.handle,
                            @ptrCast(hints),
                        );
                    } else {
                        return false;
                    }

                    self.ctx.display_mgr.setDisplayVideoMode(d, &.{
                        .width = self.data.client_area.size.width,
                        .height = self.data.client_area.size.height,
                        // INFO: These 2 are hardcoded for now
                        .frequency = 60,
                        .color_depth = 32,
                    }) catch return false;
                }

                if (drvr.extensions.xinerama.is_active and
                    drvr.ewmh._NET_WM_FULLSCREEN_MONITORS != 0)
                {
                    var event = libx11.XEvent{
                        .xclient = libx11.XClientMessageEvent{
                            .type = libx11.ClientMessage,
                            .display = self.ctx.driver.handles.xdisplay,
                            .window = self.handle,
                            .message_type = self.ctx.driver.ewmh._NET_WM_FULLSCREEN_MONITORS,
                            .format = 32,
                            .serial = 0,
                            .send_event = 0,
                            .data = .{ .l = [5]c_long{
                                d.xinerama_index,
                                d.xinerama_index,
                                d.xinerama_index,
                                d.xinerama_index,
                                0,
                            } },
                        },
                    };
                    self.ctx.driver.sendXEvent(&event, self.ctx.driver.windowManagerId());
                }

                self.x11.windowed_area = self.data.client_area;

                self.ctx.display_mgr.setScreenSaver(false);
            } else {
                self.ctx.display_mgr.setDisplayVideoMode(d, null) catch unreachable;

                if (drvr.extensions.xinerama.is_active and
                    drvr.ewmh._NET_WM_FULLSCREEN_MONITORS != 0)
                {
                    libx11.dyn_api.XDeleteProperty(
                        drvr.handles.xdisplay,
                        self.handle,
                        drvr.ewmh._NET_WM_FULLSCREEN_MONITORS,
                    );
                }

                new_window_area = &self.x11.windowed_area;
                self.ctx.display_mgr.setScreenSaver(true);
            }

            self.data.flags.is_fullscreen = value;
            self.updateSizeHints();
            if (!self.updateStyles()) {
                self.data.flags.is_fullscreen = !value;
                return false;
            }

            _ = libx11.dyn_api.XMoveResizeWindow(
                drvr.handles.xdisplay,
                self.handle,
                new_window_area.top_left.x,
                new_window_area.top_left.y,
                @intCast(new_window_area.size.width),
                @intCast(new_window_area.size.height),
            );

            drvr.flushXRequests();
        }

        return true;
    }

    pub fn setDragAndDrop(
        self: *Self,
        accepted: bool,
    ) void {
        const version: i32 = libx11.XDND_VER;
        const drvr = self.ctx.driver;

        if (accepted == self.x11.xdnd_allow) {
            return;
        }
        self.x11.xdnd_allow = accepted;

        if (accepted) {
            debug.assert(self.x11.xdnd_req.paths.capacity == 0 and self.x11.xdnd_req.paths.items.len == 0);
            libx11.dyn_api.XChangeProperty(
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
            libx11.dyn_api.XDeleteProperty(
                drvr.handles.xdisplay,
                self.handle,
                drvr.ewmh.XdndAware,
            );
            self.freeDroppedFiles();
        }
        drvr.flushXRequests();
    }

    // /// Returns a cached slice that contains the path(s) to the last dropped file(s).
    pub fn getDroppedFiles(self: *const Self) [][]const u8 {
        return self.x11.xdnd_req.paths.items;
    }

    /// Frees the allocated memory used to hold the file(s) path(s).
    pub fn freeDroppedFiles(self: *Self) void {
        if (self.x11.xdnd_req.raw_data) |rd| {
            _ = libx11.dyn_api.XFree(@constCast(rd));
        }
        if (self.x11.xdnd_req.paths.capacity != 0) {
            self.x11.xdnd_req.paths.clearAndFree(self.ctx.allocator);
        }
    }

    pub fn getCursorPosition(self: *const Self) common.geometry.Point2D {
        const drvr = self.ctx.driver;
        var root: libx11.Window = undefined;
        var child: libx11.Window = undefined;
        var root_x: c_int, var root_y: c_int = .{ undefined, undefined };
        var win_x: c_int, var win_y: c_int = .{ undefined, undefined };
        var mask: c_uint = undefined;
        _ = libx11.dyn_api.XQueryPointer(
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
        const drvr = self.ctx.driver;
        _ = libx11.dyn_api.XWarpPointer(
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
        if (!self.data.flags.cursor_in_client) {
            return;
        }

        self.x11.cursor.mode = mode;
        cursor.applyCursorHints(self.ctx.driver, &self.x11.cursor, self.handle);

        if (self.data.flags.has_raw_mouse) {
            if (mode == .Hidden) {
                self.ctx.raw_mouse_motion_window = self.handle;
            } else {
                self.ctx.raw_mouse_motion_window = null;
            }
        }
    }

    pub fn getDpi(self: *const Self, dpi_x: ?*f64, dpi_y: ?*f64, scaler: ?*f64) void {
        const drvr = self.ctx.driver;
        if (scaler) |s| s.* = drvr.g_screen_scale;
        if (dpi_x) |x| x.* = drvr.g_dpi;
        if (dpi_y) |y| y.* = drvr.g_dpi;
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
                self.ctx.driver,
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
        cursor.destroyCursorIcon(self.ctx.driver.handles.xdisplay, &self.x11.cursor);
        self.x11.cursor.icon = new_cursor;
        if (self.data.flags.cursor_in_client) {
            cursor.applyCursorHints(self.ctx.driver, &self.x11.cursor, self.handle);
        }
    }

    pub fn setNativeCursorIcon(
        self: *Self,
        cursor_shape: common.cursor.NativeCursorShape,
    ) void {
        const new_cursor = cursor.createNativeCursor(self.ctx.driver, cursor_shape);
        cursor.destroyCursorIcon(self.ctx.driver.handles.xdisplay, &self.x11.cursor);
        self.x11.cursor.icon = new_cursor.icon;
        self.x11.cursor.mode = new_cursor.mode;
        if (self.data.flags.cursor_in_client) {
            cursor.applyCursorHints(self.ctx.driver, &self.x11.cursor, self.handle);
        }
    }

    pub fn setIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        allocator: std.mem.Allocator,
    ) WindowError!void {
        const drvr = self.ctx.driver;
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
            libx11.dyn_api.XChangeProperty(
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
            libx11.dyn_api.XDeleteProperty(
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
        const drvr = self.ctx.driver;
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
            defer _ = libx11.dyn_api.XFree(@ptrCast(ex));
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
        const drvr = self.ctx.driver;
        if (!drvr.extensions.xi2.is_v2point0) {
            return false;
        }

        var success = true;
        if (self.data.flags.has_raw_mouse != active) {
            self.data.flags.has_raw_mouse = active;
            if (active) {
                success = enableRawMouseMotion(self.ctx.driver);
                self.ctx.raw_mouse_motion_window = self.handle;
            } else {
                success = disableRawMouseMotion(self.ctx.driver);
                self.ctx.raw_mouse_motion_window = null;
            }
            self.setCursorMode(self.x11.cursor.mode);
        }

        return success;
    }

    // pub fn getGLContext(self: *const Self) WindowError!glx.GLContext {
    //     switch (self.fb_cfg.accel) {
    //         .opengl => return glx.GLContext.init(self.ctx.driver, self.handle, &self.fb_cfg) catch {
    //             return WindowError.GLError;
    //         },
    //         else => return WindowError.UnsupportedRenderBackend,
    //     }
    // }

    pub fn createCanvas(self: *Self) WindowError!common.fb.Canvas {
        // TODO: Implement
        // switch (self.fb_cfg.accel) {
        //     .software => {
        //         if (@as(Win32CanvasTag, self.canvas) == .invalid) {
        //             self.canvas = .{ .blt_ctx = try BlitContext.init(self) };
        //         }
        //         const c = common.fb.Canvas{
        //             .ctx = @ptrCast(&self.canvas),
        //             ._vtable = .{
        //                 .swapBuffers = swSwapBuffers,
        //                 .setSwapInterval = swSetSwapInterval,
        //                 .getSoftwareBuffer = swGetSoftwareBuffer,
        //                 .updateSoftwareBuffer = swUpdateSoftwareBuffer,
        //                 .getDriverInfo = swGetDriverInfo,
        //                 .deinit = swDestroyCanvas,
        //             },
        //             .fb_format_info = self.canvas.blt_ctx.px_fmt_info,
        //             .render_backend = .software,
        //         };
        //         return c;
        //     },
        //     .opengl => {
        //         if (@as(Win32CanvasTag, self.canvas) == .invalid) {
        //             self.canvas = .{
        //                 .gl_ctx = wgl.GLContext.init(
        //                     self.win32.dc,
        //                     self.ctx.driver,
        //                     &self.fb_cfg,
        //                 ) catch
        //                     return WindowError.CanvasImpossible,
        //             };
        //         }
        //         const c = common.fb.Canvas{
        //             .ctx = @ptrCast(&self.canvas),
        //             ._vtable = .{
        //                 .swapBuffers = wgl.glSwapBuffers,
        //                 .makeCurrent = wgl.glMakeCurrent,
        //                 .setSwapInterval = wgl.glSetSwapInterval,
        //                 .getDriverInfo = wgl.glGetDriverInfo,
        //                 .deinit = wgl.glDestroyCanvas,
        //             },
        //             .fb_format_info = self.canvas.gl_ctx.px_fmt_info,
        //             .render_backend = .opengl,
        //         };
        //         return c;
        //     },
        // }
    }

    // pub fn createCanvas(self: *Self) WindowError!DrawContext {
    //     switch (self.fb_cfg.accel) {
    //         .none => {
    //             var gcv: libx11.XGCValues = undefined;
    //             var vinfo: libx11.XVisualInfo = undefined;

    //             gcv.graphics_exposures = libx11.False;
    //             self.x11.gc = libx11.dyn_api.XCreateGC(
    //                 self.ctx.driver.handles.xdisplay,
    //                 self.handle,
    //                 libx11.GCGraphicsExposures,
    //                 &gcv,
    //             );
    //             if (self.x11.gc == null) {
    //                 @panic("TODO fail path can't create graphics context");
    //             }

    //             if (libx11.dyn_api.XGetVisualInfoFromVisual(
    //                 self.ctx.driver.handles.xdisplay,
    //                 self.x11.visual,
    //                 &vinfo,
    //             ) < 0) {
    //                 @panic("TODO fail path cant get visual info");
    //             }
    //             var cl_sz: common.window_data.WindowSize = undefined;
    //             self.getClientSize(&cl_sz);
    //             const BYTES_PER_PIXEL = 4; // TODO: Grab this from the visuals
    //             const stride: u32 = @as(u32, @intCast(cl_sz.physical_width)) * BYTES_PER_PIXEL;
    //             const stride_padded = (stride + 3) & ~3;
    //             const pixels = try self.ctx.allocator.alloc(
    //                 u8,
    //                 @as(u32, @intCast(cl_sz.physical_height)) * stride_padded,
    //             );
    //             self.x11.ximage = libx11.dyn_api.XCreateImage(
    //                 self.ctx.driver.handles.xdisplay,
    //                 self.x11.visual,
    //                 vinfo.depth,
    //                 libx11.ZPixmap,
    //                 0,
    //                 pixels.ptr,
    //                 @intCast(cl_sz.physical_width),
    //                 @intCast(cl_sz.physical_height),
    //                 32,
    //                 0,
    //             );

    //             if (self.x11.ximage == null) {
    //                 @panic("TODO fail path cant create ximage");
    //             }
    //             self.x11.ximage.?.byte_order = libx11.LSBFirst;
    //         },
    //         .opengl => return glx.GLContext.init(self.ctx.driver, self.handle, &self.fb_cfg) catch {
    //             return WindowError.GLError;
    //         },
    //     }
    // }

    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (common.IS_DEBUG_BUILD) {
            std.debug.print("0==========================0\n", .{});
            if (size) {
                std.debug.print("\nWindow #{}\n", .{self.data.id});
                var cl_sz: common.window_data.WindowSize = undefined;
                self.getClientSize(&cl_sz);
                std.debug.print(
                    "physical client Size (w:{},h:{}) | logical client size (w:{},h:{})\n",
                    .{
                        cl_sz.physical_width,
                        cl_sz.physical_height,
                        cl_sz.logical_width,
                        cl_sz.logical_height,
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
    driver: *const X11Driver,
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
    attribs.colormap = libx11.dyn_api.XCreateColormap(
        driver.handles.xdisplay,
        driver.windowManagerId(),
        visual,
        libx11.AllocNone,
    );

    var window_size = data.client_area.size;
    if (data.flags.is_dpi_aware) {
        window_size.scaleBy(driver.g_screen_scale);
    }

    const handle = libx11.dyn_api.XCreateWindow(
        driver.handles.xdisplay,
        driver.windowManagerId(),
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

    return handle;
}

fn setInitialWindowPropeties(
    driver: *const X11Driver,
    window: libx11.Window,
    data: *const WindowData,
) WindowError!void {
    // communication protocols

    var protocols = [_]libx11.Atom{
        // this allows us to receive close request from the window manager.
        // instead of it closing the socket and crashing our app
        driver.ewmh.WM_DELETE_WINDOW,
        // this allows the window manager to check if a window is still alive and responding
        driver.ewmh._NET_WM_PING,
    };

    _ = libx11.dyn_api.XSetWMProtocols(
        driver.handles.xdisplay,
        window,
        &protocols,
        protocols.len,
    );

    libx11.dyn_api.XChangeProperty(
        driver.handles.xdisplay,
        window,
        driver.ewmh._NET_WM_PID,
        libx11.XA_CARDINAL,
        32,
        libx11.PropModeReplace,
        @ptrCast(&driver.pid),
        1,
    );

    // if supported declare window type.
    if (driver.ewmh._NET_WM_WINDOW_TYPE != 0 and
        driver.ewmh._NET_WM_WINDOW_TYPE_NORMAL != 0)
    {
        libx11.dyn_api.XChangeProperty(
            driver.handles.xdisplay,
            window,
            driver.ewmh._NET_WM_WINDOW_TYPE,
            libx11.XA_ATOM,
            32,
            libx11.PropModeReplace,
            @ptrCast(&driver.ewmh._NET_WM_WINDOW_TYPE_NORMAL),
            1,
        );
    }

    // WMHints.
    var hints = libx11.dyn_api.XAllocWMHints() orelse return WindowError.CreateFail;
    defer _ = libx11.dyn_api.XFree(hints);
    hints.flags = libx11.StateHint;
    hints.initial_state = libx11.NormalState;
    _ = libx11.dyn_api.XSetWMHints(driver.handles.xdisplay, window, @ptrCast(hints));

    // resizablitity
    var size_hints = libx11.dyn_api.XAllocSizeHints() orelse
        return WindowError.CreateFail;

    defer _ = libx11.dyn_api.XFree(size_hints);
    size_hints.flags |= libx11.PWinGravity;
    size_hints.win_gravity = libx11.StaticGravity;

    var window_size = data.client_area.size;
    if (data.flags.is_dpi_aware) {
        window_size.scaleBy(driver.g_screen_scale);
    }

    if (!data.flags.is_resizable) {
        size_hints.flags |= (libx11.PMinSize | libx11.PMaxSize);
        size_hints.max_width = window_size.width;
        size_hints.min_width = window_size.width;
        size_hints.max_height = window_size.height;
        size_hints.min_height = window_size.height;
    }

    if (data.client_area.top_left.x != Window.WINDOW_DEFAULT_POSITION.x and
        data.client_area.top_left.y != Window.WINDOW_DEFAULT_POSITION.y)
    {
        size_hints.x = data.client_area.top_left.x;
        size_hints.y = data.client_area.top_left.y;
        size_hints.flags |= libx11.PPosition;
    }

    _ = libx11.dyn_api.XSetWMNormalHints(
        driver.handles.xdisplay,
        window,
        @ptrCast(size_hints),
    );

    // WMClassHints
    var class_hints = libx11.dyn_api.XAllocClassHint() orelse
        return WindowError.CreateFail;
    defer _ = libx11.dyn_api.XFree(class_hints);
    class_hints.res_name = bopts.X11_RES_NAME.ptr;
    class_hints.res_class = bopts.X11_CLASS_NAME.ptr;

    _ = libx11.dyn_api.XSetClassHint(
        driver.handles.xdisplay,
        window,
        @ptrCast(class_hints),
    );
}

pub fn windowFromId(driver: *const X11Driver, window_id: libx11.Window) ?*Window {
    const window = driver.findInXContext(window_id);
    return @ptrCast(@alignCast(window));
}

pub inline fn enableRawMouseMotion(driver: *const X11Driver) bool {
    const MASK_LEN = comptime x11ext.xi2.XIMaskLen(x11ext.xi2.XI_RawMotion);
    var mask: [MASK_LEN]u8 = [1]u8{0} ** MASK_LEN;
    var ev_mask = x11ext.xi2.XIEventMask{
        .deviceid = x11ext.xi2.XIAllMasterDevices,
        .mask_len = MASK_LEN,
        .mask = &mask,
    };
    x11ext.xi2.XISetMask(&mask, x11ext.xi2.XI_RawMotion);
    return driver.extensions.xi2.XISelectEvents(
        driver.handles.xdisplay,
        driver.windowManagerId(),
        @ptrCast(&ev_mask),
        1,
    ) == libx11.Success;
}

pub inline fn disableRawMouseMotion(driver: *const X11Driver) bool {
    const MASK_LEN = 1;
    var mask: [MASK_LEN]u8 = [1]u8{0} ** MASK_LEN;
    var ev_mask = x11ext.xi2.XIEventMask{
        .deviceid = x11ext.xi2.XIAllMasterDevices,
        .mask_len = MASK_LEN,
        .mask = &mask,
    };
    x11ext.xi2.XISetMask(&mask, x11ext.xi2.XI_RawMotion);
    return driver.extensions.xi2.XISelectEvents(
        driver.handles.xdisplay,
        driver.windowManagerId(),
        @ptrCast(&ev_mask),
        1,
    ) == libx11.Success;
}

fn waitOnX11Socket(display: *libx11.Display, timeout: i64) bool {
    const timeout_ns = timeout * std.time.ns_per_ms;
    var ready: u32 = 0;
    // start by flushing and checking for available events.
    while (libx11.dyn_api.XPending(display) == 0) {
        if (unix.poll.poll(
            libx11.ConnectionNumber(display),
            unix.poll.PollFlag.IORead,
            timeout_ns,
            &ready,
        ) == false) {
            // timeout or error
            return false;
        }
    }
    return true;
}

inline fn isNextEventType(display: *libx11.Display, window_id: libx11.Window, event_type: c_int) bool {
    var e: libx11.XEvent = undefined;
    return libx11.dyn_api.XCheckTypedWindowEvent(display, window_id, event_type, &e) == libx11.True;
}

fn waitForWindowVisibility(display: *libx11.Display, window_id: libx11.Window) bool {
    while (!isNextEventType(display, window_id, libx11.VisibilityNotify)) {
        if (!waitOnX11Socket(display, 250)) {
            return false;
        }
    }
    return true;
}
