const std = @import("std");
const monitor_impl = @import("monitor_impl.zig");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const X11Context = @import("global.zig").X11Context;
const WindowImpl = @import("window_impl.zig").WindowImpl;

/// Data our hidden helper window will modify during execution.
pub const HelperData = struct {
    monitor_store_ptr: ?*MonitorStore,
    clipboard_text: ?[]u8,
};

pub const Internals = struct {
    helper_data: HelperData,
    helper_window: libx11.Window,
    const HELPER_TITLE = "WIDOW_HELPER";
    const Self = @This();

    pub const StatePointerMode = enum {
        Monitor,
        Joystick,
    };

    // if we were to use init to create the data on the stack
    // and then copy it to the heap it will invalidate the pointer
    // set as for the window (GWLP_USERDATA).
    pub fn setup(self: *Self) !void {
        const x11cntxt = X11Context.singleton();
        _ = x11cntxt;
        self.helper_window = 0;
        self.helper_data.clipboard_text = null;
        self.helper_data.monitor_store_ptr = null;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.helper_data.clipboard_text) |text| {
            allocator.free(text);
            self.helper_data.clipboard_text = null;
        }
    }

    pub inline fn setStatePointer(self: *Self, mode: StatePointerMode, pointer: ?*anyopaque) void {
        switch (mode) {
            StatePointerMode.Monitor => {
                self.helper_data.monitor_store_ptr = @ptrCast(@alignCast(pointer));
            },
            else => {},
        }
    }

    pub fn clipboardText(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        _ = allocator;
        _ = self;
    }

    pub fn setClipboardText(self: *Self, allocator: std.mem.Allocator, text: []const u8) !void {
        _ = text;
        _ = allocator;
        _ = self;
    }
};

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling monitor,clipboard,and joystick messages related messages.
fn createHelperWindow() !libx11.Window {}

/// create a platform icon and set it to the window.
pub fn createIcon(
    window: *WindowImpl,
    pixels: []const u8,
    width: i32,
    height: i32,
) !void {
    _ = height;
    _ = width;
    _ = pixels;
    _ = window;
}

/// create a platform cursor and set it to the window.
pub fn createCursor(
    window: *WindowImpl,
    pixels: []const u8,
    width: i32,
    height: i32,
    xhot: u32,
    yhot: u32,
) !void {
    _ = yhot;
    _ = xhot;
    _ = height;
    _ = width;
    _ = pixels;
    _ = window;
}

// Zigwin32 libary doesn't have definitions for IDC constants probably due to alignement issues.
// pub fn createStandardCursor(window: *WindowImpl, shape: CursorShape) !void {
//     const cursor_id = switch (shape) {
//         CursorShape.PointingHand => win32_window_messaging.IDC_HAND,
//         CursorShape.Crosshair => win32_window_messaging.IDC_CROSS,
//         CursorShape.Text => win32_window_messaging.IDC_IBEAM,
//         CursorShape.Wait => win32_window_messaging.IDC_WAIT,
//         CursorShape.Help => win32_window_messaging.IDC_HELP,
//         CursorShape.Busy => win32_window_messaging.IDC_APPSTARTING,
//         CursorShape.Forbidden => win32_window_messaging.IDC_NO,
//         else => win32_window_messaging.IDC_ARROW,
//     };
//     // LoadCursorW takes a handle to an instance of the module
//     // whose executable file contains the cursor to be loaded.
//     const handle = win32_window_messaging.LoadCursorW(0, cursor_id);
//     if (handle == 0) {
//         // We failed.
//         return error.FailedToLoadStdCursor;
//     }
//     window.setCursorShape(&icon.Cursor{ .handle = handle, .shared = true, .mode = common.cursor.CursorMode.Normal });
// }

