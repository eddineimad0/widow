const std = @import("std");
const dbg = @import("builtin").mode == .Debug;
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const monitor_impl = @import("monitor_impl.zig");
const icon = @import("icon.zig");
const clipboard = @import("clipboard.zig");
const common = @import("common");
const error_defs = @import("errors.zig");
const window_msg = zigwin32.ui.windows_and_messaging;
const sys_power = zigwin32.system.power;
const sys_service = zigwin32.system.system_services;
const Win32Driver = @import("driver.zig").Win32Driver;
const WindowImpl = @import("window_impl.zig").WindowImpl;

/// Data our hidden helper window will modify during execution.
pub const HelperData = struct {
    monitor_store_ptr: ?*MonitorStore,
    clipboard_change: bool, // So we can cache the clipboard value until it changes.
    next_clipboard_viewer: ?win32.HWND, // we're using the old api to watch the clipboard.
    clipboard_text: ?[]u8,
};

pub const Internals = struct {
    monitor_store: MonitorStore,
    dev_notif_handle: *anyopaque,
    helper_data: HelperData,
    helper_window: win32.HWND,
    const HELPER_TITLE = "WIDOW_HELPER";
    const Self = @This();

    pub fn create(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);
        const win32_singelton = Win32Driver.singleton();
        self.helper_window = try createHelperWindow(win32_singelton.handles.hinstance);
        errdefer _ = window_msg.DestroyWindow(self.helper_window);
        self.helper_data.clipboard_change = false;
        self.helper_data.clipboard_text = null;
        self.helper_data.next_clipboard_viewer = try clipboard.registerClipboardViewer(self.helper_window);
        self.helper_data.monitor_store_ptr = null;
        registerDevicesNotif(self.helper_window, &self.dev_notif_handle);

        _ = window_msg.SetWindowLongPtrW(
            self.helper_window,
            window_msg.GWLP_USERDATA,
            @intCast(@intFromPtr(&self.helper_data)),
        );

        return self;
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        clipboard.unregisterClipboardViewer(self.helper_window, self.helper_data.next_clipboard_viewer);
        _ = sys_service.UnregisterDeviceNotification(self.dev_notif_handle);

        _ = window_msg.SetWindowLongPtrW(
            self.helper_window,
            window_msg.GWLP_USERDATA,
            0,
        );

        _ = window_msg.DestroyWindow(self.helper_window);
        if (self.helper_data.clipboard_text) |text| {
            allocator.free(text);
            self.helper_data.clipboard_text = null;
        }

        if (self.helper_data.monitor_store_ptr) |_| {
            // avoid calling deinit on undefined data.
            self.monitor_store.deinit();
        }

        allocator.destroy(self);
    }

    /// Init the Monitor store member, and update the helper data refrence.
    pub fn initMonitorStoreImpl(self: *Self, allocator: std.mem.Allocator) !*MonitorStore {
        self.monitor_store = try MonitorStore.init(allocator);
        self.helper_data.monitor_store_ptr = &self.monitor_store;
        return &self.monitor_store;
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

    pub inline fn setClipboardText(self: *Self, allocator: std.mem.Allocator, text: []const u8) !void {
        // refetch on the next call to Internals.clipboardText.
        return clipboard.setClipboardText(allocator, self.helper_window, text);
    }
};

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling monitor,clipboard messages related messages.
fn createHelperWindow(hinstance: win32.HINSTANCE) !win32.HWND {
    var buffer: [(Internals.HELPER_TITLE.len) * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const helper_title = utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_TITLE) catch unreachable;

    const helper_window = win32.CreateWindowExW(
        0,
        utils.MAKEINTATOM(Win32Driver.singleton().handles.helper_class),
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

    _ = window_msg.ShowWindow(helper_window, window_msg.SW_HIDE);
    return helper_window;
}

/// Register window to recieve HID notification
fn registerDevicesNotif(helper_window: win32.HWND, dbi_handle: **anyopaque) void {
    var dbi: sys_service.DEV_BROADCAST_DEVICEINTERFACE_A = undefined;
    dbi.dbcc_size = @sizeOf(sys_service.DEV_BROADCAST_DEVICEINTERFACE_A);
    dbi.dbcc_devicetype = @intFromEnum(sys_service.DBT_DEVTYP_DEVICEINTERFACE);
    dbi.dbcc_classguid = win32.GUID_DEVINTERFACE_HID;
    dbi_handle.* = window_msg.RegisterDeviceNotificationW(
        helper_window,
        @ptrCast(&dbi),
        win32.DEVICE_NOTIFY_WINDOW_HANDLE,
    ) orelse unreachable; // Should always succeed.
}

/// create a platform icon.
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

/// Creates a platform cursor.
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

/// Returns a handle to a shared(standard) platform cursor.
pub fn createStandardCursor(shape: common.cursor.StandardCursorShape) !icon.Cursor {
    const CursorShape = common.cursor.StandardCursorShape;

    const cursor_id = switch (shape) {
        CursorShape.PointingHand => win32.IDC_HAND,
        CursorShape.Crosshair => win32.IDC_CROSS,
        CursorShape.Text => win32.IDC_IBEAM,
        CursorShape.BkgrndTask => win32.IDC_APPSTARTING,
        CursorShape.Help => win32.IDC_HELP,
        CursorShape.Busy => win32.IDC_WAIT,
        CursorShape.Forbidden => win32.IDC_NO,
        CursorShape.Move => win32.IDC_SIZEALL,
        CursorShape.Default => win32.IDC_ARROW,
    };

    const handle = window_msg.LoadImageA(
        null,
        cursor_id,
        window_msg.GDI_IMAGE_TYPE.CURSOR,
        0,
        0,
        @enumFromInt(@intFromEnum(window_msg.LR_DEFAULTSIZE) |
            @intFromEnum(window_msg.LR_SHARED)),
    );

    if (handle == null) {
        // We failed.
        std.debug.print("error {}\n", .{utils.getLastError()});
        return error.FailedToLoadStdCursor;
    }

    return icon.Cursor{ .handle = @ptrCast(handle), .shared = true, .mode = common.cursor.CursorMode.Normal };
}

pub const MonitorStore = struct {
    monitors: std.ArrayList(monitor_impl.MonitorImpl),
    used_monitors: u8,
    expected_video_change: bool, // For skipping unnecessary updates.
    prev_exec_state: sys_power.EXECUTION_STATE,
    const Self = @This();

    /// Initialize the `MonitorStore` struct.
    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .used_monitors = 0,
            .expected_video_change = false,
            .prev_exec_state = sys_power.ES_SYSTEM_REQUIRED,
            .monitors = try monitor_impl.pollMonitors(allocator),
        };
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

    /// Returns a refrence to the requested Monitor.
    pub fn findMonitor(self: *Self, monitor_handle: win32.HMONITOR) !*monitor_impl.MonitorImpl {
        // Find the monitor.
        var target: ?*monitor_impl.MonitorImpl = null;
        for (self.monitors.items) |*item| {
            if (item.handle == monitor_handle) {
                target = item;
                break;
            }
        }
        const monitor = target orelse {
            std.log.err("[MonitorStore]: monitor not found,handle={*}", .{monitor_handle});
            return error_defs.MonitorError.MonitorNotFound;
        };

        return monitor;
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
        const monitor = try self.findMonitor(monitor_handle);

        if (self.used_monitors == 0) {
            const thread_exec_state = comptime @intFromEnum(sys_power.ES_CONTINUOUS) |
                @intFromEnum(sys_power.ES_DISPLAY_REQUIRED);
            // first time acquiring a monitor
            // prevent the system from entering sleep or turning off.
            self.prev_exec_state = sys_power.SetThreadExecutionState(
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
    pub fn releaseMonitor(self: *Self, monitor_handle: win32.HMONITOR) !void {
        const monitor = try self.findMonitor(monitor_handle);
        monitor.setWindow(null);

        self.used_monitors -= 1;
        if (self.used_monitors == 0) {
            _ = sys_power.SetThreadExecutionState(self.prev_exec_state);
        }
    }

    pub fn setMonitorVideoMode(
        self: *Self,
        monitor_handle: win32.HMONITOR,
        mode: ?*common.video_mode.VideoMode,
    ) !void {
        const monitor = try self.findMonitor(monitor_handle);
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
        const monitor = try self.findMonitor(monitor_handle);
        monitor.queryCurrentMode(output);
    }

    pub fn debugInfos(self: *const Self) void {
        if (dbg) {
            for (self.monitors.items) |*monitor| {
                monitor.debugInfos(false);
            }
        }
    }
};

// test "MonitorStore_init()" {
//     const testing = std.testing;
//     var ms = try MonitorStore.init(testing.allocator);
//     try ms.refreshMonitorsMap();
//     defer ms.deinit();
// }
