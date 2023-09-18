const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions.zig");
const common = @import("common");
const utils = @import("utils.zig");
const X11Context = @import("global.zig").X11Context;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const VideoMode = common.video_mode.VideoMode;
const WindowImpl = @import("window_impl.zig").WindowImpl;

pub const MonitorHandle = x11ext.RRCrtc;

fn calculateMonitorFrequency(mode_info: *const x11ext.XRRModeInfo) u16 {
    if (mode_info.dotClock == 0 or mode_info.hTotal == 0 or mode_info.vTotal == 0) {
        return 0;
    } else {
        const num: f64 = @floatFromInt(mode_info.dotClock);
        const deno: f64 = @floatFromInt(mode_info.hTotal * mode_info.vTotal);
        return @intFromFloat(@round(num / deno));
    }
}

fn pollVideoModes(
    allocator: std.mem.Allocator,
    screens_res: *x11ext.XRRScreenResources,
    output_info: *x11ext.XRROutputInfo,
    rotated: bool,
) !ArrayList(VideoMode) {
    const x11cntxt = X11Context.singleton();
    const default_depth: u8 = @intCast(libx11.DefaultDepth(
        x11cntxt.handles.xdisplay,
        x11cntxt.handles.default_screen,
    ));

    const n_modes: usize = @intCast(output_info.nmode);
    var modes_arry = try ArrayList(VideoMode).initCapacity(allocator, n_modes);
    errdefer modes_arry.deinit();
    for (0..n_modes) |i| {
        var modes_info: ?*x11ext.XRRModeInfo = null;
        for (0..@intCast(screens_res.nmode)) |j| {
            if (screens_res.modes[j].id == output_info.modes[i]) {
                modes_info = &screens_res.modes[j];
                break;
            }
        }
        if (modes_info) |info| {
            if (info.modeFlags & x11ext.RR_Interlace != 0) {
                continue;
            }

            var width: i32 = undefined;
            var height: i32 = undefined;
            if (rotated) {
                width = @intCast(info.height);
                height = @intCast(info.width);
            } else {
                width = @intCast(info.width);
                height = @intCast(info.height);
            }

            const videomode = common.video_mode.VideoMode.init(
                width,
                height,
                calculateMonitorFrequency(info),
                default_depth,
            );
            // skip duplicate modes
            var duplicate = false;
            for (modes_arry.items) |*mode| {
                if (videomode.equals(mode)) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) {
                continue;
            }
            try modes_arry.append(videomode);
        } else {
            continue;
        }
    }
    return modes_arry;
}

/// Construct a Vector with all currently connected monitors.
pub fn pollMonitors(allocator: Allocator) !ArrayList(MonitorImpl) {
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

        var monitors = try ArrayList(MonitorImpl).initCapacity(allocator, @intCast(screens_res.ncrtc));
        errdefer {
            for (monitors.items) |*monitor| {
                monitor.deinit();
            }
            monitors.deinit();
        }

        var screens: ?[*]x11ext.XineramaScreenInfo = null;
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
            if (output_info.connection != x11ext.RR_Connected or output_info.crtc == x11ext.RRCrtc_None) {
                x11cntxt.extensions.xrandr.XRRFreeOutputInfo(output_info);
                continue;
            }
            std.debug.assert(output_info.crtc == screens_res.crtcs[i]);
            const crtc_info = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(
                x11cntxt.handles.xdisplay,
                screens_res,
                output_info.crtc,
            );

            // Figure out the xinerama index.
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
            const name_len = utils.strLen(output_info.name);
            var name = try allocator.alloc(u8, name_len);
            utils.strCpy(output_info.name, name.ptr, name_len);

            var monitor = MonitorImpl{
                .handle = output_info.crtc,
                .name = name,
                .randr_output = screens_res.outputs[i],
                .xinerama_index = xinerama_index,
                .current_mode = null,
                .window = null,
                .modes = try pollVideoModes(
                    allocator,
                    screens_res,
                    output_info,
                    (crtc_info.rotation == x11ext.RR_Rotate_90 or crtc_info.rotation == x11ext.RR_Rotate_270),
                ),
            };
            errdefer monitor.deinit();

            try monitors.append(monitor);
            x11cntxt.extensions.xrandr.XRRFreeOutputInfo(output_info);
            x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(crtc_info);
        }
        x11cntxt.extensions.xrandr.XRRFreeScreenResources(screens_res);
        if (screens) |scrns| {
            _ = libx11.XFree(scrns);
        }

        return monitors;
    }
    // TODO: handle error.
    return error.RandrNotFound;
}

/// Encapsulate the necessary infos for a monitor.
pub const MonitorImpl = struct {
    handle: MonitorHandle,
    name: []u8,
    randr_output: x11ext.RROutput,
    xinerama_index: ?i32,
    modes: ArrayList(common.video_mode.VideoMode), // All the VideoModes that the monitor support.
    current_mode: ?VideoMode, // Keeps track of any mode changes we made.
    window: ?*WindowImpl, // A pointer to the window occupying(fullscreen) the monitor.

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.modes.allocator.free(self.name);
        self.modes.deinit();
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        self.handle = other.handle;
    }
};

test "poll_monitors" {
    try X11Context.initSingleton();
    defer X11Context.deinitSingleton();
    const mons = try pollMonitors(std.testing.allocator);
    defer {
        for (mons.items) |*mon| {
            mon.deinit();
        }
        mons.deinit();
    }

    for (mons.items) |mon| {
        std.debug.print("\nMonitor:{s}\n", .{mon.name});
        std.debug.print("\nhandle:{d}\n", .{mon.handle});
        std.debug.print("\noutput:{d}\n", .{mon.randr_output});
        std.debug.print("\nindex:{?}\n", .{mon.xinerama_index});
        std.debug.print("\nVideoModes:\n", .{});
        for (mon.modes.items) |mode| {
            std.debug.print("\n[+] Mode {any}\n", .{mode});
        }
    }
}
