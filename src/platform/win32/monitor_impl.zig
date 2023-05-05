// use super::{internals::Internals, utility::wide_to_utf8};
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

/// We'll use this type to pass data to the `enum_monitor_proc`.
const myTuple = std.meta.Tuple(&.{ ?win32_gdi.HMONITOR, []const u16 });

fn enum_monitor_proc(
    handle: ?win32_gdi.HMONITOR,
    _: ?win32_gdi.HDC,
    _: ?*win32_fndation.RECT,
    data: win32_fndation.LPARAM,
) callconv(win_abi) win32_fndation.BOOL {
    var data_ptr = @intToPtr(*myTuple, @intCast(usize, data));
    var mi: win32_gdi.MONITORINFOEXW = undefined;
    mi.__AnonymousBase_winuser_L13571_C43.cbSize = @sizeOf(win32_gdi.MONITORINFOEXW);
    if (win32_gdi.GetMonitorInfoW(handle, @ptrCast(*win32_gdi.MONITORINFO, &mi)) == 1) {
        if (utils.wide_str_cmp(&mi.szDevice, data_ptr.*[1])) {
            data_ptr.*[0] = handle;
        }
    }
    return 1; // TRUE
}

/// Returns the handle used by the system to identify the monitor.
fn query_system_handle(adapter_name: []const u16) ?win32_gdi.HMONITOR {
    // TODO: Code Smell;
    const data: myTuple = .{ null, adapter_name };
    var dm: win32_gdi.DEVMODEW = std.mem.zeroes(win32_gdi.DEVMODEW);
    dm.dmSize = @sizeOf(win32_gdi.DEVMODEW);
    _ = win32_gdi.EnumDisplaySettingsExW(@ptrCast([*:0]const u16, adapter_name.ptr), win32_gdi.ENUM_CURRENT_SETTINGS, &dm, 0);
    var clip_rect = win32_fndation.RECT{
        .left = dm.Anonymous1.Anonymous2.dmPosition.x,
        .top = dm.Anonymous1.Anonymous2.dmPosition.y,
        .right = dm.Anonymous1.Anonymous2.dmPosition.x + @intCast(i32, dm.dmPelsWidth),
        .bottom = dm.Anonymous1.Anonymous2.dmPosition.y + @intCast(i32, dm.dmPelsHeight),
    };
    _ = win32_gdi.EnumDisplayMonitors(null, &clip_rect, enum_monitor_proc, @intCast(isize, @ptrToInt(&data)));
    return data[0];
}

