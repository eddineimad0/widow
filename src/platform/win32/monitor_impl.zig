const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const dbg = @import("builtin").mode == .Debug;
const win32 = @import("win32_defs.zig");
const utils = @import("./utils.zig");
const gdi = @import("zigwin32").graphics.gdi;
const WindowImpl = @import("window_impl.zig").WindowImpl;
const VideoMode = @import("common").video_mode.VideoMode;
const WidowArea = @import("common").geometry.WidowArea;
const Win32Driver = @import("driver.zig").Win32Driver;
const ArrayList = std.ArrayList;

pub const MonitorError = error{
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

/// Construct a Vector with all currently connected monitors.
pub fn pollMonitors(
    allocator: mem.Allocator,
) (mem.Allocator.Error || MonitorError)!ArrayList(MonitorImpl) {
    // Anticipate at least 4 monitors.
    var monitors = try ArrayList(MonitorImpl).initCapacity(allocator, 4);
    errdefer {
        for (monitors.items) |*monitor| {
            monitor.deinit();
        }
        monitors.deinit();
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
                return MonitorError.MissingHandle;
            };

            // We'll need it when enumerating video modes.
            const is_pruned = (display_adapter.StateFlags & gdi.DISPLAY_DEVICE_MODESPRUNED) != 0;
            // Enumerate all "possible" video modes.
            var modes = try pollVideoModes(allocator, &display_adapter.DeviceName, is_pruned);
            errdefer modes.deinit();

            const display_name = utils.wideZToUtf8(allocator, &display_device.DeviceName) catch {
                return mem.Allocator.Error.OutOfMemory;
            };
            errdefer allocator.free(display_name);
            try monitors.append(MonitorImpl.init(
                handle,
                display_adapter.DeviceName,
                display_name,
                modes,
            ));
        }
    }
    // Shrink and fit
    monitors.shrinkAndFree(monitors.items.len);
    return monitors;
}

