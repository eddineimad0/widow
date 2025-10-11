const std = @import("std");
const common = @import("common");
const win32_gfx = @import("win32api/graphics.zig");
const win32_krnl = @import("win32api/kernel32.zig");
const utils = @import("utils.zig");
const wndw = @import("window.zig");
const build_options = @import("build-options");

const mem = std.mem;
const debug = std.debug;
const win32 = std.os.windows;
const unicode = std.unicode;

const VideoMode = common.video_mode.VideoMode;
const Win32Driver = @import("driver.zig").Win32Driver;
const ArrayList = std.ArrayListUnmanaged;

pub const DisplayError = error{
    MissingHandle,
    BadVideoMode,
    NotFound,
};

// Define helper window property name
pub const HELPER_DISPLAY_PROP = std.unicode.utf8ToUtf16LeStringLiteral("DISPLAY_REF");

/// We'll use this type to pass data to the `enumMonitorProc` function.
const LparamTuple = std.meta.Tuple(&.{ ?win32_gfx.HMONITOR, []const u16 });

fn EnumMonitorProc(
    handle: ?win32_gfx.HMONITOR,
    _: ?win32.HDC,
    _: ?*win32.RECT,
    lparam: win32.LPARAM,
) callconv(.winapi) win32.BOOL {
    const ulparam: usize = @intCast(lparam);
    const data: *LparamTuple = @ptrFromInt(ulparam);
    // the EnumDisplayMonitor function will return the handles of all monitors
    // that intersect the given rectangle even pseudo-monitors used for mirroring,
    // we'll need to compare the names to figure out the right handle.
    var mi: win32_gfx.MONITORINFOEXW = undefined;
    mi.monitorInfo.cbSize = @sizeOf(win32_gfx.MONITORINFOEXW);
    if (win32_gfx.GetMonitorInfoW(handle, @ptrCast(&mi)) == 1) {
        if (utils.wideStrZCmp(@ptrCast(&mi.szDevice), @ptrCast(data.*[1].ptr))) {
            data.*[0] = handle;
        }
    }
    return win32.TRUE;
}

