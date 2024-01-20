const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions.zig");
const common = @import("common");
const utils = @import("utils.zig");
const dbg = @import("builtin").mode == .Debug;
const X11Context = @import("global.zig").X11Context;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const VideoMode = common.video_mode.VideoMode;
const WindowImpl = @import("window_impl.zig").WindowImpl;

pub const MonitorError = error{
    ModeChangeFailed,
};

/// Calculates and return the monitor frequency
/// from the video mode infos
/// Note:
/// if the a frequency value can't be calcluated it returns 0;
inline fn calculateMonitorFrequency(mode_info: *const x11ext.XRRModeInfo) u16 {
    // If the dot clock is zero, then all of the timing
    // parameters and flags are not used,
    if (mode_info.dotClock == 0) {
        // Unknown refresh rate.
        return 0;
    } else {
        const num: f64 = @floatFromInt(mode_info.dotClock);
        const deno: f64 = @floatFromInt(mode_info.hTotal * mode_info.vTotal);
        return @intFromFloat(@round(num / deno));
    }
}

/// Fills the output parameters from the video mode info
fn videoModeFromRRMode(mode: *const x11ext.XRRModeInfo, rotated: bool, output: *VideoMode) bool {
    if (mode.modeFlags & x11ext.RR_Interlace != 0) {
        return false;
    }
    const x11cntxt = X11Context.singleton();
    if (rotated) {
        output.width = @intCast(mode.height);
        output.height = @intCast(mode.width);
    } else {
        output.width = @intCast(mode.width);
        output.height = @intCast(mode.height);
    }
    output.frequency = calculateMonitorFrequency(mode);
    // TODO: what if the returned frequency is 0.
    std.debug.assert(output.frequency != 0);
    output.color_depth = @intCast(libx11.DefaultDepth(
        x11cntxt.handles.xdisplay,
        x11cntxt.handles.default_screen,
    ));
    return true;
}

/// Fills the `modes_arry` and `ids_arry` with all possible video modes for the specified `output`
fn pollVideoModes(
    screens_res: *x11ext.XRRScreenResources,
    output_info: *x11ext.XRROutputInfo,
    rotated: bool,
    modes_arry: *ArrayList(VideoMode),
    ids_arry: *ArrayList(x11ext.RRMode),
) Allocator.Error!void {
    const n_modes: usize = @intCast(output_info.nmode);
    try modes_arry.ensureTotalCapacity(n_modes);
    try ids_arry.ensureTotalCapacity(n_modes);
    errdefer modes_arry.deinit();
    errdefer ids_arry.deinit();

    var videomode: VideoMode = undefined;
    for (0..n_modes) |i| {
        var modes_info: ?*x11ext.XRRModeInfo = null;
        // Find the mode infos.
        for (0..@intCast(screens_res.nmode)) |j| {
            if (screens_res.modes[j].id == output_info.modes[i]) {
                modes_info = &screens_res.modes[j];
                break;
            }
        }

        if (modes_info) |info| {
            if (!videoModeFromRRMode(info, rotated, &videomode)) {
                continue;
            }
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
            // This help us when changing crtc(video device)'s video modes.
            try ids_arry.append(info.id);
        } else {
            continue;
        }
    }
    modes_arry.shrinkAndFree(modes_arry.items.len);
    ids_arry.shrinkAndFree(ids_arry.items.len);
}

/// Querys the x server for the current connected screens.
fn getScreenRessources() *x11ext.XRRScreenResources {
    const x11cntxt = X11Context.singleton();
    return if (x11cntxt.extensions.xrandr.is_v1point3)
        // Faster than XRRGetScreenResources.
        x11cntxt.extensions.xrandr.XRRGetScreenResourcesCurrent(
            x11cntxt.handles.xdisplay,
            x11cntxt.handles.root_window,
        )
    else
        // This request explicitly asks the server to ensure that the
        // configuration data is up-to-date
        x11cntxt.extensions.xrandr.XRRGetScreenResources(
            x11cntxt.handles.xdisplay,
            x11cntxt.handles.root_window,
        );
}