/// Construct a Vector with all currently connected monitors.
pub fn poll_monitors(allocator: Allocator) !Arraylist(MonitorImpl) {
    var monitors = try Arraylist(MonitorImpl).initCapacity(allocator, 4);
    errdefer monitors.deinit();
    var dd: win32_gdi.DISPLAY_DEVICEW = undefined;
    var da: win32_gdi.DISPLAY_DEVICEW = undefined;
    var i: u32 = 0;
    var j: u32 = undefined;
    while (true) {
        da.cb = @sizeOf(win32_gdi.DISPLAY_DEVICEW);
        if (win32_gdi.EnumDisplayDevicesW(null, i, &da, 0) == 0) {
            // End of enumeration.
            break;
        }

        i += 1;
        if (da.StateFlags & win32_gdi.DISPLAY_DEVICE_ACTIVE == 0) {
            // Skip non active adapters.
            continue;
        }

        j = 0;
        while (true) {
            dd.cb = @sizeOf(win32_gdi.DISPLAY_DEVICEW);
            if (win32_gdi.EnumDisplayDevicesW(@ptrCast([*:0]const u16, &da.DeviceName), j, &dd, 0) == 0) {
                // End of enumeration.
                break;
            }

            j += 1;
            if (dd.StateFlags & win32_gdi.DISPLAY_DEVICE_ACTIVE == 0) {
                // Skip non active displays.
                continue;
            }

            var is_pruned = (da.StateFlags & win32_gdi.DISPLAY_DEVICE_MODESPRUNED) != 0;
            // Query for the handle.
            var handle = query_system_handle(&da.DeviceName) orelse {
                return error.FailedToQueryMonitorHandle;
            };
            // Query for the video modes.
            var modes = try poll_video_modes(allocator, &da.DeviceName, is_pruned);
            errdefer modes.deinit();
            // TODO: allocator issue.
            var display_name = try std.unicode.utf16leToUtf8Alloc(std.heap.c_allocator, &dd.DeviceName);
            errdefer std.heap.c_allocator.free(display_name);
            try monitors.append(MonitorImpl.init(
                handle,
                da.DeviceName,
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
        // dev_mode = std.mem.zeroes(win32_gdi.DEVMODEW);
        dev_mode.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        dev_mode.dmDriverExtra = 0;
        if (win32_gdi.EnumDisplaySettingsExW(@ptrCast([*:0]const u16, adapter_name.ptr), i, &dev_mode, 0) == 0) {
            // No more modes to enumerate.
            break;
        }
        i += 1;

        var mode = VideoMode.init(
            @intCast(i32, dev_mode.dmPelsWidth),
            @intCast(i32, dev_mode.dmPelsHeight),
            @intCast(u8, dev_mode.dmBitsPerPel),
            @intCast(u16, dev_mode.dmDisplayFrequency),
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

pub const MonitorImpl = struct {
    handle: win32_gdi.HMONITOR, // Windows handle to the monitor.
    name: []u8, // Name assigned to the monitor
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the monitor.
    modes: Arraylist(VideoMode), // All the VideoModes that the monitor support.
    mode_changed: bool, // Set true if the original video mode of the monitor was changed.
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

    pub fn deinit(self: *const Self) void {
        // For now it's easier to deallocate
        // the monitors if deinit takes a const pointer.
        std.heap.c_allocator.free(self.name);
        self.modes.deinit();
    }

    // pub fn equals(self: *const Self, other: *const Self) bool {
    //     // The name too..
    //     return (self.handle == other.handle);
    // }
    //
    //

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
            @intCast(u8, dev_mode.dmBitsPerPel),
            @intCast(u16, dev_mode.dmDisplayFrequency),
        );
    }
    /// Returns a point containing the x and y coordinates of upper-left corner
    /// of the display, in desktop coordinates.
    /// i.e: relative position of the monitor in a multiple monitor environment.
    pub fn virtual_position(self: *const Self) WidowPoint2D {
        var dev_mode: win32_gdi.DEVMODEW = undefined;
        dev_mode.dmSize = @sizeOf(win32_gdi.DEVMODEW);
        dev_mode.dmDriverExtra = 0;
        win32_gdi.EnumDisplaySettingsExW(
            @ptrCast([*:0]const u16, &self.adapter),
            win32_gdi.ENUM_CURRENT_SETTINGS,
            &dev_mode,
            win32_gdi.EDS_ROTATEDMODE,
        );

        return WidowPoint2D.init(
            dev_mode.Anonymous1.Anonymous2.dmPosition.x,
            dev_mode.Anonymous1.Anonymous2.dmPosition.y,
        );
    }

    /// Return a tuple(Point,size) containing the total resolution
    /// of the monitor.
    pub fn fullscreen_area(self: *const Self) WidowArea {
        var mi = query_monitor_info(self.handle);
        return WidowArea.init(mi.rcMonitor.left, mi.rcMonitor.top, mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top);
    }

    /// Determines if the desired VideoMode `mode` is possible with
    /// the current hardware.
    fn is_mode_possible(self: *const Self, mode: *const VideoMode) bool {
        for (self.modes.items) |video_mode| {
            if (video_mode.equals(mode)) {
                return true;
            }
        }
        return false;
    }

    /// Sets the monitor fullscreen video mode to the desired `mode`,
    /// or a mode close to it in case of the hardware not being compatible
    /// with the requested `mode`.
    /// # Note
    /// The alternative mode is selected based on the following criteria,
    /// Color depth(Bits per pixels) > size(width and height) > refresh rate
    /// in that exact order.
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
        //Passing NULL for the lpDevMode parameter and 0 for the dwFlags parameter
        //is the easiest way to return to the default mode after a dynamic mode change.
        _ = win32_gdi.ChangeDisplaySettingsExW(
            @ptrCast([*:0]const u16, &self.adapter),
            null,
            null,
            win32_gdi.CDS_FULLSCREEN,
            null,
        );
        self.mode_changed = false;
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
// pub(super) fn monitor_content_scale(
//     monitor_handle: HMONITOR,
//     platform_internals: &Internals,
// ) -> f64 {
//     let mut scale_x: u32 = 0;
//     let mut _scale_y: u32 = 0;
//
//     if platform_internals.is_win8point1_or_above() {
//         unsafe {
//             // [win32api docs]
//             // This API is not DPI aware and should not be used if the calling thread is per-monitor DPI aware.
//             // For the DPI-aware version of this API, see GetDpiForWindow.
//             if platform_internals.functions.win32_GetDpiForMonitor.unwrap()(
//                 monitor_handle,
//                 MDT_EFFECTIVE_DPI,
//                 &mut scale_x,
//                 &mut _scale_y,
//             ) != S_OK
//             {
//                 return 0.0;
//             }
//         }
//     } else {
//         unsafe {
//             let device_cntxt = GetDC(0);
//             scale_x = GetDeviceCaps(device_cntxt, LOGPIXELSX) as u32;
//             _scale_y = GetDeviceCaps(device_cntxt, LOGPIXELSY) as u32;
//             ReleaseDC(0, device_cntxt);
//         }
//     }
//     // [Winapi docs]
//     // The values of *dpiX and *dpiY are identical.
//     // You only need to record one of the values to
//     // determine the DPI and respond appropriately.
//
//     return scale_x as f64 / USER_DEFAULT_SCREEN_DPI as f64;
//     //scale_y as f64 / USER_DEFAULT_SCREEN_DPI as f64,
// }

test "monitor_impl_init_test" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;
    var all_monitors = try poll_monitors(testing_allocator);
    defer {
        for (all_monitors.items) |monitor| {
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
        for (all_monitors.items) |monitor| {
            // monitors contain heap allocated data that need
            // to be freed.
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    var primary_monitor = &all_monitors.items[0];
    std.debug.print("Current Video Mode: {}\n", .{primary_monitor.query_current_mode()});
    std.debug.print("Full Resolution: {}\n", .{primary_monitor.fullscreen_area()});
    std.debug.print("Changing Video Mode....\n", .{});
    const mode = VideoMode.init(800, 600, 32, 60);
    try primary_monitor.set_video_mode(&mode);
    std.time.sleep(std.time.ns_per_s * 3);
    std.debug.print("Restoring Original Mode....\n", .{});
    primary_monitor.restore_orignal_video();
}
