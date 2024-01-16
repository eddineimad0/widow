const std = @import("std");
const dbg = @import("builtin").mode == .Debug;
const win32 = @import("win32_defs.zig");
const utils = @import("./utils.zig");
const win32_gdi = @import("zigwin32").graphics.gdi;
const MonitorError = @import("errors.zig").MonitorError;
const WindowImpl = @import("window_impl.zig").WindowImpl;
const VideoMode = @import("common").video_mode.VideoMode;
const WidowArea = @import("common").geometry.WidowArea;
const Win32Context = @import("global.zig").Win32Context;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

/// We'll use this type to pass data to the `enumMonitorProc` function.
const LparamTuple = std.meta.Tuple(&.{ ?win32_gdi.HMONITOR, []const u16 });

fn EnumMonitorProc(
    handle: ?win32_gdi.HMONITOR,
    _: ?win32_gdi.HDC,
    _: ?*win32.RECT,
    lparam: win32.LPARAM,
) callconv(win32.WINAPI) win32.BOOL {
    const ulparam: usize = @intCast(lparam);
    var data: *LparamTuple = @ptrFromInt(ulparam);
    // the EnumDisplayMonitor function will return the handles of all monitors
    // that intersect the given rectangle even pseudo-monitors used for mirroring,
    // we'll need to compare the names to figure out the right handle.
    var mi: win32_gdi.MONITORINFOEXW = undefined;
    mi.__AnonymousBase_winuser_L13571_C43.cbSize = @sizeOf(win32_gdi.MONITORINFOEXW);
    if (win32_gdi.GetMonitorInfoW(handle, @ptrCast(&mi)) == 1) {
        if (utils.wideStrZCmp(@ptrCast(&mi.szDevice), @ptrCast(data.*[1].ptr))) {
            data.*[0] = handle;
        }
    }
    return win32.TRUE;
}

/// Returns the handle used by the system to identify the monitor.
fn querySystemHandle(display_adapter: []const u16) ?win32.HMONITOR {
    var dm: win32_gdi.DEVMODEW = undefined;
    dm.dmSize = @sizeOf(win32_gdi.DEVMODEW);
    dm.dmDriverExtra = 0;
    // We need to figure out the rectangle that the monitor occupies on the virtual
    // desktop.
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

    // Enumerate the displays that intersect the rectangle to figure out the monitor's handle.
    _ = win32_gdi.EnumDisplayMonitors(null, &clip_rect, EnumMonitorProc, @intCast(@intFromPtr(&data)));
    return data[0];
}