/// Construct a Vector with all currently connected monitors.
pub fn pollMonitors(allocator: Allocator) Allocator.Error!ArrayList(MonitorImpl) {
    const screens_res = getScreenRessources();
    const x11cntxt = X11Context.singleton();
    // the number of crtcs match the number of video devices(GPUs) which matches the number
    // of possible monitors.
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

    // the number of outputs matches the number of available video ports(HDMI,VGA,...etc)
    for (0..@intCast(screens_res.noutput)) |i| {
        const output_info = x11cntxt.extensions.xrandr.XRRGetOutputInfo(
            x11cntxt.handles.xdisplay,
            screens_res,
            screens_res.outputs[i],
        );
        if (output_info.connection != x11ext.RR_Connected or output_info.crtc == x11ext.RRCrtc_None) {
            // Skip if the output isn't connected or isn't drawing from any video buffer(crtc);
            x11cntxt.extensions.xrandr.XRRFreeOutputInfo(output_info);
            continue;
        }

        // Grab the video buffer infos.
        const crtc_info = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(
            x11cntxt.handles.xdisplay,
            screens_res,
            output_info.crtc,
        );

        // Figure out the xinerama index
        // in a multi-monitor setup.
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
            .adapter = output_info.crtc,
            .name = name,
            .output = screens_res.outputs[i],
            .xinerama_index = xinerama_index,
            .orig_mode = x11ext.RRMode_None,
            .window = null,
            .modes = ArrayList(VideoMode).init(allocator),
            .modes_ids = ArrayList(x11ext.RRMode).init(allocator),
        };

        try pollVideoModes(
            screens_res,
            output_info,
            (crtc_info.rotation == x11ext.RR_Rotate_90 or crtc_info.rotation == x11ext.RR_Rotate_270),
            &monitor.modes,
            &monitor.modes_ids,
        );
        errdefer monitor.deinit();

        try monitors.append(monitor);
        x11cntxt.extensions.xrandr.XRRFreeOutputInfo(output_info);
        x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(crtc_info);
    }
    x11cntxt.extensions.xrandr.XRRFreeScreenResources(screens_res);
    if (screens) |scrns| {
        _ = libx11.XFree(scrns);
    }
    // Shrink and free.
    monitors.shrinkAndFree(monitors.items.len);
    return monitors;
}

