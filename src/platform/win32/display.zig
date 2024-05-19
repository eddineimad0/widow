const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const gdi = @import("zigwin32").graphics.gdi;
const common = @import("common");
const Win32Driver = @import("driver.zig").Win32Driver;
const Window = @import("window.zig").Window;
const VideoMode = common.video_mode.VideoMode;
const WidowArea = common.geometry.WidowArea;
const ArrayList = std.ArrayList;

pub const DisplayError = error{
    MissingHandle,
    BadVideoMode,
    NotFound,
};

/// We'll use this type to pass data to the `enumMonitorProc` function.
const LparamTuple = std.meta.Tuple(&.{ ?gdi.HMONITOR, []const u16 });

fn EnumMonitorProc(
    handle: ?gdi.HMONITOR,
    _: ?gdi.HDC,
    _: ?*win32.RECT,
    lparam: win32.LPARAM,
) callconv(win32.WINAPI) win32.BOOL {
    const ulparam: usize = @intCast(lparam);
    const data: *LparamTuple = @ptrFromInt(ulparam);
    // the EnumDisplayMonitor function will return the handles of all monitors
    // that intersect the given rectangle even pseudo-monitors used for mirroring,
    // we'll need to compare the names to figure out the right handle.
    var mi: gdi.MONITORINFOEXW = undefined;
    mi.monitorInfo.cbSize = @sizeOf(gdi.MONITORINFOEXW);
    if (gdi.GetMonitorInfoW(handle, @ptrCast(&mi)) == 1) {
        if (utils.wideStrZCmp(@ptrCast(&mi.szDevice), @ptrCast(data.*[1].ptr))) {
            data.*[0] = handle;
        }
    }
    return win32.TRUE;
}

/// Returns the handle used by the system to identify the monitor.
fn querySystemHandle(display_adapter: []const u16) ?win32.HMONITOR {
    var dm: gdi.DEVMODEW = undefined;
    dm.dmSize = @sizeOf(gdi.DEVMODEW);
    dm.dmDriverExtra = 0;
    // We need to figure out the rectangle that the monitor occupies
    // on the virtual desktop.
    if (win32.EnumDisplaySettingsExW(
        @ptrCast(display_adapter.ptr),
        win32.ENUM_CURRENT_SETTINGS,
        &dm,
        0,
    ) == 0) {
        return null;
    }

    const pels_width: i32 = @intCast(dm.dmPelsWidth);
    const pels_height: i32 = @intCast(dm.dmPelsHeight);
    var clip_rect = win32.RECT{
        .left = dm.Anonymous1.Anonymous2.dmPosition.x,
        .top = dm.Anonymous1.Anonymous2.dmPosition.y,
        .right = dm.Anonymous1.Anonymous2.dmPosition.x + pels_width,
        .bottom = dm.Anonymous1.Anonymous2.dmPosition.y + pels_height,
    };

    const data: LparamTuple = .{ null, display_adapter };

    // Enumerate the displays that intersect the rectangle to figure
    // out the monitor's handle.
    _ = gdi.EnumDisplayMonitors(
        null,
        &clip_rect,
        EnumMonitorProc,
        @intCast(@intFromPtr(&data)),
    );

    return data[0];
}

