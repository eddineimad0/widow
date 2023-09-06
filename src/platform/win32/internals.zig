const std = @import("std");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const monitor_impl = @import("monitor_impl.zig");
const icon = @import("icon.zig");
const clipboard = @import("clipboard.zig");
const common = @import("common");
const error_defs = @import("errors.zig");
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const win32_system_power = zigwin32.system.power;
const win32_sys_service = zigwin32.system.system_services;
const Win32Context = @import("global.zig").Win32Context;
const WindowImpl = @import("window_impl.zig").WindowImpl;
const JoystickSubSystemImpl = @import("joystick_impl.zig").JoystickSubSystemImpl;

/// Data our hidden helper window will modify during execution.
pub const HelperData = struct {
    monitor_store_ptr: ?*MonitorStore,
    joysubsys_ptr: ?*JoystickSubSystemImpl,
    clipboard_change: bool, // So we can cache the clipboard value until it changes.
    next_clipboard_viewer: ?win32.HWND, // we're using the old api to watch the clipboard.
    clipboard_text: ?[]u8,
};

pub const Internals = struct {
    monitor_store: MonitorStore,
    jss: ?*JoystickSubSystemImpl,
    dev_notif_handle: *anyopaque,
    helper_data: HelperData,
    helper_window: win32.HWND,
    const HELPER_TITLE = "WIDOW_HELPER";
    const Self = @This();

    pub fn setup(self: *Self) !void {
        // if we were to use init to create the data on the stack
        // and then copy it to the heap it will invalidate the pointer
        // set as for the window (GWLP_USERDATA).
        const win32_singelton = Win32Context.singleton();
        self.helper_window = try createHelperWindow(win32_singelton.handles.hinstance);
        self.helper_data.next_clipboard_viewer = try clipboard.registerClipboardViewer(self.helper_window);
        self.helper_data.clipboard_change = false;
        self.helper_data.clipboard_text = null;
        self.helper_data.monitor_store_ptr = null;
        self.helper_data.joysubsys_ptr = null;
        self.jss = null;
        registerDevicesNotif(self.helper_window, &self.dev_notif_handle);

        _ = win32_window_messaging.SetWindowLongPtrW(
            self.helper_window,
            win32_window_messaging.GWLP_USERDATA,
            @intCast(@intFromPtr(&self.helper_data)),
        );
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        clipboard.unregisterClipboardViewer(self.helper_window, self.helper_data.next_clipboard_viewer);
        _ = win32_sys_service.UnregisterDeviceNotification(self.dev_notif_handle);

        _ = win32_window_messaging.SetWindowLongPtrW(
            self.helper_window,
            win32_window_messaging.GWLP_USERDATA,
            0,
        );

        _ = win32_window_messaging.DestroyWindow(self.helper_window);
        if (self.helper_data.clipboard_text) |text| {
            allocator.free(text);
            self.helper_data.clipboard_text = null;
        }

        self.monitor_store.deinit();
        if (self.jss) |jss| {
            jss.deinit();
            allocator.destroy(jss);
        }
    }

    /// Init the Monitor store member, and update the helper data refrence.
    pub fn initMonitorStoreImpl(self: *Self, allocator: std.mem.Allocator) !void {
        self.monitor_store = try MonitorStore.init(allocator);
        self.helper_data.monitor_store_ptr = &self.monitor_store;
    }

    pub fn initJoySubSysImpl(self: *Self, allocator: std.mem.Allocator, events_queue: *common.event.EventQueue) !*JoystickSubSystemImpl {
        if (self.jss == null) {
            self.jss = try allocator.create(JoystickSubSystemImpl);
            errdefer allocator.destroy(self.jss.?);
            try JoystickSubSystemImpl.setup(self.jss.?, allocator, events_queue);
            self.helper_data.joysubsys_ptr = self.jss;
        }
        return self.jss.?;
    }

    pub fn clipboardText(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        if (self.helper_data.clipboard_change or self.helper_data.clipboard_text == null) {
            // refetching clipboard data
            if (self.helper_data.clipboard_text) |text| {
                allocator.free(text);
                errdefer self.helper_data.clipboard_text = null;
            }
            self.helper_data.clipboard_text = try clipboard.clipboardText(allocator, self.helper_window);
            self.helper_data.clipboard_change = false;
        }
        return self.helper_data.clipboard_text.?;
    }

    pub fn setClipboardText(self: *Self, allocator: std.mem.Allocator, text: []const u8) !void {
        // refetch on the next call to Internals.clipboardText.
        return clipboard.setClipboardText(allocator, self.helper_window, text);
    }
};

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling monitor,clipboard,and joystick messages related messages.
fn createHelperWindow(hinstance: win32.HINSTANCE) !win32.HWND {
    var buffer: [(Internals.HELPER_TITLE.len) * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const helper_title = utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_TITLE) catch unreachable;

    const helper_window = win32.CreateWindowExW(
        0,
        utils.makeIntAtom(Win32Context.singleton().handles.helper_class),
        helper_title,
        0,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        null,
        null,
        hinstance,
        null,
    ) orelse {
        return error_defs.WindowError.FailedToCreate;
    };

    _ = win32_window_messaging.ShowWindow(helper_window, win32_window_messaging.SW_HIDE);
    return helper_window;
}

