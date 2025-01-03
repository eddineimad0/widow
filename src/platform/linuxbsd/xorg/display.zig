const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const common = @import("common");
const utils = @import("utils.zig");

const VideoMode = common.video_mode.VideoMode;
const mem = std.mem;

const X11Driver = @import("driver.zig").X11Driver;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Window = @import("window.zig").Window;

const dbg = @import("builtin").mode == .Debug;

pub const DisplayError = error{
    VideoModeChangeFailed,
    NotFound,
};

/// Calculates and return the monitor frequency
/// from the video mode infos
/// Note:
/// if the a frequency value can't be calcluated it returns 0;
inline fn calculateDisplayFrequency(mode_info: *const x11ext.XRRModeInfo) u16 {
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
fn videoModeFromRRMode(
    driver: *const X11Driver,
    mode: *const x11ext.XRRModeInfo,
    rotated: bool,
    output: *VideoMode,
) bool {
    if (mode.modeFlags & x11ext.RR_Interlace != 0) {
        return false;
    }
    if (rotated) {
        output.width = @intCast(mode.height);
        output.height = @intCast(mode.width);
    } else {
        output.width = @intCast(mode.width);
        output.height = @intCast(mode.height);
    }
    output.frequency = calculateDisplayFrequency(mode);
    std.debug.assert(output.frequency != 0);
    output.color_depth = @intCast(libx11.DefaultDepth(
        driver.handles.xdisplay,
        driver.handles.default_screen,
    ));
    return true;
}

/// Fills the `modes_arry` and `ids_arry` with all possible
/// video modes for the specified `output`
fn pollVideoModes(
    driver: *const X11Driver,
    screens_res: *const x11ext.XRRScreenResources,
    output_info: *const x11ext.XRROutputInfo,
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
            if (!videoModeFromRRMode(driver, info, rotated, &videomode)) {
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
fn getScreenRessources(driver: *const X11Driver) *x11ext.XRRScreenResources {
    return if (driver.extensions.xrandr.is_v1point3)
        // Faster than XRRGetScreenResources.
        driver.extensions.xrandr.XRRGetScreenResourcesCurrent(
            driver.handles.xdisplay,
            driver.handles.root_window,
        )
    else
        // This request explicitly asks the server to ensure that the
        // configuration data is up-to-date
        driver.extensions.xrandr.XRRGetScreenResources(
            driver.handles.xdisplay,
            driver.handles.root_window,
        );
}

/// Construct a Vector with all currently connected displays.
pub fn pollDisplays(allocator: Allocator, driver: *const X11Driver) Allocator.Error!ArrayList(Display) {
    const screens_res = getScreenRessources(driver);
    // the number of crtcs match the number of video devices(GPUs) which matches the number
    // of possible displays.
    var displays = try ArrayList(Display).initCapacity(
        allocator,
        @intCast(screens_res.ncrtc),
    );
    errdefer {
        for (displays.items) |*d| {
            d.deinit(driver);
        }
        displays.deinit();
    }

    var screens: ?[*]x11ext.XineramaScreenInfo = null;
    var n_screens: i32 = 0;
    if (driver.extensions.xinerama.is_active) {
        screens = driver.extensions.xinerama.QueryScreens(
            driver.handles.xdisplay,
            &n_screens,
        );
    }

    // the number of outputs matches the number of available
    // video ports(HDMI,VGA,...etc)
    for (0..@intCast(screens_res.noutput)) |i| {
        const output_info = driver.extensions.xrandr.XRRGetOutputInfo(
            driver.handles.xdisplay,
            screens_res,
            screens_res.outputs[i],
        );
        if (output_info.connection != x11ext.RR_Connected or
            output_info.crtc == x11ext.RRCrtc_None)
        {
            // Skip if the output isn't connected or isn't drawing
            // from any video buffer(crtc);
            driver.extensions.xrandr.XRRFreeOutputInfo(output_info);
            continue;
        }

        // Grab the video buffer infos.
        const crtc_info = driver.extensions.xrandr.XRRGetCrtcInfo(
            driver.handles.xdisplay,
            screens_res,
            output_info.crtc,
        );

        // Figure out the xinerama index
        // in a multi-display setup.
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

        // Copy the display name.
        // in case of an error the dislay 'deinit' should free the name.
        const name_len = utils.strZLen(output_info.name);
        const name = try allocator.alloc(u8, name_len);
        utils.strNCpy(name.ptr, output_info.name, name_len);

        var d = Display{
            .adapter = output_info.crtc,
            .name = name,
            .output = screens_res.outputs[i],
            .xinerama_index = xinerama_index,
            .orig_mode = x11ext.RRMode_None,
            .window = null,
            .modes = ArrayList(VideoMode).init(allocator),
            .modes_ids = ArrayList(x11ext.RRMode).init(allocator),
        };
        errdefer d.deinit(driver);

        try pollVideoModes(
            driver,
            screens_res,
            output_info,
            (crtc_info.rotation == x11ext.RR_Rotate_90 or
                crtc_info.rotation == x11ext.RR_Rotate_270),
            &d.modes,
            &d.modes_ids,
        );

        try displays.append(d);
        driver.extensions.xrandr.XRRFreeOutputInfo(output_info);
        driver.extensions.xrandr.XRRFreeCrtcInfo(crtc_info);
    }
    driver.extensions.xrandr.XRRFreeScreenResources(screens_res);
    if (screens) |scrns| {
        _ = libx11.XFree(scrns);
    }
    // Shrink and free.
    displays.shrinkAndFree(displays.items.len);
    return displays;
}

/// Encapsulate the necessary infos for a monitor.
pub const Display = struct {
    adapter: x11ext.RRCrtc,
    name: []u8,
    output: x11ext.RROutput,
    xinerama_index: ?i32,
    modes: ArrayList(common.video_mode.VideoMode), // All the VideoModes that the monitor support.
    modes_ids: ArrayList(x11ext.RRMode),
    orig_mode: x11ext.RRMode, // Keeps track of any mode changes we made.
    window: ?*Window, // A pointer to the window occupying(fullscreen)

    const Self = @This();

    pub fn deinit(self: *Self, driver: *const X11Driver) void {
        self.restoreOrignalVideoMode(driver);
        self.modes.allocator.free(self.name);
        self.modes.deinit();
        self.modes_ids.deinit();
    }

    /// Check of if the 2 displays are equals.
    pub fn equals(self: *const Self, other: *const Self) bool {
        self.adapter = other.adapter;
    }

    /// Populate the output with the current VideoMode of the monitor.
    pub fn queryCurrentMode(self: *const Self, driver: *const X11Driver, output: *VideoMode) void {
        const res = getScreenRessources(driver);
        defer driver.extensions.xrandr.XRRFreeScreenResources(res);
        const ci = driver.extensions.xrandr.XRRGetCrtcInfo(
            driver.handles.xdisplay,
            res,
            self.adapter,
        );
        defer driver.extensions.xrandr.XRRFreeCrtcInfo(ci);

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
                driver,
                mi,
                (ci.rotation == x11ext.RR_Rotate_90 or
                    ci.rotation == x11ext.RR_Rotate_270),
                output,
            );
        }
    }

    /// Populate the `area` with the monitor's full area.
    pub inline fn getFullArea(
        self: *const Self,
        area: *common.geometry.WidowArea,
        driver: *const X11Driver,
    ) void {
        const sr = getScreenRessources(driver);
        defer driver.extensions.xrandr.XRRFreeScreenResources(sr);
        const ci = driver.extensions.xrandr.XRRGetCrtcInfo(
            driver.handles.xdisplay,
            sr,
            self.adapter,
        );
        defer driver.extensions.xrandr.XRRFreeCrtcInfo(ci);
        area.top_left.x = ci.x;
        area.top_left.y = ci.y;
        area.size.width = @intCast(ci.width);
        area.size.height = @intCast(ci.height);
    }

    /// Determines if the desired VideoMode `mode` is possible with
    /// the current display.
    inline fn isVideoModePossible(
        self: *const Self,
        mode: *const VideoMode,
        index: *usize,
    ) bool {
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
    pub fn setVideoMode(
        self: *Self,
        video_mode: *const VideoMode,
        driver: *const X11Driver,
    ) DisplayError!void {
        var mode_index: usize = undefined;
        if (self.isVideoModePossible(video_mode, &mode_index) == false) {
            mode_index = video_mode.selectBestMatch(self.modes.items);
        }
        var current_mode: VideoMode = undefined;
        self.queryCurrentMode(driver, &current_mode);
        if (self.modes.items[mode_index].equals(&current_mode)) {
            // The desired mode is already current.
            return;
        }
        const sr = getScreenRessources(driver);
        defer driver.extensions.xrandr.XRRFreeScreenResources(sr);
        const ci = driver.extensions.xrandr.XRRGetCrtcInfo(
            driver.handles.xdisplay,
            sr,
            self.adapter,
        );
        defer driver.extensions.xrandr.XRRFreeCrtcInfo(ci);

        if (self.orig_mode == x11ext.RRMode_None) {
            self.orig_mode = ci.mode;
        }

        const result = driver.extensions.xrandr.XRRSetCrtcConfig(
            driver.handles.xdisplay,
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
            return DisplayError.VideoModeChangeFailed;
        }
    }

    /// Restores the original video mode.
    fn restoreOrignalVideoMode(self: *Self, driver: *const X11Driver) void {
        // TODO: check
        if (self.orig_mode == x11ext.RRMode_None) {
            return;
        }
        const sr = getScreenRessources(driver);
        defer driver.extensions.xrandr.XRRFreeScreenResources(sr);

        const ci = driver.extensions.xrandr.XRRGetCrtcInfo(
            driver.handles.xdisplay,
            sr,
            self.adapter,
        );
        defer driver.extensions.xrandr.XRRFreeCrtcInfo(ci);

        _ = driver.extensions.xrandr.XRRSetCrtcConfig(
            driver.handles.xdisplay,
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
    pub inline fn setWindow(self: *Self, window: ?*Window) void {
        if (self.window) |w| {
            _ = w.setFullscreen(false);
        }
        self.window = window;
    }

    pub fn debugInfos(self: *const Self, print_video_modes: bool) void {
        if (dbg) {
            std.debug.print("\nDisplay:{s}\n", .{self.name});
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

pub const DisplayManager = struct {
    driver: *const X11Driver,
    displays: std.ArrayList(Display),

    const Self = @This();

    pub fn init(
        allocator: mem.Allocator,
        driver: *const X11Driver,
    ) (mem.Allocator.Error || DisplayError)!Self {
        return .{
            .displays = try pollDisplays(allocator, driver),
            .driver = driver,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.displays.items) |*d| {
            if (d.window) |w| {
                _ = w.setFullscreen(false);
            }
            d.deinit(self.driver);
        }
        self.displays.deinit();
    }

    /// Updates the displays array by removing all disconnected displays
    /// and adding new connected ones.
    pub fn updateDisplays(self: *Self) (mem.Allocator.Error || DisplayError)!void {
        const new_displays = try pollDisplays(self.displays.allocator, self.driver);

        for (self.displays.items) |*display| {
            var disconnected = true;
            for (new_displays.items) |*new_display| {
                if (display.equals(new_display)) {
                    disconnected = false;
                    break;
                }
            }

            if (disconnected) {
                // TODO: need to test what will happen to the window
            } else {
                // avoids changing the video mode when deinit is called.
                // as it's a useless call to the OS.
                // TODO: need to test what will happen to the window
                //display.curr_video = Display.REGISTRY_VIDEOMODE_INDEX;
            }
            display.deinit(self.driver);
        }

        self.displays.deinit();

        self.displays = new_displays;
    }

    /// Returns a refrence to the Monitor occupied by the window.
    pub fn findWindowDisplay(self: *Self, w: *const Window) !*Display {
        const w_area = w.data.client_area;
        std.debug.print("Window={}, Area={any}\n", .{ w.data.id, w_area });
        var d_area: common.geometry.WidowArea = undefined;
        var max_intersect: f32 = 0.0;
        var target: ?*Display = null;
        for (self.displays.items) |*d| {
            d.getFullArea(&d_area, self.driver);
            const intersect_percent = utils.getDisplayOverlapRatio(&d_area, &w_area);
            if (intersect_percent > max_intersect) {
                target = d;
                max_intersect = intersect_percent;
            }
        }

        const display = target orelse {
            std.log.err(
                "[DisplayManager]: monitor not found, for window_handle=@{}",
                .{w.handle},
            );
            return DisplayError.NotFound;
        };

        std.debug.print("Matching display={s}\n", .{display.name});
        return display;
    }

    /// If the mode is null the function must not fail or return an error.
    pub fn setDisplayVideoMode(
        self: *Self,
        display: *Display,
        mode: ?*const VideoMode,
    ) DisplayError!void {
        if (mode) |m| {
            try display.setVideoMode(m, self.driver);
        } else {
            display.restoreOrignalVideoMode(self.driver);
        }
    }
};

//test "poll_displays" {
//    const dyn = @import("x11/dynamic.zig");
//    try dyn.initDynamicApi();
//    const mons = try pollDisplays(std.testing.allocator);
//    defer {
//        for (mons.items) |*mon| {
//            mon.deinit();
//        }
//        mons.deinit();
//    }
//
//    for (mons.items) |mon| {
//        mon.debugInfos(true);
//        var vm: VideoMode = undefined;
//        mon.queryCurrentMode(&vm);
//        std.debug.print("\n[+] Current Mode {any}\n", .{vm});
//        var area: common.geometry.WidowArea = undefined;
//        mon.monitorFullArea(&area);
//        std.debug.print("\n[+] Current Full Area {any}\n", .{area});
//    }
//    // width = 1280, .height = 800, .frequency = 60, .color_depth = 24
//    const nvm = VideoMode.init(1280, 800, 60, 24);
//    const mon = &mons.items[0];
//    try mon.setVideoMode(&nvm);
//    std.time.sleep(3 * std.time.ns_per_s);
//    try mon.setVideoMode(null);
//}
