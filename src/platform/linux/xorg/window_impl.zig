const std = @import("std");
const common = @import("common");
const libX11 = @import("x11/xlib.zig");
const MonitorStore = @import("internals.zig").MonitorStore;
const WindowData = common.window_data.WindowData;
const X11Context = @import("global.zig").X11Context;

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

    pub fn setup(
        instance: *Self,
        allocator: std.mem.Allocator,
        window_title: []const u8,
    ) !void {
        instance.handle = try createPlatformWindow(window_title, &instance.data);
        if (instance.data.flags.is_visible) {
            instance.show();
            if (instance.data.flags.is_focused) {
                // instance.focus();
            }
        }
        _ = allocator;
    }

    // Destroy the window
    pub fn close(self: *Self) void {
        std.debug.assert(self.handle != 0);
        const x11cntxt = X11Context.singleton();

        _ = libX11.XUnmapWindow(x11cntxt.handles.xdisplay, self.handle);
        _ = libX11.XDestroyWindow(x11cntxt.handles.xdisplay, self.handle);
        self.handle = 0;
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
};

fn createPlatformWindow(
    title: []const u8,
    data: *const WindowData,
) !libX11.Window {
    const EVENT_MASK = libX11.KeyReleaseMask | libX11.KeyPressMask | libX11.ButtonPressMask |
        libX11.ButtonReleaseMask | libX11.EnterWindowMask | libX11.LeaveWindowMask |
        libX11.FocusChangeMask | libX11.VisibilityChangeMask | libX11.PointerMotionMask |
        libX11.StructureNotifyMask | libX11.PropertyChangeMask | libX11.ExposureMask;

    _ = title;
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
        return error.WindowCreationFailure;
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
    std.time.sleep(std.time.ns_per_s * 3);
    // window.close();
    // X11Context.deinitSingleton();
}