/// Returns a Vector containing all the possible video modes
/// for the given display adapter.
fn pollVideoModes(
    allocator: mem.Allocator,
    adapter_name: []const u16,
    is_pruned: bool,
) mem.Allocator.Error!ArrayList(VideoMode) {
    var i: u32 = 0;
    var modes = try ArrayList(VideoMode).initCapacity(allocator, 64);
    errdefer modes.deinit();
    var dev_mode: gdi.DEVMODEW = undefined;
    // _ = win32.EnumDisplaySettingsExW(
    //     @ptrCast(&adapter_name.ptr),
    //     win32.ENUM_CURRENT_SETTINGS,
    //     &dev_mode,
    //     0,
    // );
    // debug.print(
    //     "Current_MODE:({},{},{},{})\n",
    //     .{ dev_mode.dmPelsWidth, dev_mode.dmPelsHeight, dev_mode.dmDisplayFrequency, dev_mode.dmBitsPerPel },
    // );

    // the current mode is at 0
    // try modes.append(VideoMode.init(
    //     @intCast(dev_mode.dmPelsWidth),
    //     @intCast(dev_mode.dmPelsHeight),
    //     @intCast(dev_mode.dmDisplayFrequency),
    //     @intCast(dev_mode.dmBitsPerPel),
    // ));

    main_loop: while (true) : (i += 1) {
        dev_mode.dmSize = @sizeOf(gdi.DEVMODEW);
        dev_mode.dmDriverExtra = 0;
        if (win32.EnumDisplaySettingsExW(
            @ptrCast(adapter_name.ptr),
            i,
            &dev_mode,
            0,
        ) == 0) {
            // No more modes to enumerate.
            break;
        }

        // var w, var h = .{ dev_mode.dmPelsWidth, dev_mode.dmPelsHeight };
        // if (dev_mode.Anonymous1.Anonymous2.dmDisplayOrientation == gdi.DMDO_90 or
        //     dev_mode.Anonymous1.Anonymous2.dmDisplayOrientation == gdi.DMDO_270)
        // {
        //     // switch width and height values.
        //     // TODO:test.
        //     mem.swap(@TypeOf(w), &w, &h);
        // }

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

        // If `is_pruned` we need to skip modes unsupported by the display.
        if (is_pruned and gdi.ChangeDisplaySettingsExW(
            @ptrCast(adapter_name),
            &dev_mode,
            null,
            gdi.CDS_TEST,
            null,
        ) == gdi.DISP_CHANGE_SUCCESSFUL) {
            continue;
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

/// Returns the dpi value for the given monitor.
/// # Note
/// This function is a last resort to get the dpi value for a window.
pub fn monitorDPI(
    monitor_handle: win32.HMONITOR,
) u32 {
    var dpi_x: u32 = undefined;
    var dpi_y: u32 = undefined;
    const drv = Win32Driver.singleton();
    if (drv.opt_func.GetDpiForMonitor) |func| {
        // [win32api docs]
        // This API is not DPI aware and should not be used if
        // the calling thread is per-monitor DPI aware.
        if (func(monitor_handle, win32.MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y) != win32.S_OK) {
            return win32.USER_DEFAULT_SCREEN_DPI;
        }
    } else {
        const device_cntxt = gdi.GetDC(null);
        dpi_x = @intCast(gdi.GetDeviceCaps(device_cntxt, gdi.LOGPIXELSX));
        _ = gdi.ReleaseDC(null, device_cntxt);
    }
    // [Winapi docs]
    // The values of *dpiX and *dpiY are identical.
    // You only need to record one of the values to
    // determine the DPI and respond appropriately.
    return dpi_x;
}

/// Encapsulate the necessary infos for a monitor.
pub const MonitorImpl = struct {
    handle: gdi.HMONITOR, // System handle to the monitor.
    name: []u8, // Name assigned to the monitor
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the monitor.
    modes: ArrayList(VideoMode), // All the VideoModes that the monitor support.
    current_mode: usize, // Keeps track of any mode changes we made.
    window: ?*WindowImpl, // A pointer to the window occupying(fullscreen) the monitor.

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
            .window = null,
            .current_mode = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        // Hack since both self.name and self.modes
        // use the same allocator.
        self.restoreRegistryMode();
        self.modes.allocator.free(self.name);
        self.modes.deinit();
    }

    /// checks if 2 monitors represent the same device.
    pub inline fn equals(self: *const Self, other: *const Self) bool {
        // Windows might change the monitor handle when a new one is plugged or unplugged
        // so make sure to compare the name.
        return (mem.eql(u8, self.name, other.name));
    }

    /// Populate the output with the current VideoMode of the monitor.
    pub inline fn queryCurrentMode(self: *const Self, output: *VideoMode) void {
        // if (self.current_mode) |*mode| {
        //     output.* = mode.*;
        //     return;
        // }
        //
        // var dev_mode: gdi.DEVMODEW = undefined;
        // dev_mode.dmDriverExtra = 0;
        // dev_mode.dmSize = @sizeOf(gdi.DEVMODEW);
        // _ = win32.EnumDisplaySettingsExW(
        //     @ptrCast(&self.adapter),
        //     win32.ENUM_CURRENT_SETTINGS,
        //     &dev_mode,
        //     0,
        // );
        // output.width = @intCast(dev_mode.dmPelsWidth);
        // output.height = @intCast(dev_mode.dmPelsHeight);
        // output.frequency = @intCast(dev_mode.dmDisplayFrequency);
        // output.color_depth = @intCast(dev_mode.dmBitsPerPel);

        output.* = self.modes.items[self.current_mode];
    }

    /// Populate the `area` with the monitor's full area.
    pub inline fn monitorFullArea(self: *const Self, area: *WidowArea) void {
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
    inline fn isModeCompatible(self: *const Self, mode: *const VideoMode) ?usize {
        for (self.modes.items, 0..) |*video_mode, idx| {
            if (video_mode.equals(mode)) {
                return idx;
            }
        }
        return null;
    }

    /// Sets the monitor fullscreen video mode to the desired `mode`,
    /// or a mode close to it in case of the display not being compatible
    /// with the requested `mode`.
    /// # Note
    /// if `mode` is null the monitor's original video mode is restored.
    pub fn setVideoMode(self: *Self, video_mode: ?*const VideoMode) !void {
        if (video_mode) |mode| {
            const possible_mode: usize = if (self.isModeCompatible(mode)) |idx|
                idx
            else
                mode.selectBestMatch(self.modes.items);
            // else blk: {
            //     const index = mode.selectBestMatch(self.modes.items);
            //     break :blk &self.modes.items[index];
            // };

            // var current_mode: VideoMode = undefined;
            // self.queryCurrentMode(&current_mode);
            if (possible_mode == self.current_mode) {
                // the desired mode is already current.
                return;
            }

            const choosen_mode = &self.modes.items[possible_mode];
            var dm: gdi.DEVMODEW = undefined;
            dm.dmDriverExtra = 0;
            dm.dmSize = @sizeOf(gdi.DEVMODEW);
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
                    self.current_mode = possible_mode;
                    return;
                },
                else => return MonitorError.BadVideoMode,
            }
        } else {
            self.restoreRegistryMode();
        }
    }

    /// Restores the original video mode stored in the registry.
    fn restoreRegistryMode(self: *Self) void {
        // Passing NULL for the lpDevMode parameter
        // and 0 for the dwFlags parameter
        // is the easiest way to return to the
        // default mode after a dynamic mode change.
        _ = gdi.ChangeDisplaySettingsExW(
            @ptrCast(&self.adapter),
            null,
            null,
            gdi.CDS_FULLSCREEN,
            null,
        );
        // TODO:
        // self.current_mode = null;
    }

    /// Set the window Handle field
    pub inline fn setWindow(self: *Self, window: ?*WindowImpl) void {
        self.window = window;
    }

    pub fn debugInfos(self: *Self, print_video_modes: bool) void {
        if (dbg) {
            std.debug.print("Handle:{x}\n", .{@intFromPtr(self.handle)});
            var adapter_name = std.mem.zeroes([32 * 3]u8);
            _ = std.unicode.utf16leToUtf8(&adapter_name, &self.adapter) catch unreachable;
            std.debug.print("adapter:{s} => name:{s}\n", .{ adapter_name, self.name });
            if (print_video_modes) {
                std.debug.print("video modes:", .{});
                for (self.modes.items) |*monitor| {
                    std.debug.print("{}\n", .{monitor.*});
                }
            }
            std.debug.print("\n current_mode: {}\n", .{self.current_mode});
            std.debug.print("\n occupying window: {?*}\n", .{self.window});
        }
    }
};

test "monitor_impl init" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try pollMonitors(testing_allocator);
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

// test "change primary video mode" {
//     const testing = std.testing;
//     const testing_allocator = testing.allocator;
//     var all_monitors = try pollMonitors(testing_allocator);
//     defer {
//         for (all_monitors.items) |*monitor| {
//             monitor.deinit();
//         }
//         all_monitors.deinit();
//     }
//     var primary_monitor = &all_monitors.items[0];
//     var output: VideoMode = undefined;
//     primary_monitor.debugInfos(false);
//     primary_monitor.queryCurrentMode(&output);
//     std.debug.print("Primary monitor name len:{}\n", .{primary_monitor.name.len});
//     std.debug.print("Current Video Mode: {}\n", .{output});
//     std.debug.print("Changing Video Mode....\n", .{});
//     const mode = VideoMode.init(700, 400, 55, 24);
//     try primary_monitor.setVideoMode(&mode);
//     std.time.sleep(std.time.ns_per_s * 3);
//     std.debug.print("Restoring Original Mode....\n", .{});
//     primary_monitor.restoreRegistryMode();
// }
