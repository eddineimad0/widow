const std = @import("std");
const monitor_impl = @import("display.zig");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const keymaps = @import("keymaps.zig");
const X11driver = @import("driver.zig").X11Driver;
const Allocator = std.mem.Allocator;
const HashMapU32 = std.AutoArrayHashMap(u32, u32);
const KeyCode = common.keyboard_mouse.KeyCode;

/// Data our hidden helper window will modify during execution.
pub const HelperData = struct {
    monitor_store_ptr: ?*MonitorStore,
    clipboard_text: ?[]u8,
    keycode_lookup_table: [keymaps.KEYCODE_MAP_SIZE]KeyCode,
    xkeysym_unicode_mapping: HashMapU32,
};

pub const Internals = struct {
    helper_data: HelperData,
    helper_window: libx11.Window,
    monitor_store: MonitorStore,
    const Self = @This();

    pub fn create(allocator: Allocator) Allocator.Error!*Self {
        var self = try allocator.create(Self);
        self.helper_data.clipboard_text = null;
        self.helper_data.monitor_store_ptr = null;
        self.helper_data.xkeysym_unicode_mapping = HashMapU32.init(allocator);

        keymaps.initKeyCodeTable(&self.helper_data.keycode_lookup_table);
        try keymaps.initUnicodeKeysymMapping(&self.helper_data.xkeysym_unicode_mapping);
        // last thing to do is create a helper window
        self.helper_window = try createHelperWindow(&self.helper_data);
        return self;
    }

    pub fn destroy(self: *Self, allocator: Allocator) void {
        const x11driver = X11driver.singleton();
        _ = x11driver.removeFromXContext(self.helper_window);
        _ = libx11.XDestroyWindow(x11driver.handles.xdisplay, self.helper_window);

        self.helper_data.xkeysym_unicode_mapping.deinit();
        if (self.helper_data.clipboard_text) |text| {
            allocator.free(text);
            self.helper_data.clipboard_text = null;
        }

        self.monitor_store.deinit();
        allocator.destroy(self);
    }

    pub inline fn lookupKeyCode(self: *const Self, xkeycode: u8) KeyCode {
        return self.helper_data.keycode_lookup_table[xkeycode];
    }

    pub inline fn lookupKeyCharacter(self: *const Self, xkeysym: libx11.KeySym) ?u32 {
        // Latin-1
        if ((xkeysym <= 0xFF and xkeysym >= 0xA0) or (xkeysym >= 0x20 and xkeysym <= 0x7E)) {
            return @truncate(xkeysym);
        }

        // Latin-1 from Keypad.
        if (xkeysym == 0xFFBD or (xkeysym <= 0xFFB9 and xkeysym >= 0xFFAA)) {
            return @truncate(xkeysym - 0xFF80);
        }

        // Unicode (may be present).
        if ((xkeysym & 0xFF000000) == 0x01000000) {
            return @truncate(xkeysym & 0x00FFFFFF);
        }

        return self.helper_data.xkeysym_unicode_mapping.get(@truncate(xkeysym));
    }

    /// Init the Monitor store member, and update the helper data refrence.
    pub fn initMonitorStoreImpl(self: *Self, allocator: Allocator) Allocator.Error!*MonitorStore {
        self.monitor_store = try MonitorStore.init(allocator);
        self.helper_data.monitor_store_ptr = &self.monitor_store;
        return &self.monitor_store;
    }

    pub fn clipboardText(self: *Self, allocator: Allocator) Allocator.Error![]u8 {
        _ = allocator;
        _ = self;
    }

    pub fn setClipboardText(self: *Self, allocator: Allocator, text: []const u8) Allocator.Error!void {
        _ = text;
        _ = allocator;
        _ = self;
    }
};

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling monitor,clipboard related messages.
fn createHelperWindow(helper_data: *HelperData) !libx11.Window {
    const x11driver = X11driver.singleton();
    var window_attributes: libx11.XSetWindowAttributes = undefined;
    const handle = libx11.XCreateWindow(
        x11driver.handles.xdisplay,
        x11driver.handles.root_window,
        0,
        0,
        1,
        1,
        0,
        0,
        libx11.InputOnly,
        libx11.DefaultVisual(x11driver.handles.xdisplay, x11driver.handles.default_screen),
        0,
        @ptrCast(&window_attributes),
    );

    if (!x11driver.addToXContext(
        handle,
        @ptrCast(helper_data),
    )) {}

    return handle;
}

/// create a platform icon.
pub fn createIcon(
    pixels: ?[]const u8,
    width: i32,
    height: i32,
) !void {
    _ = height;
    _ = width;
    _ = pixels;
}

/// Creates a platform cursor.
pub fn createCursor(
    pixels: ?[]const u8,
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
}

/// Returns a handle to a shared(standard) platform cursor.
pub fn createStandardCursor(shape: common.cursor.StandardCursorShape) !void {
    _ = shape;
    const CursorShape = common.cursor.StandardCursorShape;
    _ = CursorShape;

    // const cursor_id = switch (shape) {
    //     CursorShape.PointingHand => win32.IDC_HAND,
    //     CursorShape.Crosshair => win32.IDC_CROSS,
    //     CursorShape.Text => win32.IDC_IBEAM,
    //     CursorShape.BkgrndTask => win32.IDC_APPSTARTING,
    //     CursorShape.Help => win32.IDC_HELP,
    //     CursorShape.Busy => win32.IDC_WAIT,
    //     CursorShape.Forbidden => win32.IDC_NO,
    //     CursorShape.Move => win32.IDC_SIZEALL,
    //     CursorShape.Default => win32.IDC_ARROW,
    // };
}

pub const MonitorStoreError = error{};
pub const MonitorStore = struct {
    monitors: std.ArrayList(monitor_impl.MonitorImpl),
    used_monitors: u8,
    const Self = @This();

    /// Initialize the `MonitorStore` struct.
    pub fn init(allocator: Allocator) Allocator.Error!Self {
        return .{
            .used_monitors = 0,
            .monitors = try monitor_impl.pollMonitors(allocator),
        };
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

    /// Returns a refrence to the requested Monitor or an error if the monitor was not found.
    pub fn findMonitor(self: *Self, monitor_handle: x11ext.RRCrtc) ?*monitor_impl.MonitorImpl {
        // Find the monitor.
        var target: ?*monitor_impl.MonitorImpl = null;
        for (self.monitors.items) |*item| {
            if (item.handle == monitor_handle) {
                target = item;
                break;
            }
        }

        return target;
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