/// Construct a Vector with all currently connected displays.
pub fn pollDisplays(
    allocator: mem.Allocator,
) (mem.Allocator.Error || DisplayError)!ArrayList(Display) {
    // Anticipate at least 4 displays.
    var displays = try ArrayList(Display).initCapacity(allocator, 4);
    errdefer {
        for (displays.items) |*display| {
            display.deinit();
        }
        displays.deinit();
    }
    var display_device: gdi.DISPLAY_DEVICEW = undefined;
    display_device.cb = @sizeOf(gdi.DISPLAY_DEVICEW);
    var display_adapter: gdi.DISPLAY_DEVICEW = undefined;
    display_adapter.cb = @sizeOf(gdi.DISPLAY_DEVICEW);
    var i: u32 = 0;
    while (true) : (i += 1) {
        if (gdi.EnumDisplayDevicesW(null, i, &display_adapter, 0) == 0) {
            // End of enumeration.
            break;
        }

        if (display_adapter.StateFlags & gdi.DISPLAY_DEVICE_ACTIVE == 0) {
            // Skip non active adapters.
            continue;
        }

        var j: u32 = 0;
        while (true) : (j += 1) {
            if (gdi.EnumDisplayDevicesW(
                @ptrCast(&display_adapter.DeviceName),
                j,
                &display_device,
                0,
            ) == 0) {
                // End of enumeration.
                break;
            }

            if (display_device.StateFlags & gdi.DISPLAY_DEVICE_ACTIVE == 0) {
                // Skip non active displays.
                continue;
            }

            // Get the handle for the monitor.
            const handle = querySystemHandle(&display_adapter.DeviceName) orelse {
                return DisplayError.MissingHandle;
            };

            // We'll need it when enumerating video modes.
            // This isn't required since *EnumDisplaySettingsExW* won't return
            // a non compatible video mode unless `EDS_RAWMODE(0x2)` is specified.
            // const is_pruned = (display_adapter.StateFlags & gdi.DISPLAY_DEVICE_MODESPRUNED) != 0;

            // Enumerate all "possible" video modes.
            var modes = try pollVideoModes(allocator, &display_adapter.DeviceName);
            errdefer modes.deinit();

            const display_name = utils.wideZToUtf8(allocator, &display_device.DeviceName) catch {
                return mem.Allocator.Error.OutOfMemory;
            };
            errdefer allocator.free(display_name);
            try displays.append(Display.init(
                handle,
                display_adapter.DeviceName,
                display_name,
                modes,
            ));
        }
    }
    // Shrink and fit
    displays.shrinkAndFree(displays.items.len);
    return displays;
}

/// Returns a Vector containing all the possible video modes
/// for the given display adapter.
fn pollVideoModes(
    allocator: mem.Allocator,
    adapter_name: []const u16,
) mem.Allocator.Error!ArrayList(VideoMode) {
    var i: u32 = 0;
    var modes = try ArrayList(VideoMode).initCapacity(allocator, 64);
    errdefer modes.deinit();
    var dev_mode: gdi.DEVMODEW = undefined;
    dev_mode.dmSize = @sizeOf(gdi.DEVMODEW);
    dev_mode.dmDriverExtra = 0;

    // save the registry settings at index 0
    _ = gdi.EnumDisplaySettingsW(
        @ptrCast(adapter_name.ptr),
        gdi.ENUM_REGISTRY_SETTINGS,
        &dev_mode,
    );

    try modes.append(VideoMode.init(
        @intCast(dev_mode.dmPelsWidth),
        @intCast(dev_mode.dmPelsHeight),
        @intCast(dev_mode.dmDisplayFrequency),
        @intCast(dev_mode.dmBitsPerPel),
    ));

    main_loop: while (true) : (i += 1) {
        if (win32.EnumDisplaySettingsExW(
            @ptrCast(adapter_name.ptr),
            i,
            &dev_mode,
            0,
        ) == 0) {
            // No more modes to enumerate.
            break;
        }

        var mode = VideoMode.init(
            @intCast(dev_mode.dmPelsWidth),
            @intCast(dev_mode.dmPelsHeight),
            @intCast(dev_mode.dmDisplayFrequency),
            @intCast(dev_mode.dmBitsPerPel),
        );

        // Skip duplicate modes.
        for (modes.items) |*video_mode| {
            if (mode.equals(video_mode)) {
                continue :main_loop;
            }
        }

        try modes.append(mode);
    }
    // Shrink and fit
    modes.shrinkAndFree(modes.items.len);
    return modes;
}

/// Populate the given MonitorInfo struct with the corresponding monitor informations.
pub inline fn queryMonitorInfo(handle: win32.HMONITOR, mi: *gdi.MONITORINFO) void {
    mi.cbSize = @sizeOf(gdi.MONITORINFO);
    _ = gdi.GetMonitorInfoW(
        handle,
        mi,
    );
}