/// Register window to recieve HID notification
fn registerDevicesNotif(helper_window: win32.HWND, dbi_handle: **anyopaque) void {
    var dbi: win32_sys_service.DEV_BROADCAST_DEVICEINTERFACE_A = undefined;
    dbi.dbcc_size = @sizeOf(win32_sys_service.DEV_BROADCAST_DEVICEINTERFACE_A);
    dbi.dbcc_devicetype = @intFromEnum(win32_sys_service.DBT_DEVTYP_DEVICEINTERFACE);
    dbi.dbcc_classguid = win32.GUID_DEVINTERFACE_HID;
    dbi_handle.* = win32_window_messaging.RegisterDeviceNotificationW(
        helper_window,
        @ptrCast(&dbi),
        win32.DEVICE_NOTIFY_WINDOW_HANDLE,
    ) orelse unreachable; // Should always succeed.
}

/// create a platform icon and set it to the window.
pub fn createIcon(
    pixels: ?[]const u8,
    width: i32,
    height: i32,
) !icon.Icon {
    if (pixels) |slice| {
        const sm_handle = try icon.createIcon(slice, width, height, null, null);
        const bg_handle = try icon.createIcon(slice, width, height, null, null);
        return icon.Icon{ .sm_handle = sm_handle, .bg_handle = bg_handle };
    } else {
        return icon.Icon{ .sm_handle = null, .bg_handle = null };
    }
}

/// create a platform cursor and set it to the window.
pub fn createCursor(
    pixels: ?[]const u8,
    width: i32,
    height: i32,
    xhot: u32,
    yhot: u32,
) !icon.Cursor {
    if (pixels) |slice| {
        const handle = try icon.createIcon(slice, width, height, xhot, yhot);
        return icon.Cursor{ .handle = handle, .shared = false, .mode = common.cursor.CursorMode.Normal };
    } else {
        return icon.Cursor{ .handle = null, .shared = false, .mode = common.cursor.CursorMode.Normal };
    }
}