/// Returns the handle used by the system to identify the monitor.
fn querySystemHandle(display_adapter: []const u16) ?win32_gfx.HMONITOR {
    var dm: win32_gfx.DEVMODEW = undefined;
    dm.dmSize = @sizeOf(win32_gfx.DEVMODEW);
    dm.dmDriverExtra = 0;
    // We need to figure out the rectangle that the monitor occupies
    // on the virtual desktop.
    if (win32_gfx.EnumDisplaySettingsExW(
        @ptrCast(display_adapter.ptr),
        win32_gfx.ENUM_CURRENT_SETTINGS,
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
    _ = win32_gfx.EnumDisplayMonitors(
        null,
        &clip_rect,
        EnumMonitorProc,
        @intCast(@intFromPtr(&data)),
    );

    return data[0];
}

/// Construct a Vector with all currently connected displays.
fn pollDisplays(
    allocator: mem.Allocator,
) (mem.Allocator.Error || DisplayError)!ArrayList(Display) {
    // Anticipate at least 4 displays.
    var displays = try ArrayList(Display).initCapacity(allocator, 4);
    errdefer {
        for (displays.items) |*display| {
            display.deinit(allocator);
        }
        displays.deinit(allocator);
    }
    var display_device: win32_gfx.DISPLAY_DEVICEW = undefined;
    display_device.cb = @sizeOf(win32_gfx.DISPLAY_DEVICEW);
    var display_adapter: win32_gfx.DISPLAY_DEVICEW = undefined;
    display_adapter.cb = @sizeOf(win32_gfx.DISPLAY_DEVICEW);
    var i: u32 = 0;
    while (true) : (i += 1) {
        if (win32_gfx.EnumDisplayDevicesW(null, i, &display_adapter, 0) == 0)
            break; // End of enumeration.

        if (display_adapter.StateFlags & win32_gfx.DISPLAY_DEVICE_ACTIVE == 0)
            continue; // Skip non active adapters.

        var j: u32 = 0;
        while (true) : (j += 1) {
            if (win32_gfx.EnumDisplayDevicesW(
                @ptrCast(&display_adapter.DeviceName),
                j,
                &display_device,
                0,
            ) == 0) {
                // End of enumeration.
                break;
            }

            if (display_device.StateFlags & win32_gfx.DISPLAY_DEVICE_ACTIVE == 0)
                continue; // Skip non active displays.

            // Get the handle for the monitor.
            const handle = querySystemHandle(&display_adapter.DeviceName) orelse
                return DisplayError.MissingHandle;

            var display = try Display.init(
                allocator,
                handle,
                display_adapter.DeviceName,
                display_device.DeviceName,
                display_device.StateFlags & win32_gfx.DISPLAY_DEVICE_PRIMARY_DEVICE != 0,
            );
            errdefer display.deinit(allocator);

            try displays.append(allocator, display);
        }
    }
    // Shrink and fit
    displays.shrinkAndFree(allocator, displays.items.len);
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
    errdefer modes.deinit(allocator);
    var dev_mode: win32_gfx.DEVMODEW = undefined;
    dev_mode.dmSize = @sizeOf(win32_gfx.DEVMODEW);
    dev_mode.dmDriverExtra = 0;

    // save the registry settings at index 0
    _ = win32_gfx.EnumDisplaySettingsW(
        @ptrCast(adapter_name.ptr),
        win32_gfx.ENUM_REGISTRY_SETTINGS,
        &dev_mode,
    );

    try modes.append(allocator, VideoMode.init(
        @intCast(dev_mode.dmPelsWidth),
        @intCast(dev_mode.dmPelsHeight),
        @intCast(dev_mode.dmDisplayFrequency),
        @intCast(dev_mode.dmBitsPerPel),
    ));

    main_loop: while (true) : (i += 1) {
        if (win32_gfx.EnumDisplaySettingsExW(
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
            if (mode.equals(video_mode))
                continue :main_loop;
        }

        try modes.append(allocator, mode);
    }
    // Shrink and fit
    modes.shrinkAndFree(allocator, modes.items.len);
    return modes;
}

/// Encapsulate the necessary infos for a display(monitor).
pub const Display = struct {
    handle: win32_gfx.HMONITOR, // System handle to the display.
    modes: ArrayList(VideoMode), // All the VideoModes that the monitor support.
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the display.
    name: []u8, // Name assigned to the display
    curr_video: usize, // the index of the currently active videomode.
    is_primary: bool,

    // the original(registry setting of the dispaly video mode)
    // is always saved at index 0 of the `modes` ArrayList.
    const REGISTRY_VIDEOMODE_INDEX = 0;

    const Self = @This();

    pub fn init(
        allocator: mem.Allocator,
        handle: win32_gfx.HMONITOR,
        adapter_name: [32]u16,
        device_name: [32]u16,
        primary: bool,
    ) mem.Allocator.Error!Self {
        // Enumerate all "possible" video modes.
        var modes = try pollVideoModes(allocator, &adapter_name);
        errdefer modes.deinit(allocator);

        const display_name = utils.wideZToUtf8(allocator, &device_name) catch
            return mem.Allocator.Error.OutOfMemory;

        errdefer unreachable;

        return .{
            .handle = handle,
            .modes = modes,
            .adapter = adapter_name,
            .name = display_name,
            .curr_video = REGISTRY_VIDEOMODE_INDEX,
            .is_primary = primary,
        };
    }

    pub fn deinit(self: *Self, allocator: mem.Allocator) void {
        // Hack since both self.name and self.modes
        // use the same allocator.
        self.restoreRegistryMode();
        allocator.free(self.name);
        self.modes.deinit(allocator);
    }

    /// checks if 2 displays represent the same device.
    pub inline fn equals(self: *const Self, other: *const Self) bool {
        // Windows(OS) might change the display handle when a new one is plugged or
        // an old one is unplugged so make sure to compare the name.
        return (mem.eql(u8, self.name, other.name));
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
    fn setVideoMode(self: *Self, mode: *const VideoMode) DisplayError!void {
        const possible_mode: usize = if (self.isVideoModeCompatible(mode)) |idx|
            idx
        else
            mode.selectBestMatch(self.modes.items);

        if (possible_mode == self.curr_video) {
            // the desired mode is already current.
            return;
        }

        const choosen_mode = &self.modes.items[possible_mode];
        var dm: win32_gfx.DEVMODEW = undefined;
        dm.dmSize = @sizeOf(win32_gfx.DEVMODEW);
        dm.dmDriverExtra = 0;
        dm.dmFields = win32_gfx.DM_PELSWIDTH |
            win32_gfx.DM_PELSHEIGHT |
            win32_gfx.DM_BITSPERPEL |
            win32_gfx.DM_DISPLAYFREQUENCY;
        dm.dmPelsWidth = @intCast(choosen_mode.width);
        dm.dmPelsHeight = @intCast(choosen_mode.height);
        dm.dmBitsPerPel = @intCast(choosen_mode.color_depth);
        dm.dmDisplayFrequency = @intCast(choosen_mode.frequency);
        const result = win32_gfx.ChangeDisplaySettingsExW(
            @ptrCast(&self.adapter),
            &dm,
            null,
            win32_gfx.CDS_TYPE{ .FULLSCREEN = 1 },
            null,
        );

        switch (result) {
            win32_gfx.DISP_CHANGE.SUCCESSFUL => {
                self.curr_video = possible_mode;
                return;
            },
            else => return DisplayError.BadVideoMode,
        }
    }

    /// Restores the original video mode stored in the registry.
    /// if it has changed.
    fn restoreRegistryMode(self: *Self) void {
        // Passing NULL for the lpDevMode parameter
        // and 0 for the dwFlags parameter
        // is the easiest way to switch to the registry
        // video mode after a dynamic mode change.
        if (self.curr_video != REGISTRY_VIDEOMODE_INDEX) {
            _ = win32_gfx.ChangeDisplaySettingsExW(
                @ptrCast(&self.adapter),
                null,
                null,
                win32_gfx.CDS_TYPE{ .FULLSCREEN = 1 },
                null,
            );
            self.curr_video = REGISTRY_VIDEOMODE_INDEX;
        }
    }

    /// Returns the dpi value for the given display.
    /// # Note
    /// This function is a last resort to get the dpi value for a window.
    pub fn displayDPI(self: *const Self, driver: *const Win32Driver) u32 {
        var dpi_x: u32 = undefined;
        var dpi_y: u32 = undefined;
        if (driver.opt_func.GetDpiForMonitor) |func| {
            // [win32 docs]
            // This API is not DPI aware and should not be used if
            // the calling thread is per-monitor DPI aware.
            if (func(self.handle, win32_gfx.MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y) != win32.S_OK) {
                return win32_gfx.USER_DEFAULT_SCREEN_DPI;
            }
        } else {
            const device_cntxt = win32_gfx.GetDC(null);
            dpi_x = @intCast(win32_gfx.GetDeviceCaps(
                device_cntxt,
                win32_gfx.GET_DEVICE_CAPS_INDEX.LOGPIXELSX,
            ));
            _ = win32_gfx.ReleaseDC(null, device_cntxt);
        }
        // [Win32 docs]
        // The values of *dpiX and *dpiY are identical.
        // You only need to record one of the values to
        // determine the DPI and respond appropriately.
        return dpi_x;
    }

    /// Populate the `area` with the monitor's full area.
    pub fn getFullArea(self: *const Self, area: *common.geometry.Rect) void {
        var mi: win32_gfx.MONITORINFO = undefined;
        mi.cbSize = @sizeOf(win32_gfx.MONITORINFO);
        _ = win32_gfx.GetMonitorInfoW(
            self.handle,
            &mi,
        );
        area.* = common.geometry.Rect.init(
            mi.rcMonitor.left,
            mi.rcMonitor.top,
            mi.rcMonitor.right - mi.rcMonitor.left,
            mi.rcMonitor.bottom - mi.rcMonitor.top,
        );
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
        }
    }
};

pub const DisplayManager = struct {
    displays: ArrayList(Display),
    expected_video_change: bool, // For skipping unnecessary updates.
    orig_thread_exec_state: win32_krnl.EXECUTION_STATE,

    const Self = @This();
    pub const WINDOW_PROP = unicode.utf8ToUtf16LeStringLiteral("Widow Display Manager");

    pub fn init(allocator: mem.Allocator) (mem.Allocator.Error || DisplayError)!Self {
        var self: Self = .{
            .expected_video_change = false,
            .displays = try pollDisplays(allocator),
            .orig_thread_exec_state = undefined,
        };

        self.orig_thread_exec_state =
            win32_krnl.SetThreadExecutionState(.{ .CONTINUOUS = 1 });
        _ = win32_krnl.SetThreadExecutionState(self.orig_thread_exec_state);

        return self;
    }

    pub fn deinit(self: *Self, allocator: mem.Allocator) void {
        self.expected_video_change = true;
        for (self.displays.items) |*d| {
            d.deinit(allocator);
        }
        self.displays.deinit(allocator);
    }

    /// Updates the displays array by removing all disconnected displays
    /// and adding new connected ones.
    pub fn rePollDisplays(self: *Self, allocator: mem.Allocator) (mem.Allocator.Error || DisplayError)!void {
        // PERF: This can possibly be optimized but isn't a priority now
        self.expected_video_change = true;
        defer self.expected_video_change = false;

        const new_displays = try pollDisplays(allocator);

        for (self.displays.items) |*display| {
            var disconnected = true;
            for (new_displays.items) |*new_display| {
                if (display.equals(new_display)) {
                    disconnected = false;
                    break;
                }
            }

            if (!disconnected) {
                // avoids changing the video mode when deinit is called.
                // as it's a useless call to the OS.
                display.curr_video = Display.REGISTRY_VIDEOMODE_INDEX;
            }
            display.deinit(allocator);
        }

        self.displays.deinit(allocator);

        self.displays = new_displays;
    }

    /// Returns a refrence to the Monitor occupied by the window.
    pub fn findWindowDisplay(self: *Self, window: *const wndw.Window) !*Display {
        const display_handle = win32_gfx.MonitorFromWindow(
            window.handle,
            win32_gfx.MONITOR_FROM_FLAGS.NEAREST,
        );
        // Find the monitor.
        var target: ?*Display = null;
        for (self.displays.items) |*d| {
            if (d.handle == display_handle) {
                target = d;
                break;
            }
        }

        const display = target orelse {
            if (build_options.LOG_PLATFORM_EVENTS) {
                std.log.err(
                    "[DisplayManager]: Display not found, requested handle={*} ,requesting window={d}",
                    .{ display_handle, window.data.id },
                );
            }
            return DisplayError.NotFound;
        };

        return display;
    }

    /// If the mode is null the function must not fail or return an error.
    pub fn setDisplayVideoMode(
        self: *Self,
        display: *Display,
        mode: ?*const VideoMode,
    ) DisplayError!void {
        // ChangeDisplaySettigns sends a WM_DISPLAYCHANGED message
        // We Set this here to avoid wastefully updating the monitors map.
        self.expected_video_change = true;
        if (mode) |m| {
            try display.setVideoMode(m);
        } else {
            display.restoreRegistryMode();
        }
        self.expected_video_change = false;
    }

    pub fn setScreenSaver(self: *Self, on: bool) void {
        if (!on) {
            self.orig_thread_exec_state = win32_krnl.SetThreadExecutionState(.{
                .CONTINUOUS = 1,
                .DISPLAY_REQUIRED = 1,
            });
        } else {
            _ = win32_krnl.SetThreadExecutionState(self.orig_thread_exec_state);
        }
    }
};

test "Display init" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try pollDisplays(testing_allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            monitor.deinit(testing_allocator);
        }
        all_monitors.deinit(testing_allocator);
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
            display.deinit(testing_allocator);
        }
        displays.deinit(testing_allocator);
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
