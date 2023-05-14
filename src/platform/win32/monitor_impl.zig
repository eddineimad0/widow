// use windows_sys::Win32::{
//     Foundation::{BOOL, FALSE, HWND, LPARAM, RECT, S_OK, TRUE},
const std = @import("std");
const Arraylist = std.ArrayList;
const Allocator = std.mem.Allocator;
const win_abi = std.os.windows.WINAPI;
const win32api = @import("win32");
const MDT_EFFECTIVE_DPI = win32api.ui.hi_dpi.MDT_EFFECTIVE_DPI;
const USER_DEFAULT_SCREEN_DPI = win32api.ui.windows_and_messaging.USER_DEFAULT_SCREEN_DPI;
const win32_gdi = win32api.graphics.gdi;
const win32_fndation = win32api.foundation;
const VideoMode = @import("../../core/video_mode.zig").VideoMode;
const utils = @import("./utils.zig");
const WidowPoint2D = @import("../../core/geometry.zig").WidowPoint2D;
const WidowSize = @import("../../core/geometry.zig").WidowSize;
const WidowArea = @import("../../core/geometry.zig").WidowArea;
const defs = @import("./defs.zig");

/// We'll use this type to pass data to the `enum_monitor_proc` function.
const LparamTuple = std.meta.Tuple(&.{ ?win32_gdi.HMONITOR, []const u16 });

fn enum_monitor_proc(
    handle: ?win32_gdi.HMONITOR,
    _: ?win32_gdi.HDC,
    _: ?*win32_fndation.RECT,
    data: win32_fndation.LPARAM,
) callconv(win_abi) win32_fndation.BOOL {
    var data_ptr = @intToPtr(*LparamTuple, @intCast(usize, data));
    // the EnumDisplayMonitor function will return the handles of all poll_monitors
    // that intersect the given rectangle even pseudo-monitors used for mirroring,
    // we'll need to compare the names to figure out the right handle.
    var mi: win32_gdi.MONITORINFOEXW = undefined;
    mi.__AnonymousBase_winuser_L13571_C43.cbSize = @sizeOf(win32_gdi.MONITORINFOEXW);
    if (win32_gdi.GetMonitorInfoW(handle, @ptrCast(*win32_gdi.MONITORINFO, &mi)) == 1) {
        if (utils.wide_strz_cmp(@ptrCast([*:0]const u16, &mi.szDevice), @ptrCast([*:0]const u16, data_ptr.*[1].ptr))) {
            data_ptr.*[0] = handle;
        }
    }
    return 1; // TRUE
}

/// Returns the handle used by the system to identify the monitor.
fn query_system_handle(display_adapter: []const u16) ?win32_gdi.HMONITOR {
    var dm: win32_gdi.DEVMODEW = undefined;
    dm.dmSize = @sizeOf(win32_gdi.DEVMODEW);
    dm.dmDriverExtra = 0;
    // we need to figure out the rectangle that the monitor occupies on the virtual
    // desktop.
    if (win32_gdi.EnumDisplaySettingsExW(@ptrCast([*:0]const u16, display_adapter.ptr), win32_gdi.ENUM_CURRENT_SETTINGS, &dm, 0) == 0) {
        return null;
    }
    var clip_rect = win32_fndation.RECT{
        .left = dm.Anonymous1.Anonymous2.dmPosition.x,
        .top = dm.Anonymous1.Anonymous2.dmPosition.y,
        .right = dm.Anonymous1.Anonymous2.dmPosition.x + @intCast(i32, dm.dmPelsWidth),
        .bottom = dm.Anonymous1.Anonymous2.dmPosition.y + @intCast(i32, dm.dmPelsHeight),
    };
    const data: LparamTuple = .{ null, display_adapter };
    // Enumerate the displays to figure out the monitor's handle
    _ = win32_gdi.EnumDisplayMonitors(null, &clip_rect, enum_monitor_proc, @intCast(isize, @ptrToInt(&data)));
    return data[0];
}