// TODO:
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
    expected_video_change: bool, // For skipping unnecessary updates.
    prev_exec_state: win32_system_power.EXECUTION_STATE,
    const Self = @This();

    /// Initialize the `MonitorStore` struct.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .used_monitors = 0,
            .expected_video_change = false,
            .prev_exec_state = win32_system_power.ES_SYSTEM_REQUIRED,
            .monitors = try monitor_impl.pollMonitors(allocator),
        };

        return self;
    }

    /// Deinitialize the MonitorStore struct.
    /// this frees the monitors array invalidating all monitors refrence.
    pub fn deinit(self: *Self) void {
        self.expected_video_change = true;
        for (self.monitors.items) |*monitor| {
            if (monitor.window) |*window| {
                window.*.requestRestore();
            }
            // free allocated data.
            monitor.deinit();
        }
        self.monitors.deinit();
    }

    /// Updates the monitors array by removing all disconnected monitors
    /// and adding new connected ones.
    pub fn refreshMonitorsMap(self: *Self) !void {
        self.expected_video_change = true;
        defer self.expected_video_change = false;

        const new_monitors = try monitor_impl.pollMonitors(self.monitors.allocator);

        for (self.monitors.items) |*monitor| {
            var disconnected = true;
            for (new_monitors.items) |*new_monitor| {
                if (monitor.equals(new_monitor)) {
                    // pass along the address of the occupying window.
                    new_monitor.setWindow(monitor.window);
                    if (monitor.current_mode) |*mode| {
                        // copy the current video mode
                        new_monitor.setVideoMode(mode) catch {};
                    }
                    disconnected = false;
                    break;
                }
            }
            if (disconnected) {
                if (monitor.window) |window| {
                    // when a monitor is disconnected
                    // windows will move the window as is
                    // to an availble monitor
                    // not good in fullscreen mode.
                    window.requestRestore();
                    // when the window is restored from fullscreen
                    // its coordinates might fall in the region that
                    // the disconnected monitor occupied and end up being
                    // hidden from the user so manually set it's position.
                    window.setClientPosition(50, 50);
                }
            }

            // avoids changing the video mode when deinit is called.
            // as it's a useless call to the OS.
            monitor.current_mode = null;
            monitor.deinit();
        }

        self.monitors.deinit();

        self.monitors = new_monitors;
    }

    /// Acquire a monitor for a window
    pub fn setMonitorWindow(
        self: *Self,
        monitor_handle: win32.HMONITOR,
        window: *WindowImpl,
        monitor_area: *common.geometry.WidowArea,
    ) !void {

        // Find the monitor.
        var target: ?*monitor_impl.MonitorImpl = null;
        for (self.monitors.items) |*item| {
            if (item.handle == monitor_handle) {
                target = item;
                break;
            }
        }
        const monitor = target orelse {
            std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
            return error_defs.MonitorError.MonitorNotFound;
        };

        if (self.used_monitors == 0) {
            const thread_exec_state = comptime @intFromEnum(win32_system_power.ES_CONTINUOUS) |
                @intFromEnum(win32_system_power.ES_DISPLAY_REQUIRED);
            // first time acquiring a monitor
            // prevent the system from entering sleep or turning off.
            self.prev_exec_state = win32_system_power.SetThreadExecutionState(
                @enumFromInt(thread_exec_state),
            );
        } else {
            if (monitor.window) |old_window| {
                if (window.handle != old_window.handle) {
                    old_window.requestRestore();
                }
                self.used_monitors -= 1;
            }
        }

        monitor.setWindow(window);
        self.used_monitors += 1;
        monitor.monitorFullArea(monitor_area);
    }

    /// Called by the window instance to release any occupied monitor
    pub fn restoreMonitor(self: *Self, monitor_handle: win32.HMONITOR) !void {
        // Find the monitor.
        var target: ?*monitor_impl.MonitorImpl = null;
        for (self.monitors.items) |*item| {
            if (item.handle == monitor_handle) {
                target = item;
                break;
            }
        }
        const monitor = target orelse {
            std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
            return error_defs.MonitorError.MonitorNotFound;
        };

        monitor.setWindow(null);

        self.used_monitors -= 1;
        if (self.used_monitors == 0) {
            _ = win32_system_power.SetThreadExecutionState(self.prev_exec_state);
        }
    }

    pub fn setMonitorVideoMode(
        self: *Self,
        monitor_handle: win32.HMONITOR,
        mode: ?*common.video_mode.VideoMode,
    ) !void {
        // Find the monitor.
        var target: ?*monitor_impl.MonitorImpl = null;
        for (self.monitors.items) |*item| {
            if (item.handle == monitor_handle) {
                target = item;
                break;
            }
        }
        const monitor = target orelse {
            std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
            return error_defs.MonitorError.MonitorNotFound;
        };

        // ChangeDisplaySettigns sends a WM_DISPLAYCHANGED message
        // We Set this here to avoid wastefully updating the monitors map.
        self.expected_video_change = true;
        defer self.expected_video_change = false;

        try monitor.setVideoMode(mode);
    }

    pub fn monitorVideoMode(
        self: *const Self,
        monitor_handle: win32.HMONITOR,
        output: *common.video_mode.VideoMode,
    ) !void {
        // Find the monitor.
        var target: ?*monitor_impl.MonitorImpl = null;
        for (self.monitors.items) |*item| {
            if (item.handle == monitor_handle) {
                target = item;
                break;
            }
        }
        const monitor = target orelse {
            std.debug.print("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
            return error_defs.MonitorError.MonitorNotFound;
        };
        monitor.queryCurrentMode(output);
    }

    pub fn debugInfos(self: *const Self) void {
        for (self.monitors.items) |*monitor| {
            monitor.debugInfos(false);
        }
    }
};

test "MonitorStore.init()" {
    const testing = std.testing;
    var ms = try MonitorStore.init(testing.allocator);
    try ms.refreshMonitorsMap();
    defer ms.deinit();
}