pub const MonitorStore = struct {
    monitors: std.ArrayList(monitor_impl.MonitorImpl),
    used_monitors: u8,
    const Self = @This();

    /// Initialize the `MonitorStore` struct.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .used_monitors = 0,
            .monitors = undefined,
        };

        self.monitors = try monitor_impl.pollMonitors(allocator);

        return self;
    }

    /// Deinitialize the MonitorStore struct.
    /// this frees the monitors array invalidating all monitors refrence.
    pub fn deinit(self: *Self) void {
        for (self.monitors.items) |*monitor| {
            // if (monitor.window) |*window| {
            //     window.*.requestRestore();
            // }
            // free allocated data.
            monitor.deinit();
        }
        self.monitors.deinit();
    }

    // /// Updates the monitors array by removing all disconnected monitors
    // /// and adding new connected ones.
    // pub fn refreshMonitorsMap(self: *Self) !void {
    //     self.expected_video_change = true;
    //     defer self.expected_video_change = false;
    //
    //     const new_monitors = try monitor_impl.pollMonitors(self.monitors.allocator);
    //
    //     for (self.monitors.items) |*monitor| {
    //         var disconnected = true;
    //         for (new_monitors.items) |*new_monitor| {
    //             if (monitor.equals(new_monitor)) {
    //                 // pass along the address of the occupying window.
    //                 new_monitor.setWindow(monitor.window);
    //                 if (monitor.current_mode) |*mode| {
    //                     // copy the current video mode
    //                     new_monitor.setVideoMode(mode) catch {};
    //                 }
    //                 disconnected = false;
    //                 break;
    //             }
    //         }
    //         if (disconnected) {
    //             if (monitor.window) |window| {
    //                 // when a monitor is disconnected
    //                 // windows will move the window as is
    //                 // to an availble monitor
    //                 // not good in fullscreen mode.
    //                 window.requestRestore();
    //                 // when the window is restored from fullscreen
    //                 // its coordinates might fall in the region that
    //                 // the disconnected monitor occupied and end up being
    //                 // hidden from the user so manually set it's position.
    //                 window.setClientPosition(50, 50);
    //             }
    //         }
    //
    //         // avoids changing the video mode when deinit is called.
    //         // as it's a useless call to the OS.
    //         monitor.current_mode = null;
    //         monitor.deinit();
    //     }
    //
    //     self.monitors.deinit();
    //
    //     self.monitors = new_monitors;
    // }
    //
    // /// Acquire a monitor for a window
    // pub fn setMonitorWindow(
    //     self: *Self,
    //     //       monitor_handle: win32.HMONITOR,
    //     window: *WindowImpl,
    //     monitor_area: *common.geometry.WidowArea,
    // ) !void {
    //
    //     // Find the monitor.
    //     var target: ?*monitor_impl.MonitorImpl = null;
    //     for (self.monitors.items) |*item| {
    //         _ = item;
    //         // if (item.handle == monitor_handle) {
    //         //     target = item;
    //         //     break;
    //         // }
    //     }
    //     const monitor = target orelse {
    //         // std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
    //         // return error_defs.MonitorError.MonitorNotFound;
    //     };
    //
    //     if (self.used_monitors == 0) {
    //         // const thread_exec_state = comptime @intFromEnum(win32_system_power.ES_CONTINUOUS) |
    //         //     @intFromEnum(win32_system_power.ES_DISPLAY_REQUIRED);
    //         // first time acquiring a monitor
    //         // prevent the system from entering sleep or turning off.
    //         // self.prev_exec_state = win32_system_power.SetThreadExecutionState(
    //         //     @enumFromInt(thread_exec_state),
    //         // );
    //     } else {
    //         if (monitor.window) |old_window| {
    //             if (window.handle != old_window.handle) {
    //                 old_window.requestRestore();
    //             }
    //             self.used_monitors -= 1;
    //         }
    //     }
    //
    //     monitor.setWindow(window);
    //     self.used_monitors += 1;
    //     monitor.monitorFullArea(monitor_area);
    // }

    // Called by the window instance to release any occupied monitor
    // pub fn restoreMonitor(self: *Self, monitor_handle: win32.HMONITOR) !void {
    //     // Find the monitor.
    //     var target: ?*monitor_impl.MonitorImpl = null;
    //     for (self.monitors.items) |*item| {
    //         if (item.handle == monitor_handle) {
    //             target = item;
    //             break;
    //         }
    //     }
    //     const monitor = target orelse {
    //         std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
    //         return error_defs.MonitorError.MonitorNotFound;
    //     };
    //
    //     monitor.setWindow(null);
    //
    //     self.used_monitors -= 1;
    //     if (self.used_monitors == 0) {
    //         _ = win32_system_power.SetThreadExecutionState(self.prev_exec_state);
    //     }
    // }

    //     pub fn setMonitorVideoMode(
    //         self: *Self,
    //         monitor_handle: win32.HMONITOR,
    //         mode: ?*common.video_mode.VideoMode,
    //     ) !void {
    //         // Find the monitor.
    //         var target: ?*monitor_impl.MonitorImpl = null;
    //         for (self.monitors.items) |*item| {
    //             if (item.handle == monitor_handle) {
    //                 target = item;
    //                 break;
    //             }
    //         }
    //         const monitor = target orelse {
    //             std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
    //             return error_defs.MonitorError.MonitorNotFound;
    //         };
    //
    //         // ChangeDisplaySettigns sends a WM_DISPLAYCHANGED message
    //         // We Set this here to avoid wastefully updating the monitors map.
    //         self.expected_video_change = true;
    //         defer self.expected_video_change = false;
    //
    //         try monitor.setVideoMode(mode);
    //     }
    //
    //     pub fn monitorVideoMode(
    //         self: *const Self,
    //         monitor_handle: win32.HMONITOR,
    //         output: *common.video_mode.VideoMode,
    //     ) !void {
    //         // Find the monitor.
    //         var target: ?*monitor_impl.MonitorImpl = null;
    //         for (self.monitors.items) |*item| {
    //             if (item.handle == monitor_handle) {
    //                 target = item;
    //                 break;
    //             }
    //         }
    //         const monitor = target orelse {
    //             std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
    //             return error_defs.MonitorError.MonitorNotFound;
    //         };
    //         monitor.queryCurrentMode(output);
    //     }
    //
    //     pub fn debugInfos(self: *const Self) void {
    //         for (self.monitors.items) |*monitor| {
    //             monitor.debugInfos(false);
    //         }
    //     }
};