/// Construct a Vector with all currently connected monitors.
pub fn poll_monitors(allocator: Allocator) !Arraylist(MonitorImpl) {
    var monitors = try Arraylist(MonitorImpl).initCapacity(allocator, 4);
    errdefer monitors.deinit();
    var display_device: win32_gdi.DISPLAY_DEVICEW = undefined;
    display_device.cb = @sizeOf(win32_gdi.DISPLAY_DEVICEW);
    var display_adapter: win32_gdi.DISPLAY_DEVICEW = undefined;
    display_adapter.cb = @sizeOf(win32_gdi.DISPLAY_DEVICEW);
    var i: u32 = 0;
    var j: u32 = undefined;
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
            if (win32_gdi.EnumDisplayDevicesW(@ptrCast([*:0]const u16, &display_adapter.DeviceName), j, &display_device, 0) == 0) {
                // End of enumeration.
                break;
            }

            j += 1;
            if (display_device.StateFlags & win32_gdi.DISPLAY_DEVICE_ACTIVE == 0) {
                // Skip non active displays.
                continue;
            }

            var is_pruned = (display_adapter.StateFlags & win32_gdi.DISPLAY_DEVICE_MODESPRUNED) != 0;
            // Query for the handle.
            var handle = query_system_handle(&display_adapter.DeviceName) orelse {
                return error.FailedToQueryMonitorHandle;
            };
            // Query for the video modes.
            var modes = try poll_video_modes(allocator, &display_adapter.DeviceName, is_pruned);
            errdefer modes.deinit();
            std.debug.print("Device Name array {any}\n", .{display_device.DeviceName});
            var display_name = try utils.wide_to_utf8(allocator, &display_device.DeviceName);
            std.debug.print("Device Name slice {any}\n", .{display_name});
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
fn poll_video_modes(allocator: Allocator, adapter_name: []const u16, is_pruned: bool) !Arraylist(VideoMode) {
    var i: u32 = 0;
    var dev_mode: win32_gdi.DEVMODEW = undefined;
    var modes = try Arraylist(VideoMode).initCapacity(allocator, 64);
    errdefer modes.deinit();
    main_loop: while (true) {
        dev_mode.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        dev_mode.dmDriverExtra = 0;
        // In order for this enumeration to work a modification to zigwin32 package was necessary.
        // specifically ENUM_DISPLAY_SETTINGS type was changed form enum(u32) to u32;
        if (win32_gdi.EnumDisplaySettingsExW(@ptrCast([*:0]const u16, adapter_name.ptr), i, &dev_mode, 0) == 0) {
            // No more modes to enumerate.
            break;
        }
        i += 1;

        var mode = VideoMode.init(
            @intCast(i32, dev_mode.dmPelsWidth),
            @intCast(i32, dev_mode.dmPelsHeight),
            @intCast(u16, dev_mode.dmDisplayFrequency),
            @intCast(u8, dev_mode.dmBitsPerPel),
        );

        // Skip duplicate modes.
        for (modes.items) |video_mode| {
            if (mode.equals(&video_mode)) {
                continue :main_loop;
            }
        }

        // If `is_pruned` is set we need to skip unsupported modes.
        if (is_pruned and win32_gdi.ChangeDisplaySettingsExW(
            @ptrCast([*:0]const u16, adapter_name),
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

pub fn query_monitor_info(handle: win32_gdi.HMONITOR) win32_gdi.MONITORINFO {
    var mi: win32_gdi.MONITORINFO = undefined;
    mi.cbSize = @sizeOf(win32_gdi.MONITORINFO);
    _ = win32_gdi.GetMonitorInfoW(
        handle,
        &mi,
    );
    return mi;
}

pub fn monitor_content_scale(
    monitor_handle: win32_gdi.HMONITOR,
    proc: ?defs.proc_GetDpiForMonitor,
) f32 {
    var scale_x: u32 = undefined;
    var scale_y: u32 = undefined;

    if (proc) |GetDpiForMonitor| {
        // [win32api docs]
        // This API is not DPI aware and should not be used if the calling thread is per-monitor DPI aware.
        // For the DPI-aware version of this API, see GetDpiForWindow.
        if (GetDpiForMonitor(
            monitor_handle,
            MDT_EFFECTIVE_DPI,
            &scale_x,
            &scale_y,
        ) != win32_fndation.S_OK) {
            return 0.0;
        }
    } else {
        const device_cntxt = win32_gdi.GetDC(null);
        scale_x = @intCast(u32, win32_gdi.GetDeviceCaps(device_cntxt, win32_gdi.LOGPIXELSX));
        scale_y = @intCast(u32, win32_gdi.GetDeviceCaps(device_cntxt, win32_gdi.LOGPIXELSY));
        _ = win32_gdi.ReleaseDC(null, device_cntxt);
    }
    // [Winapi docs]
    // The values of *dpiX and *dpiY are identical.
    // You only need to record one of the values to
    // determine the DPI and respond appropriately.

    return @intToFloat(f32, scale_x) / @intToFloat(f32, USER_DEFAULT_SCREEN_DPI);
    //scale_y as f64 / USER_DEFAULT_SCREEN_DPI as f64,
}

pub const MonitorImpl = struct {
    handle: win32_gdi.HMONITOR, // Windows handle to the monitor.
    name: []u8, // Name assigned to the monitor
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the monitor.
    mode_changed: bool, // Set true if the original video mode of the monitor was changed.
    modes: Arraylist(VideoMode), // All the VideoModes that the monitor support.
    // window_handle: undefined, // A handle to the window covering the monitor

    const Self = @This();

    pub fn init(
        handle: win32_gdi.HMONITOR,
        adapter: [32]u16,
        name: []u8,
        modes: Arraylist(VideoMode),
    ) Self {
        return Self{
            .handle = handle,
            .adapter = adapter,
            .name = name,
            .modes = modes,
            .mode_changed = false,
            // window_handle: None.into(),
        };
    }

    // For now it's easier to deallocate
    // the monitors if deinit takes a const pointer.
    pub fn deinit(self: *Self) void {
        // Hack since both self.name and self.modes
        // use the same allocator.
        self.modes.allocator.free(self.name);
        self.modes.deinit();
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        return (self.handle == other.handle and utils.str_cmp(self.name, other.name));
    }

    /// Returns the current VideoMode of the monitor.
    pub fn query_current_mode(self: *const Self) VideoMode {
        var dev_mode: win32_gdi.DEVMODEW = undefined;
        dev_mode.dmDriverExtra = 0;
        dev_mode.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        _ = win32_gdi.EnumDisplaySettingsExW(
            @ptrCast([*:0]const u16, &self.adapter),
            win32_gdi.ENUM_CURRENT_SETTINGS,
            &dev_mode,
            0,
        );

        return VideoMode.init(
            @intCast(i32, dev_mode.dmPelsWidth),
            @intCast(i32, dev_mode.dmPelsHeight),
            @intCast(u16, dev_mode.dmDisplayFrequency),
            @intCast(u8, dev_mode.dmBitsPerPel),
        );
    }

    /// Return a WidowArea containing the total resolution
    /// of the monitor.
    pub fn fullscreen_area(self: *const Self) WidowArea {
        var mi = query_monitor_info(self.handle);
        return WidowArea.init(mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top);
    }

    /// Determines if the desired VideoMode `mode` is possible with
    /// the current hardware.
    fn is_mode_possible(self: *const Self, mode: *const VideoMode) bool {
        for (self.modes.items) |*video_mode| {
            if (video_mode.equals(mode)) {
                return true;
            }
        }
        return false;
    }

    /// Sets the monitor fullscreen video mode to the desired `mode`,
    /// or a mode close to it in case of the hardware not being compatible
    /// with the requested `mode`.
    pub fn set_video_mode(self: *Self, mode: *const VideoMode) !void {
        const possible_mode = if (self.is_mode_possible(mode) == true) mode else mode.select_best_match(self.modes.items);

        if (possible_mode.*.equals(&(self.query_current_mode()))) {
            // the desired mode is already current.
            return;
        }

        var dm: win32_gdi.DEVMODEW = undefined;
        dm.dmDriverExtra = 0;
        dm.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        dm.dmFields = win32_gdi.DM_PELSWIDTH | win32_gdi.DM_PELSHEIGHT | win32_gdi.DM_BITSPERPEL | win32_gdi.DM_DISPLAYFREQUENCY;
        dm.dmPelsWidth = @intCast(u32, possible_mode.width);
        dm.dmPelsHeight = @intCast(u32, possible_mode.height);
        dm.dmBitsPerPel = @intCast(u32, possible_mode.color_depth);
        dm.dmDisplayFrequency = @intCast(u32, possible_mode.frequency);
        const result = win32_gdi.ChangeDisplaySettingsExW(@ptrCast([*:0]const u16, &self.adapter), &dm, null, win32_gdi.CDS_FULLSCREEN, null);

        switch (result) {
            win32_gdi.DISP_CHANGE_SUCCESSFUL => {
                self.mode_changed = true;
                return;
            },
            else => return error.FailedToSwitchMonitorVideoMode,
        }
    }

    /// Restores the original video mode stored in the registry.
    pub fn restore_orignal_video(self: *Self) void {
        // Passing NULL for the lpDevMode parameter and 0 for the dwFlags parameter
        // is the easiest way to return to the default mode after a dynamic mode change.
        _ = win32_gdi.ChangeDisplaySettingsExW(
            @ptrCast([*:0]const u16, &self.adapter),
            null,
            null,
            win32_gdi.CDS_FULLSCREEN,
            null,
        );
        self.mode_changed = false;
    }

    pub fn debug_out(self: *Self) void {
        std.debug.print("Handle:{}\n", .{@ptrToInt(self.handle)});
        var adapter_name = std.mem.zeroes([32 * 3]u8);
        _ = std.unicode.utf16leToUtf8(&adapter_name, &self.adapter) catch unreachable;
        std.debug.print("adapter:{s}|name:{s}\n", .{ adapter_name, self.name });
        std.debug.print("video modes:", .{});
        for (self.modes.items) |*monitor| {
            std.debug.print("{}", .{monitor.*});
        }
        std.debug.print("\n mode change : {}\n", .{self.mode_changed});
    }
};

//
//     #[inline]
//     /// Set the window Handle field
//     pub(super) fn set_window(&self, handle: Option<HWND>) {
//         self.window_handle.set(handle);
//         if handle.is_none() && self.mode_changed.get() {
//             self.restore_orignal_video();
//             self.mode_changed.set(false);
//         }
//     }
//
//     #[inline]
//     /// Notifies the window currently occupying the monitor
//     /// to switch back to windowed mode.
//     pub(super) fn notify_window_restore(&self) {
//         match self.window_handle.get() {
//             Some(handle) => {
//                 const SC_RESTORE: u32 = 0xF120;
//                 // the lparam parameter isn't used for SC_RESTORE
//                 // we'll use it to figure out if the SC_RESTORE was triggred by us
//                 unsafe { SendMessageW(handle, WM_SYSCOMMAND, SC_RESTORE as usize, -1) };
//             }
//             None => return,
//         }
//     }
// }
//

test "monitor_impl_init_test" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try poll_monitors(testing_allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            // monitors contain heap allocated data that need
            // to be freed.
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    try testing.expect(all_monitors.items.len > 0); // Should at least contain 1 display
}

test "changing_primary_video_mode" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try poll_monitors(testing_allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            // monitors contain heap allocated data that need
            // to be freed.
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    var primary_monitor = &all_monitors.items[0];
    primary_monitor.debug_out();
    const monitor_dpi = monitor_content_scale(primary_monitor.handle, null);
    std.debug.print("Monitor DPI:{}\n", .{monitor_dpi});
    std.debug.print("Current Video Mode: {}\n", .{primary_monitor.query_current_mode()});
    std.debug.print("Full Resolution: {}\n", .{primary_monitor.fullscreen_area()});
    std.debug.print("Changing Video Mode....\n", .{});
    const mode = VideoMode.init(700, 400, 55, 24);
    try primary_monitor.set_video_mode(&mode);
    std.time.sleep(std.time.ns_per_s * 3);
    std.debug.print("Restoring Original Mode....\n", .{});
    primary_monitor.restore_orignal_video();
}