/// Encapsulate the necessary infos for a monitor.
pub const MonitorImpl = struct {
    adapter: x11ext.RRCrtc,
    name: []u8,
    output: x11ext.RROutput,
    xinerama_index: ?i32,
    modes: ArrayList(common.video_mode.VideoMode), // All the VideoModes that the monitor support.
    modes_ids: ArrayList(x11ext.RRMode),
    orig_mode: x11ext.RRMode, // Keeps track of any mode changes we made.
    window: ?*WindowImpl, // A pointer to the window occupying(fullscreen) the monitor.

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.restoreOrignalVideo();
        self.modes.allocator.free(self.name);
        self.modes.deinit();
        self.modes_ids.deinit();
    }

    /// Check of if the 2 monitors are equals.
    pub fn equals(self: *const Self, other: *const Self) bool {
        self.adapter = other.adapter;
    }

    /// Populate the output with the current VideoMode of the monitor.
    pub fn queryCurrentMode(self: *const Self, output: *VideoMode) void {
        const x11cntxt = X11Context.singleton();
        const res = getScreenRessources();
        defer x11cntxt.extensions.xrandr.XRRFreeScreenResources(res);
        const ci = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(x11cntxt.handles.xdisplay, res, self.adapter);
        defer x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(ci);

        var mode_info: ?*x11ext.XRRModeInfo = null;
        // Find the mode infos.
        for (0..@intCast(res.nmode)) |j| {
            if (res.modes[j].id == ci.mode) {
                mode_info = &res.modes[j];
                break;
            }
        }
        if (mode_info) |mi| {
            _ = videoModeFromRRMode(
                mi,
                (ci.rotation == x11ext.RR_Rotate_90 or ci.rotation == x11ext.RR_Rotate_270),
                output,
            );
        }
    }

    /// Populate the `area` with the monitor's full area.
    pub inline fn monitorFullArea(self: *const Self, area: *common.geometry.WidowArea) void {
        const x11cntxt = X11Context.singleton();
        const sr = getScreenRessources();
        defer x11cntxt.extensions.xrandr.XRRFreeScreenResources(sr);
        const ci = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(x11cntxt.handles.xdisplay, sr, self.adapter);
        defer x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(ci);
        area.top_left.x = ci.x;
        area.top_left.y = ci.y;
        area.size.width = @intCast(ci.width);
        area.size.height = @intCast(ci.height);
    }

    /// Determines if the desired VideoMode `mode` is possible with
    /// the current display.
    inline fn isModePossible(self: *const Self, mode: *const VideoMode, index: *usize) bool {
        for (0..self.modes.items.len) |i| {
            if (self.modes.items[i].equals(mode)) {
                index.* = i;
                return true;
            }
        }
        return false;
    }

    /// Sets the monitor fullscreen video mode to the desired `mode`,
    /// or a mode close to it in case of the display not being compatible
    /// with the requested `mode`.
    /// # Note
    /// if `mode` is null the monitor's original video mode is restored.
    pub fn setVideoMode(self: *Self, video_mode: ?*const VideoMode) MonitorError!void {
        // TODO: the self.modes and self.modes_ids should be updated whenever
        // a change to the hardware happens.
        if (video_mode) |mode| {
            var mode_index: usize = undefined;
            if (self.isModePossible(mode, &mode_index) == false) {
                mode_index = mode.selectBestMatch(self.modes.items);
            }
            var current_mode: VideoMode = undefined;
            self.queryCurrentMode(&current_mode);
            if (self.modes.items[mode_index].equals(&current_mode)) {
                // The desired mode is already current.
                return;
            }
            const x11cntxt = X11Context.singleton();
            const sr = getScreenRessources();
            defer x11cntxt.extensions.xrandr.XRRFreeScreenResources(sr);
            const ci = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(
                x11cntxt.handles.xdisplay,
                sr,
                self.adapter,
            );
            defer x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(ci);

            if (self.orig_mode == x11ext.RRMode_None) {
                self.orig_mode = ci.mode;
            }

            const result = x11cntxt.extensions.xrandr.XRRSetCrtcConfig(
                x11cntxt.handles.xdisplay,
                sr,
                self.adapter,
                libx11.CurrentTime,
                ci.x,
                ci.y,
                self.modes_ids.items[mode_index],
                ci.rotation,
                ci.outputs,
                ci.noutput,
            );
            if (result != x11ext.RRSetConfigSuccess) {
                return MonitorError.ModeChangeFailed;
            }
        } else {
            self.restoreOrignalVideo();
        }
    }

    /// Restores the original video mode.
    fn restoreOrignalVideo(self: *Self) void {
        if (self.orig_mode == x11ext.RRMode_None) {
            return;
        }
        const x11cntxt = X11Context.singleton();
        const sr = getScreenRessources();
        defer x11cntxt.extensions.xrandr.XRRFreeScreenResources(sr);
        const ci = x11cntxt.extensions.xrandr.XRRGetCrtcInfo(
            x11cntxt.handles.xdisplay,
            sr,
            self.adapter,
        );
        defer x11cntxt.extensions.xrandr.XRRFreeCrtcInfo(ci);

        _ = x11cntxt.extensions.xrandr.XRRSetCrtcConfig(
            x11cntxt.handles.xdisplay,
            sr,
            self.adapter,
            libx11.CurrentTime,
            ci.x,
            ci.y,
            self.orig_mode,
            ci.rotation,
            ci.outputs,
            ci.noutput,
        );
        self.orig_mode = x11ext.RRMode_None;
    }

    /// Set the window Handle.
    pub inline fn setWindow(self: *Self, window: ?*WindowImpl) void {
        self.window = window;
    }

    pub fn debugInfos(self: *const Self, print_video_modes: bool) void {
        if (dbg) {
            std.debug.print("\nMonitor:{s}\n", .{self.name});
            std.debug.print("\nAdapter:{d}\n", .{self.adapter});
            std.debug.print("\noutput:{d}\n", .{self.output});
            std.debug.print("\nindex:{?}\n", .{self.xinerama_index});
            if (print_video_modes) {
                std.debug.print("\n--------------VideoModes---------\n", .{});
                for (self.modes.items) |mode| {
                    std.debug.print("\n[+] Mode {any}\n", .{mode});
                }
            }
        }
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
        mon.debugInfos(true);
        var vm: VideoMode = undefined;
        mon.queryCurrentMode(&vm);
        std.debug.print("\n[+] Current Mode {any}\n", .{vm});
        var area: common.geometry.WidowArea = undefined;
        mon.monitorFullArea(&area);
        std.debug.print("\n[+] Current Full Area {any}\n", .{area});
    }
    // width = 1280, .height = 800, .frequency = 60, .color_depth = 24
    const nvm = VideoMode.init(1280, 800, 60, 24);
    const mon = &mons.items[0];
    try mon.setVideoMode(&nvm);
    std.time.sleep(3 * std.time.ns_per_s);
    try mon.setVideoMode(null);
}
