const std = @import("std");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const helperWindowProc = @import("./window_proc.zig").helperWindowProc;
const utils = @import("./utils.zig");
const monitor_impl = @import("./monitor_impl.zig");
const icon = @import("./icon.zig");
const clipboard = @import("./clipboard.zig");
const common = @import("common");
const error_defs = @import("errors.zig");
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const win32_system_power = zigwin32.system.power;
const win32_sys_service = zigwin32.system.system_services;
const Win32Context = @import("globals.zig").Win32Context;
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
    helper_data: HelperData,
    helper_window: win32.HWND,
    helper_class: u16,
    dev_notif_handle: *anyopaque,
    const HELPER_CLASS_NAME = "WIDOW_HELPER";
    const HELPER_TITLE = "";
    const Self = @This();

    pub const StatePointerMode = enum {
        Monitor,
        Joystick,
    };

    // if we were to use init to create the data on the stack
    // and then copy it to the heap it will invalidate the pointer
    // set as for the window (GWLP_USERDATA).
    pub fn setup(self: *Self) !void {
        // first time getting the singleton, must confirm successful init.
        const win32_singelton = Win32Context.singleton() orelse return error_defs.WidowWin32Error.FailedToInitPlatform;
        self.helper_class = try registerHelperClass(win32_singelton.handles.hinstance);
        self.helper_window = try createHelperWindow(win32_singelton.handles.hinstance);
        self.helper_data.next_clipboard_viewer = try clipboard.registerClipboardViewer(self.helper_window);
        self.helper_data.clipboard_change = false;
        self.helper_data.clipboard_text = null;
        self.helper_data.joysubsys_ptr = null;
        self.helper_data.monitor_store_ptr = null;
        registerDevicesNotif(self.helper_window, &self.dev_notif_handle);
        _ = win32_window_messaging.SetWindowLongPtrW(
            self.helper_window,
            win32_window_messaging.GWLP_USERDATA,
            @intCast(isize, @ptrToInt(&self.helper_data)),
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

        var buffer: [(Self.HELPER_CLASS_NAME.len) * 4]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const fballocator = fba.allocator();

        // Shoudln't fail since the buffer is big enough.
        const helper_class_name = utils.utf8ToWideZ(fballocator, Self.HELPER_CLASS_NAME) catch unreachable;

        // Unregister the helper class.
        _ = win32_window_messaging.UnregisterClassW(
            // utils.makeIntAtom(u8, self.win32.handles.helper_class),
            helper_class_name,
            Win32Context.singleton().?.handles.hinstance,
        );
    }

    pub inline fn setStatePointer(self: *Self, mode: StatePointerMode, pointer: ?*anyopaque) void {
        switch (mode) {
            StatePointerMode.Monitor => {
                self.helper_data.monitor_store_ptr = @ptrCast(?*MonitorStore, @alignCast(8, pointer));
            },
            StatePointerMode.Joystick => {
                self.helper_data.joysubsys_ptr = @ptrCast(?*JoystickSubSystemImpl, @alignCast(8, pointer));
            },
        }
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

fn registerHelperClass(hinstance: win32.HINSTANCE) !u16 {
    var helper_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    helper_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    helper_class.style = win32_window_messaging.CS_OWNDC;
    helper_class.lpfnWndProc = helperWindowProc;
    helper_class.hInstance = hinstance;
    // Estimate five times the curent utf8 string len.
    var buffer: [Internals.HELPER_CLASS_NAME.len * 4]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_CLASS_NAME) catch unreachable;
    helper_class.lpszClassName = wide_class_name;
    const class = win32_window_messaging.RegisterClassExW(&helper_class);
    if (class == 0) {
        return error_defs.WindowError.FailedToCreate;
    }
    return class;
}

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling monitor,clipboard,and joystick messages related messages.
fn createHelperWindow(hinstance: win32.HINSTANCE) !win32.HWND {
    // Estimate five times the curent utf8 string len.
    var buffer: [(Internals.HELPER_CLASS_NAME.len + Internals.HELPER_TITLE.len) * 4]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_CLASS_NAME) catch unreachable;
    const helper_title = utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_TITLE) catch unreachable;

    const helper_window = win32_window_messaging.CreateWindowExW(
        @intToEnum(win32_window_messaging.WINDOW_EX_STYLE, 0),
        wide_class_name,
        // utils.makeIntAtom(u16, helper_handle.*),
        helper_title,
        win32_window_messaging.WS_OVERLAPPED,
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
    dbi.dbcc_devicetype = @enumToInt(win32_sys_service.DBT_DEVTYP_DEVICEINTERFACE);
    dbi.dbcc_classguid = win32.GUID_DEVINTERFACE_HID;
    dbi_handle.* = win32_window_messaging.RegisterDeviceNotificationW(
        helper_window,
        @ptrCast(*anyopaque, &dbi),
        win32.DEVICE_NOTIFY_WINDOW_HANDLE,
    ) orelse unreachable; // Should always succeed.
}

