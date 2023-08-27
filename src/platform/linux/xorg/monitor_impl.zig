const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const libx11ext = @import("x11/extensions.zig");
const common = @import("common");
const utils = @import("utils.zig");
const X11Context = @import("global.zig").X11Context;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const VideoMode = common.video_mode.VideoMode;
const WindowImpl = @import("window_impl.zig").WindowImpl;

/// Construct a Vector with all currently connected monitors.
pub fn pollMonitors(allocator: Allocator) !ArrayList(MonitorImpl) {
    var monitors = ArrayList(MonitorImpl).init(allocator);
    errdefer monitors.deinit();
    const x11cntxt = X11Context.singleton();
    if (x11cntxt.handles.xrandr != null) {
        const screens_res = if (x11cntxt.extensions.xrandr.is_v1point3)
            x11cntxt.extensions.xrandr.XRRGetScreenResourcesCurrent(
                x11cntxt.handles.xdisplay,
                x11cntxt.handles.root_window,
            )
        else
            x11cntxt.extensions.xrandr.XRRGetScreenResources(
                x11cntxt.handles.xdisplay,
                x11cntxt.handles.root_window,
            );

        try monitors.ensureTotalCapacity(@intCast(screens_res.ncrtc));
        var screens: ?[*]libx11ext.XineramaScreenInfo = null;
        var n_screens: i32 = 0;
        if (x11cntxt.extensions.xinerama.is_active) {
            screens = x11cntxt.extensions.xinerama.QueryScreens(x11cntxt.handles.xdisplay, &n_screens);
        }
        for (0..@intCast(screens_res.noutput)) |i| {
            const output_info = x11cntxt.extensions.xrandr.XRRGetOutputInfo(
                x11cntxt.handles.xdisplay,
                screens_res,
                screens_res.outputs[i],
            );
            if (output_info.connection != libx11ext.RR_Connected or output_info.crtc == libx11ext.RRCrtc_None) {
                x11cntxt.extensions.xrandr.XRRFreeOutputInfo(output_info);
                continue;
            }
            std.debug.assert(output_info.crtc == screens_res.crtcs[i]);
            const crtc_info = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(
                x11cntxt.handles.xdisplay,
                screens_res,
                output_info.crtc,
            );
            var xinerama_index: ?i32 = null;
            if (screens) |scrns| {
                for (0..@intCast(n_screens)) |j| {
                    if (scrns[j].x_org == crtc_info.x and
                        scrns[j].y_org == crtc_info.y and
                        scrns[j].width == crtc_info.width and
                        scrns[j].height == crtc_info.height)
                    {
                        xinerama_index = @intCast(j);
                        break;
                    }
                }
            }
            // Copy the monitor name.
            const name_len = std.mem.len(output_info.name);
            var name = try allocator.alloc(u8, name_len);
            errdefer allocator.free(name);
            utils.strCpy(output_info.name, name.ptr, name_len);
            const monitor = MonitorImpl{
                .handle = output_info.crtc,
                .name = name,
                .randr_output = screens_res.outputs[i],
                .xinerama_index = xinerama_index,
                .current_mode = null,
                .window = null,
                .modes = ArrayList(common.video_mode.VideoMode).init(allocator),
            };

            try monitors.append(monitor);
            x11cntxt.extensions.xrandr.XRRFreeOutputInfo(output_info);
            x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(crtc_info);
        }
        x11cntxt.extensions.xrandr.XRRFreeScreenResources(screens_res);
        if (screens) |scrns| {
            _ = libx11.XFree(scrns);
        }
    }
    return monitors;
}
//fn pollVideoModes(modes_arry:*ArrayList(VideoMode),n_modes:i32,modes:*libx11ext.RRMode) !void {
//     const x11cntxt = X11Context.singleton();
//     for(0..@intCast(n_modes))|i|{
//         x11cntxt.extensions.xrandr.
//     }
// }

/// Encapsulate the necessary infos for a monitor.
pub const MonitorImpl = struct {
    handle: libx11ext.RRCrtc,
    name: []u8,
    randr_output: libx11ext.RROutput,
    xinerama_index: ?i32,
    modes: ArrayList(common.video_mode.VideoMode), // All the VideoModes that the monitor support.
    current_mode: ?VideoMode, // Keeps track of any mode changes we made.
    window: ?*WindowImpl, // A pointer to the window occupying(fullscreen) the monitor.

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.modes.allocator.free(self.name);
        self.modes.deinit();
    }
};

test "poll_monitors" {
    try X11Context.initSingleton();
    defer X11Context.deinitSingleton();
    const mons = try pollMonitors(std.testing.allocator);
    defer mons.deinit();
}
