const std = @import("std");
const common = @import("common");
const WindowData = common.window_data.WindowData;
const X11Context = @import("global.zig").X11Context;
const libX11 = @import("x11/xlib.zig");
/// Holds all the refrences we use to communitcate with the WidowContext.
pub const WidowProps = struct {
    events_queue: *common.event.EventQueue,
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
        _ = window_title;
        _ = allocator;
        _ = instance;
    }
};

fn createPlatformWindow(
    title: []const u8,
    data: *const WindowData,
) !libX11.Window {
    _ = title;

    const x11cntxt = X11Context.singleton();
    const handle = libX11.XCreateWindow(
        x11cntxt.handles.xdisplay,
        x11cntxt.handles.root_window,
        data.x,
        data.y,
        data.w,
        data.h,
        0,
        0,
        null,
        0,
        null,
    );

    return handle;
}