/// Construct a Vector with all currently connected monitors.
pub fn pollMonitors(allocator: Allocator) !ArrayList(MonitorImpl) {
    // Anticipate at least 2 monitors.
    var monitors = try ArrayList(MonitorImpl).initCapacity(allocator, 2);
    errdefer {
        for (monitors.items) |*monitor| {
            monitor.deinit();
        }
        monitors.deinit();
    }
    var display_device: win32_gdi.DISPLAY_DEVICEW = undefined;
    display_device.cb = @sizeOf(win32_gdi.DISPLAY_DEVICEW);
    var display_adapter: win32_gdi.DISPLAY_DEVICEW = undefined;
    display_adapter.cb = @sizeOf(win32_gdi.DISPLAY_DEVICEW);
    var j: u32 = undefined;
    var i: u32 = 0;
    while (true) {
        if (win32_gdi.EnumDisplayDevicesW(null, i, &display_adapter, 0) == 0) {
            // End of enumeration.
            break;
        }

        i += 1;
        if (display_adapter.StateFlags & win32_gdi.DISPLAY_DEVICE_ACTIVE == 0) {
            // Skip non active adapters.
            continue;
        }

        j = 0;
        while (true) {
            if (win32_gdi.EnumDisplayDevicesW(@ptrCast(&display_adapter.DeviceName), j, &display_device, 0) == 0) {
                // End of enumeration.
                break;
            }

            j += 1;
            if (display_device.StateFlags & win32_gdi.DISPLAY_DEVICE_ACTIVE == 0) {
                // Skip non active displays.
                continue;
            }

            // Get the handle for the monitor.
            var handle = querySystemHandle(&display_adapter.DeviceName) orelse {
                return MonitorError.MonitorHandleNotFound;
            };

            // We'll need it when enumerating video modes.
            var is_pruned = (display_adapter.StateFlags & win32_gdi.DISPLAY_DEVICE_MODESPRUNED) != 0;
            // Enumerate all "possible" video modes.
            var modes = try pollVideoModes(allocator, &display_adapter.DeviceName, is_pruned);
            errdefer modes.deinit();

            var display_name = try utils.wideZToUtf8(allocator, &display_device.DeviceName);
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
fn pollVideoModes(allocator: Allocator, adapter_name: []const u16, is_pruned: bool) !ArrayList(VideoMode) {
    var i: u32 = 0;
    var modes = try ArrayList(VideoMode).initCapacity(allocator, 64);
    errdefer modes.deinit();
    var dev_mode: win32_gdi.DEVMODEW = undefined;
    main_loop: while (true) {
        dev_mode.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        dev_mode.dmDriverExtra = 0;
        if (win32.EnumDisplaySettingsExW(@ptrCast(adapter_name.ptr), i, &dev_mode, 0) == 0) {
            // No more modes to enumerate.
            break;
        }
        i += 1;

        var mode = VideoMode.init(
            @intCast(dev_mode.dmPelsWidth),
            @intCast(dev_mode.dmPelsHeight),
            @intCast(dev_mode.dmDisplayFrequency),
            @intCast(dev_mode.dmBitsPerPel),
        );

        // Skip duplicate modes.
        for (modes.items) |video_mode| {
            if (mode.equals(&video_mode)) {
                continue :main_loop;
            }
        }

        // If `is_pruned` we need to skip modes unsupported by the display.
        if (is_pruned and win32_gdi.ChangeDisplaySettingsExW(
            @ptrCast(adapter_name),
            &dev_mode,
            null,
            win32_gdi.CDS_TEST,
            null,
        ) == win32_gdi.DISP_CHANGE_SUCCESSFUL) {
            continue;
        }
        try modes.append(mode);
    }
    // Shrink and fit
    modes.shrinkAndFree(modes.items.len);
    return modes;
}

/// Populate the given MonitorInfo struct with the corresponding monitor informations.
pub inline fn queryMonitorInfo(handle: win32.HMONITOR, mi: *win32_gdi.MONITORINFO) void {
    mi.cbSize = @sizeOf(win32_gdi.MONITORINFO);
    _ = win32_gdi.GetMonitorInfoW(
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
    const singleton = Win32Context.singleton();
    if (singleton.functions.GetDpiForMonitor) |proc| {
        // [win32api docs]
        // This API is not DPI aware and should not be used if the calling thread is per-monitor DPI aware.
        // For the DPI-aware version of this API, see GetDpiForWindow.
        if (proc(monitor_handle, win32.MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y) != win32.S_OK) {
            return win32.USER_DEFAULT_SCREEN_DPI;
        }
    } else {
        const device_cntxt = win32_gdi.GetDC(null);
        dpi_x = @intCast(win32_gdi.GetDeviceCaps(device_cntxt, win32_gdi.LOGPIXELSX));
        _ = win32_gdi.ReleaseDC(null, device_cntxt);
    }
    // [Winapi docs]
    // The values of *dpiX and *dpiY are identical.
    // You only need to record one of the values to
    // determine the DPI and respond appropriately.
    return dpi_x;
}

/// Encapsulate the necessary infos for a monitor.
pub const MonitorImpl = struct {
    handle: win32_gdi.HMONITOR, // System handle to the monitor.
    name: []u8, // Name assigned to the monitor
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the monitor.
    modes: ArrayList(VideoMode), // All the VideoModes that the monitor support.
    current_mode: ?VideoMode, // Keeps track of any mode changes we made.
    window: ?*WindowImpl, // A pointer to the window occupying(fullscreen) the monitor.

    const Self = @This();

    pub fn init(
        handle: win32_gdi.HMONITOR,
        adapter: [32]u16,
        name: []u8,
        modes: ArrayList(VideoMode),
    ) Self {
        return Self{
            .handle = handle,
            .adapter = adapter,
            .name = name,
            .modes = modes,
            .window = null,
            .current_mode = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Hack since both self.name and self.modes
        // use the same allocator.
        self.modes.allocator.free(self.name);
        self.restoreOrignalVideo();
        self.modes.deinit();
    }

    /// Compares 2 monitors.
    /// # Note
    /// We will need this when checking which monitor was disconnected.
    pub inline fn equals(self: *const Self, other: *const Self) bool {
        // Windows might change the monitor handle when a new one is plugged or unplugged
        // so make sure to compare the name.
        return (utils.strCmp(self.name, other.name));
    }

    /// Populate the output with the current VideoMode of the monitor.
    pub fn queryCurrentMode(self: *const Self, output: *VideoMode) void {
        if (self.current_mode) |*mode| {
            output.* = mode.*;
            return;
        }

        var dev_mode: win32_gdi.DEVMODEW = undefined;
        dev_mode.dmDriverExtra = 0;
        dev_mode.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        _ = win32.EnumDisplaySettingsExW(
            @ptrCast(&self.adapter),
            win32.ENUM_CURRENT_SETTINGS,
            &dev_mode,
            0,
        );

        output.width = @intCast(dev_mode.dmPelsWidth);
        output.height = @intCast(dev_mode.dmPelsHeight);
        output.frequency = @intCast(dev_mode.dmDisplayFrequency);
        output.color_depth = @intCast(dev_mode.dmBitsPerPel);
    }

    /// Populate the `area` with the monitor's full area.
    pub inline fn monitorFullArea(self: *const Self, area: *WidowArea) void {
        var mi: win32_gdi.MONITORINFO = undefined;
        queryMonitorInfo(self.handle, &mi);
        area.* = WidowArea.init(
            mi.rcMonitor.left,
            mi.rcMonitor.top,
            mi.rcMonitor.right - mi.rcMonitor.left,
            mi.rcMonitor.bottom - mi.rcMonitor.top,
        );
    }

    /// Determines if the desired VideoMode `mode` is possible with
    /// the current display.
    inline fn isModePossible(self: *const Self, mode: *const VideoMode) bool {
        for (self.modes.items) |*video_mode| {
            if (video_mode.equals(mode)) {
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
    pub fn setVideoMode(self: *Self, video_mode: ?*const VideoMode) !void {
        // TODO: what if the monitor is rotated.
        if (video_mode) |mode| {
            const possible_mode = if (self.isModePossible(mode) == true)
                mode
            else blk: {
                const index = mode.selectBestMatch(self.modes.items);
                break :blk &self.modes.items[index];
            };

            var current_mode: VideoMode = undefined;
            self.queryCurrentMode(&current_mode);
            if (possible_mode.*.equals(&current_mode)) {
                // the desired mode is already current.
                return;
            }

            var dm: win32_gdi.DEVMODEW = undefined;
            dm.dmDriverExtra = 0;
            dm.dmSize = @sizeOf(win32_gdi.DEVMODEW);
            dm.dmFields = win32_gdi.DM_PELSWIDTH |
                win32_gdi.DM_PELSHEIGHT |
                win32_gdi.DM_BITSPERPEL |
                win32_gdi.DM_DISPLAYFREQUENCY;
            dm.dmPelsWidth = @intCast(possible_mode.width);
            dm.dmPelsHeight = @intCast(possible_mode.height);
            dm.dmBitsPerPel = @intCast(possible_mode.color_depth);
            dm.dmDisplayFrequency = @intCast(possible_mode.frequency);
            const result = win32_gdi.ChangeDisplaySettingsExW(
                @ptrCast(&self.adapter),
                &dm,
                null,
                win32_gdi.CDS_FULLSCREEN,
                null,
            );

            switch (result) {
                win32_gdi.DISP_CHANGE_SUCCESSFUL => {
                    self.current_mode = possible_mode.*;
                    return;
                },
                else => return MonitorError.BadVideoMode,
            }
        } else {
            self.restoreOrignalVideo();
        }
    }

    /// Restores the original video mode stored in the registry.
    fn restoreOrignalVideo(self: *Self) void {
        // Passing NULL for the lpDevMode parameter and 0 for the dwFlags parameter
        // is the easiest way to return to the default mode after a dynamic mode change.
        if (self.current_mode != null) {
            _ = win32_gdi.ChangeDisplaySettingsExW(
                @ptrCast(&self.adapter),
                null,
                null,
                win32_gdi.CDS_FULLSCREEN,
                null,
            );
            self.current_mode = null;
        }
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
            std.debug.print("adapter:{s}|name:{s}\n", .{ adapter_name, self.name });
            if (print_video_modes) {
                std.debug.print("video modes:", .{});
                for (self.modes.items) |*monitor| {
                    std.debug.print("{}", .{monitor.*});
                }
            }
            std.debug.print("\n mode change : {}\n", .{self.current_mode != null});
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
}

test "change primary video mode" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try pollMonitors(testing_allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    var primary_monitor = &all_monitors.items[0];
    var output: VideoMode = undefined;
    primary_monitor.debugInfos(false);
    primary_monitor.queryCurrentMode(&output);
    std.debug.print("Primary monitor name len:{}\n", .{primary_monitor.name.len});
    std.debug.print("Current Video Mode: {}\n", .{output});
    std.debug.print("Changing Video Mode....\n", .{});
    const mode = VideoMode.init(700, 400, 55, 24);
    try primary_monitor.setVideoMode(&mode);
    std.time.sleep(std.time.ns_per_s * 3);
    std.debug.print("Restoring Original Mode....\n", .{});
    primary_monitor.restoreOrignalVideo();
}