/// Returns the dpi value for the given display.
/// # Note
/// This function is a last resort to get the dpi value for a window.
pub fn displayDPI(
    display_handle: win32.HMONITOR,
) u32 {
    var dpi_x: u32 = undefined;
    var dpi_y: u32 = undefined;
    const drv = Win32Driver.singleton();
    if (drv.opt_func.GetDpiForMonitor) |func| {
        // [win32 docs]
        // This API is not DPI aware and should not be used if
        // the calling thread is per-monitor DPI aware.
        if (func(display_handle, win32.MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y) != win32.S_OK) {
            return win32.USER_DEFAULT_SCREEN_DPI;
        }
    } else {
        const device_cntxt = gdi.GetDC(null);
        dpi_x = @intCast(gdi.GetDeviceCaps(device_cntxt, gdi.LOGPIXELSX));
        _ = gdi.ReleaseDC(null, device_cntxt);
    }
    // [Win32 docs]
    // The values of *dpiX and *dpiY are identical.
    // You only need to record one of the values to
    // determine the DPI and respond appropriately.
    return dpi_x;
}

/// Encapsulate the necessary infos for a display(monitor).
pub const Display = struct {
    handle: gdi.HMONITOR, // System handle to the display.
    name: []u8, // Name assigned to the display
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the display.
    modes: ArrayList(VideoMode), // All the VideoModes that the monitor support.
    curr_video: usize, // the index of the currently active videomode.
    window: ?*Window, // A pointer to the window occupying(fullscreen) the display.

    // the original(registry setting of the dispaly video mode)
    // is always saved at index 0 of the `modes` ArrayList.
    const REGISTRY_VIDEOMODE_INDEX = 0;

    const Self = @This();

    pub fn init(
        handle: gdi.HMONITOR,
        adapter: [32]u16,
        name: []u8,
        modes: ArrayList(VideoMode),
    ) Self {
        return .{
            .handle = handle,
            .adapter = adapter,
            .name = name,
            .modes = modes,
            .curr_video = REGISTRY_VIDEOMODE_INDEX,
            .window = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Hack since both self.name and self.modes
        // use the same allocator.
        self.restoreRegistryMode();
        self.modes.allocator.free(self.name);
        self.modes.deinit();
    }

    /// checks if 2 displays represent the same device.
    pub inline fn equals(self: *const Self, other: *const Self) bool {
        // Windows might change the display handle when a new one is plugged or
        // an old one is unplugged so make sure to compare the name.
        return (mem.eql(u8, self.name, other.name));
    }

    /// Populate the `area` with the monitor's full area.
    pub inline fn fullArea(self: *const Self, area: *WidowArea) void {
        var mi: gdi.MONITORINFO = undefined;
        queryMonitorInfo(self.handle, &mi);
        area.* = WidowArea.init(
            mi.rcMonitor.left,
            mi.rcMonitor.top,
            mi.rcMonitor.right - mi.rcMonitor.left,
            mi.rcMonitor.bottom - mi.rcMonitor.top,
        );
    }

    /// Determines if the desired VideoMode `mode` is possible with
    /// the current display,
    /// Returns an index to the matching VideoMode.
    inline fn isVideoModeCompatible(self: *const Self, mode: *const VideoMode) ?usize {
        for (self.modes.items, 0..) |*video_mode, idx| {
            if (video_mode.equals(mode)) {
                return idx;
            }
        }
        return null;
    }

    /// Populate the output with the current VideoMode of the display.
    pub inline fn getCurrentVideoMode(self: *const Self, output: *VideoMode) void {
        output.* = self.modes.items[self.curr_video];
    }

    /// Sets the display fullscreen video mode to the desired `mode`,
    /// or a mode close to it in case of the display not being compatible
    /// with the requested `video_mode`.
    /// # Note
    /// if `video_mode` is null the monitor's registry video mode is restored.
    pub fn setVideoMode(self: *Self, video_mode: ?*const VideoMode) DisplayError!void {
        if (video_mode) |mode| {
            const possible_mode: usize = if (self.isVideoModeCompatible(mode)) |idx|
                idx
            else
                mode.selectBestMatch(self.modes.items);

            if (possible_mode == self.curr_video) {
                // the desired mode is already current.
                return;
            }

            const choosen_mode = &self.modes.items[possible_mode];
            var dm: gdi.DEVMODEW = undefined;
            dm.dmSize = @sizeOf(gdi.DEVMODEW);
            dm.dmDriverExtra = 0;
            dm.dmFields = gdi.DM_PELSWIDTH |
                gdi.DM_PELSHEIGHT |
                gdi.DM_BITSPERPEL |
                gdi.DM_DISPLAYFREQUENCY;
            dm.dmPelsWidth = @intCast(choosen_mode.width);
            dm.dmPelsHeight = @intCast(choosen_mode.height);
            dm.dmBitsPerPel = @intCast(choosen_mode.color_depth);
            dm.dmDisplayFrequency = @intCast(choosen_mode.frequency);
            const result = gdi.ChangeDisplaySettingsExW(
                @ptrCast(&self.adapter),
                &dm,
                null,
                gdi.CDS_FULLSCREEN,
                null,
            );

            switch (result) {
                gdi.DISP_CHANGE_SUCCESSFUL => {
                    self.curr_video = possible_mode;
                    return;
                },
                else => return DisplayError.BadVideoMode,
            }
        } else {
            self.restoreRegistryMode();
        }
    }

    /// Restores the original video mode stored in the registry.
    fn restoreRegistryMode(self: *Self) void {
        // Passing NULL for the lpDevMode parameter
        // and 0 for the dwFlags parameter
        // is the easiest way to switch to the registry
        // video mode after a dynamic mode change.
        _ = gdi.ChangeDisplaySettingsExW(
            @ptrCast(&self.adapter),
            null,
            null,
            gdi.CDS_FULLSCREEN,
            null,
        );
        self.curr_video = REGISTRY_VIDEOMODE_INDEX;
    }

    /// Set the window Handle field
    pub inline fn setWindow(self: *Self, window: ?*Window) void {
        self.window = window;
    }

    pub fn debugInfos(self: *Self, print_video_modes: bool) void {
        if (common.IS_DEBUG_BUILD) {
            std.debug.print("Handle:{x}\n", .{@intFromPtr(self.handle)});
            var adapter_name = std.mem.zeroes([32 * 3]u8);
            _ = std.unicode.utf16leToUtf8(&adapter_name, &self.adapter) catch unreachable;
            std.debug.print(
                "adapter name:{s} => device name:{s}\n",
                .{ adapter_name, self.name },
            );
            if (print_video_modes) {
                for (self.modes.items) |*monitor| {
                    std.debug.print("{}\n", .{monitor.*});
                }
            }
            std.debug.print("current video mode: {}\n", .{self.curr_video});
            std.debug.print("occupying window ref: {?*}\n", .{self.window});
        }
    }
};

test "Display init" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try pollDisplays(testing_allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    try testing.expect(all_monitors.items.len > 0); // Should at least contain 1 display
    for (all_monitors.items) |*mon| {
        mon.debugInfos(true);
    }
}

test "change primary video mode" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var displays = try pollDisplays(testing_allocator);
    defer {
        for (displays.items) |*display| {
            display.deinit();
        }
        displays.deinit();
    }
    var primary = &displays.items[0];
    var output: VideoMode = undefined;
    primary.debugInfos(false);
    primary.getCurrentVideoMode(&output);
    std.debug.print("Primary display name: {s}\n", .{primary.name});
    std.debug.print("Current Video Mode: {}\n", .{output});
    std.debug.print("Changing Video Mode....\n", .{});
    const mode = VideoMode.init(700, 400, 55, 24);
    try primary.setVideoMode(&mode);
    primary.getCurrentVideoMode(&output);
    std.debug.print("Current Video Mode: {}\n", .{output});
    std.time.sleep(std.time.ns_per_s * 3);
    std.debug.print("Restoring Original Mode....\n", .{});
    primary.restoreRegistryMode();
}