/// create a platform icon and set it to the window.
pub fn createIcon(
    window: *WindowImpl,
    pixels: []const u8,
    width: i32,
    height: i32,
) !void {
    const sm_handle = try icon.createIcon(pixels, width, height, null, null);
    const bg_handle = try icon.createIcon(pixels, width, height, null, null);
    window.setIcon(&icon.Icon{ .sm_handle = sm_handle, .bg_handle = bg_handle });
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
    const handle = try icon.createIcon(pixels, width, height, xhot, yhot);
    window.setCursorShape(&icon.Cursor{ .handle = handle, .shared = false, .mode = common.cursor.CursorMode.Normal });
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
    monitors_map: std.AutoArrayHashMap(win32.HMONITOR, monitor_impl.MonitorImpl),
    used_monitors: u8,
    expected_video_change: bool, // For skipping unnecessary updates.
    prev_exec_state: win32_system_power.EXECUTION_STATE,
    const Self = @This();

    /// Initialize the `MonitorStore` struct.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .monitors_map = std.AutoArrayHashMap(win32.HMONITOR, monitor_impl.MonitorImpl).init(allocator),
            .used_monitors = 0,
            .expected_video_change = false,
            .prev_exec_state = win32_system_power.ES_SYSTEM_REQUIRED,
        };

        // Populate the monitor map
        var monitors = try monitor_impl.pollMonitors(allocator);
        defer monitors.deinit();
        errdefer {
            for (monitors.items) |*monitor| {
                monitor.deinit();
            }
            monitors.deinit();
            self.monitors_map.deinit();
        }
        for (monitors.items) |*monitor| {
            try self.monitors_map.put(monitor.handle, monitor.*);
        }
        return self;
    }

    /// Deinitialize the `MonitorStore` struct.
    /// this frees the monitors map and invalidate all monitors refrence.
    pub fn deinit(self: *Self) void {
        self.expected_video_change = true;
        for (self.monitors_map.values()) |*monitor| {
            if (monitor.window) |*window| {
                window.*.requestRestore();
            }
            // free allocated data.
            monitor.deinit();
        }
        self.monitors_map.deinit();
    }

    /// Updates the monitor map by removing all disconnected monitors
    /// and adding new connected ones.
    /// # Note
    /// the update is very slow but it's only triggered if a monitor was connected, or disconnected.
    pub fn refreshMonitorsMap(self: *Self) !void {
        self.expected_video_change = true;
        defer self.expected_video_change = false;

        const all_monitors = try monitor_impl.pollMonitors(self.monitors_map.allocator);
        // keep track of the index in case of an error to free the remaining monitors.
        var i: usize = 0;
        defer all_monitors.deinit();
        errdefer {
            // clean the remaning monitors.
            for (i..all_monitors.items.len) |index| {
                all_monitors.items[index].deinit();
            }
        }

        // Remove the disconnected monitors.
        for (self.monitors_map.values()) |*monitor| {
            var disconnected = true;
            for (all_monitors.items) |*new_monitor| {
                if (monitor.equals(new_monitor)) {
                    disconnected = false;
                    break;
                }
            }
            if (disconnected) {
                // Restore any occupying window.
                if (monitor.window) |*window| {
                    window.*.requestRestore();
                }
                // Free the monitor name pointer.
                monitor.deinit();
                _ = self.monitors_map.swapRemove(monitor.handle);
            }
        }

        // Insert the new ones
        for (all_monitors.items) |*monitor| {
            var connected = true;
            for (self.monitors_map.values()) |*value| {
                if (monitor.equals(value)) {
                    connected = false;
                    break;
                }
            }

            if (connected) {
                try self.monitors_map.put(monitor.handle, monitor.*);
            } else {
                monitor.deinit();
            }
            i += 1;
        }
    }

    /// Acquire a monitor for a window
    pub fn setMonitorWindow(
        self: *Self,
        monitor_handle: win32.HMONITOR,
        window: *WindowImpl,
        monitor_area: *common.geometry.WidowArea,
    ) !void {
        const monitor = self.monitors_map.getPtr(monitor_handle) orelse {
            return error_defs.MonitorError.MonitorNotFound;
        };

        if (self.used_monitors == 0) {
            const thread_exec_state = comptime @enumToInt(win32_system_power.ES_CONTINUOUS) |
                @enumToInt(win32_system_power.ES_DISPLAY_REQUIRED);
            // first time acquiring a monitor
            // prevent the system from entering sleep or turning off.
            self.prev_exec_state = win32_system_power.SetThreadExecutionState(
                @intToEnum(win32_system_power.EXECUTION_STATE, thread_exec_state),
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
        const monitor = self.monitors_map.getPtr(monitor_handle) orelse {
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
        const monitor = self.monitors_map.getPtr(monitor_handle) orelse {
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
        const monitor = self.monitors_map.getPtr(monitor_handle) orelse {
            return error_defs.MonitorError.MonitorNotFound;
        };
        monitor.queryCurrentMode(output);
    }
};

test "MonitorStore.init()" {
    const testing = std.testing;
    var ms = try MonitorStore.init(testing.allocator);
    defer ms.deinit();
}
