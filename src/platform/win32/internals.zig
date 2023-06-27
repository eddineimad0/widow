const std = @import("std");
const window_proc = @import("./window_proc.zig");
const module = @import("./module.zig");
const utils = @import("./utils.zig");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32.zig");
const monitor_impl = @import("./monitor_impl.zig");
const icon = @import("./icon.zig");
const clipboard = @import("./clipboard.zig");
const common = @import("common");
const win32_sysinfo = zigwin32.system.system_information;
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const win32_system_power = zigwin32.system.power;
const win32_sys_service = zigwin32.system.system_services;
const WindowImpl = @import("window_impl.zig").WindowImpl;
const JoystickSubSystem = @import("joystick_impl.zig").JoystickSubSystem;
const CursorShape = common.cursor.CursorShape;

const proc_SetProcessDPIAware = *const fn () callconv(win32.WINAPI) win32.BOOL;

const proc_RtlVerifyVersionInfo = *const fn (*win32.OSVERSIONINFOEXW, u32, u64) callconv(win32.WINAPI) win32.NTSTATUS;

const proc_SetProcessDpiAwareness = *const fn (win32.PROCESS_DPI_AWARENESS) callconv(win32.WINAPI) win32.HRESULT;

const proc_SetProcessDpiAwarenessContext = *const fn (win32.DPI_AWARENESS_CONTEXT) callconv(win32.WINAPI) win32.HRESULT;

pub const proc_EnableNonClientDpiScaling = *const fn (win32.HWND) callconv(win32.WINAPI) win32.BOOL;

pub const proc_GetDpiForWindow = *const fn (win32.HWND) callconv(win32.WINAPI) win32.DWORD;

pub const proc_GetDpiForMonitor = *const fn (
    win32.HMONITOR,
    win32.MONITOR_DPI_TYPE,
    *u32,
    *u32,
) callconv(win32.WINAPI) win32.HRESULT;

pub const proc_AdjustWindowRectExForDpi = *const fn (
    *win32.RECT,
    u32,
    i32,
    u32,
    u32,
) callconv(win32.WINAPI) win32.BOOL;

const Win32Flags = struct {
    is_win_vista_or_above: bool,
    is_win7_or_above: bool,
    is_win8point1_or_above: bool,
    is_win10b1607_or_above: bool,
    is_win10b1703_or_above: bool,
};

const Win32Handles = struct {
    main_class: u16,
    helper_class: u16,
    helper_window: win32.HWND,
    dev_notif: *anyopaque,
    ntdll: ?win32.HINSTANCE,
    user32: ?win32.HINSTANCE,
    shcore: ?win32.HINSTANCE,
    hinstance: win32.HINSTANCE, // the hinstance of the process
};

const LoadedFunctions = struct {
    RtlVerifyVersionInfo: ?proc_RtlVerifyVersionInfo,
    SetProcessDPIAware: ?proc_SetProcessDPIAware,
    SetProcessDpiAwareness: ?proc_SetProcessDpiAwareness,
    SetProcessDpiAwarenessContext: ?proc_SetProcessDpiAwarenessContext,
    GetDpiForMonitor: ?proc_GetDpiForMonitor,
    GetDpiForWindow: ?proc_GetDpiForWindow,
    AdjustWindowRectExForDpi: ?proc_AdjustWindowRectExForDpi,
    EnableNonClientDpiScaling: ?proc_EnableNonClientDpiScaling,
};

const Win32 = struct {
    flags: Win32Flags,
    handles: Win32Handles,
    functions: LoadedFunctions,
};

pub const InternalError = error{
    WNDCLASSNotRegistered,
    MonitorNotFound,
    FailedToLoadNtdll,
    FailedToCreateHelper,
};

pub const MonitorStore = struct {
    monitors_map: std.AutoArrayHashMap(win32.HMONITOR, monitor_impl.MonitorImpl),
    used_monitors: u8,
    expected_video_change: bool, // For skipping unnecessary updates.
    prev_exec_state: win32_system_power.EXECUTION_STATE,
    const Self = @This();

    /// Initialize the `MonitorStore` struct.
    pub fn create(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);
        self.* = Self{
            .monitors_map = std.AutoArrayHashMap(win32.HMONITOR, monitor_impl.MonitorImpl).init(allocator),
            .used_monitors = 0,
            .expected_video_change = false,
            .prev_exec_state = win32_system_power.ES_SYSTEM_REQUIRED,
        };

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
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        self.expected_video_change = true;
        for (self.monitors_map.values()) |*monitor| {
            if (monitor.window) |*window| {
                window.*.requestRestore();
            }
            monitor.deinit();
        }
        self.monitors_map.deinit();
        allocator.destroy(self);
    }

    /// Updates the monitor map by removing all disconnected monitors
    /// and adding new connected ones.
    /// # Note
    /// the update is very slow but it's only triggered if a monitor was connected, or disconnected.
    pub fn updateMonitors(self: *Self) !void {
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
                // Free the name pointer.
                if (monitor.window) |*window| {
                    window.*.requestRestore();
                }
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

    pub fn setMonitorWindow(
        self: *Self,
        monitor_handle: win32.HMONITOR,
        window: *WindowImpl,
        mode: ?*const common.video_mode.VideoMode,
        monitor_area: *common.geometry.WidowArea,
    ) !void {
        const monitor = self.monitors_map.getPtr(monitor_handle) orelse {
            return;
        };

        // ChangeDisplaySettigns sends a WM_DISPLAYCHANGED message
        // We Set this here to avoid wastefully updating the monitors map.
        self.expected_video_change = true;
        defer self.expected_video_change = false;
        try monitor.setVideoMode(mode);

        if (self.used_monitors == 0) {
            const thread_exec_state = comptime @enumToInt(win32_system_power.ES_CONTINUOUS) | @enumToInt(win32_system_power.ES_DISPLAY_REQUIRED);
            // first time acquiring a  monitor
            // prevent the system from entering sleep or turning off.
            self.prev_exec_state = win32_system_power.SetThreadExecutionState(@intToEnum(win32_system_power.EXECUTION_STATE, thread_exec_state));
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
        monitor.fullscreenArea(monitor_area);
    }

    /// Called by the window instance to release any occupied monitor
    pub fn restoreMonitor(self: *Self, monitor_handle: win32.HMONITOR) !void {
        const monitor = self.monitors_map.getPtr(monitor_handle) orelse {
            return InternalError.MonitorNotFound;
        };
        monitor.setWindow(null);

        self.expected_video_change = true;
        defer self.expected_video_change = false;
        monitor.restoreOrignalVideo();

        self.used_monitors -= 1;
        if (self.used_monitors == 0) {
            _ = win32_system_power.SetThreadExecutionState(self.prev_exec_state);
        }
    }
};

pub const DeviceContext = struct {
    monitor_store: ?*MonitorStore,
    joystick_store: ?*JoystickSubSystem,
    clipboard_change: bool, // So we can cache the clipboard value until it changes.
    next_clipboard_viewer: ?win32.HWND, // we're using the old api to watch the clipboard.
    clipboard_text: ?[]u8,
};

pub const Internals = struct {
    win32: Win32,
    devices: DeviceContext,
    // TODO: can we change this to a user comptime string.
    pub const WINDOW_CLASS_NAME = "WIDOW";
    const HELPER_CLASS_NAME = WINDOW_CLASS_NAME ++ "_HELPER";
    const HELPER_TITLE = "";
    const Self = @This();

    pub fn create(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Determine the current HInstance.
        self.win32.handles.hinstance = try module.getProcessHandle();
        // Register the window class
        self.win32.handles.main_class = try registerWindowClass(
            self.win32.handles.hinstance,
        );

        errdefer {
            var buffer: [Internals.WINDOW_CLASS_NAME.len * 5]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const fballocator = fba.allocator();
            // Shoudln't fail since the buffer is big enough.
            const wide_class_name = utils.utf8ToWideZ(fballocator, Internals.WINDOW_CLASS_NAME) catch unreachable;
            _ = win32_window_messaging.UnregisterClassW(
                // utils.makeIntAtom(u8, self.win32.handles.main_class),
                wide_class_name,
                self.win32.handles.hinstance,
            );
        }

        // Load the required libraries.
        try self.loadLibraries();
        errdefer self.freeLibraries();

        // Setup windows version flags.
        if (isWin32VersionMinimum(self.win32.functions.RtlVerifyVersionInfo.?, 6, 0)) {
            self.win32.flags.is_win_vista_or_above = true;

            if (isWin32VersionMinimum(self.win32.functions.RtlVerifyVersionInfo.?, 6, 1)) {
                self.win32.flags.is_win7_or_above = true;

                if (isWin32VersionMinimum(self.win32.functions.RtlVerifyVersionInfo.?, 6, 3)) {
                    self.win32.flags.is_win8point1_or_above = true;

                    if (isWin10BuildMinimum(self.win32.functions.RtlVerifyVersionInfo.?, 1607)) {
                        self.win32.flags.is_win10b1607_or_above = true;

                        if (isWin10BuildMinimum(self.win32.functions.RtlVerifyVersionInfo.?, 1703)) {
                            self.win32.flags.is_win10b1703_or_above = true;
                        }
                    }
                }
            }
        }

        // Declare DPI Awareness.
        // TODO handle errors.
        if (self.win32.flags.is_win10b1703_or_above) {
            _ = self.win32.functions.SetProcessDpiAwarenessContext.?(win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        } else if (self.win32.flags.is_win8point1_or_above) {
            _ = self.win32.functions.SetProcessDpiAwareness.?(win32.PROCESS_PER_MONITOR_DPI_AWARE);
        } else if (self.win32.flags.is_win_vista_or_above) {
            _ = self.win32.functions.SetProcessDPIAware.?();
        }

        try createHelperWindow(self.win32.handles.hinstance, &self.win32.handles.helper_class, &self.win32.handles.helper_window);
        self.devices.joystick_store = null;
        self.devices.clipboard_change = false;
        self.devices.monitor_store = null; // Should be set by the caller.
        self.devices.next_clipboard_viewer = try clipboard.registerClipboardViewer(self.win32.handles.helper_window);
        self.devices.clipboard_text = null;
        registerDevices(self.win32.handles.helper_window, &self.win32.handles.dev_notif, &self.devices);
        return self;
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {

        // Free the loaded modules.
        self.freeLibraries();

        _ = win32_sys_service.UnregisterDeviceNotification(self.win32.handles.dev_notif);

        // Clear up the Devices refrence
        _ = win32_window_messaging.SetWindowLongPtrW(self.win32.handles.helper_window, win32_window_messaging.GWLP_USERDATA, 0);

        _ = win32_window_messaging.DestroyWindow(self.win32.handles.helper_window);

        var buffer: [(Internals.WINDOW_CLASS_NAME.len + Internals.HELPER_CLASS_NAME.len) * 5]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const fballocator = fba.allocator();
        // Shoudln't fail since the buffer is big enough.
        const wide_class_name = utils.utf8ToWideZ(fballocator, Internals.WINDOW_CLASS_NAME) catch unreachable;
        // Shoudln't fail since the buffer is big enough.
        const helper_class_name = utils.utf8ToWideZ(fballocator, Internals.HELPER_CLASS_NAME) catch unreachable;

        // Unregister the helper class.
        _ = win32_window_messaging.UnregisterClassW(
            // utils.makeIntAtom(u8, self.win32.handles.helper_class),
            helper_class_name,
            self.win32.handles.hinstance,
        );

        // Unregister the window class.
        _ = win32_window_messaging.UnregisterClassW(
            // utils.makeIntAtom(u8, self.win32.handles.main_class),
            wide_class_name,
            self.win32.handles.hinstance,
        );

        if (self.devices.clipboard_text) |text| {
            allocator.free(text);
            self.devices.clipboard_text = null;
        }

        clipboard.unregisterClipboardViewer(self.win32.handles.helper_window, self.devices.next_clipboard_viewer);

        allocator.destroy(self);
    }

    pub inline fn clipboardText(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        if (self.devices.clipboard_change or self.devices.clipboard_text == null) {
            // refetching clipboard data
            if (self.devices.clipboard_text) |text| {
                allocator.free(text);
                errdefer self.devices.clipboard_text = null;
            }
            self.devices.clipboard_text = try clipboard.clipboardText(allocator, self.win32.handles.helper_window);
            self.devices.clipboard_change = false;
        }
        return self.devices.clipboard_text.?;
    }

    pub inline fn setClipboardText(self: *Self, allocator: std.mem.Allocator, text: []const u8) !void {
        // refetch on the next call to Internals.clipboardText.
        return clipboard.setClipboardText(allocator, self.win32.handles.helper_window, text);
    }

    fn loadLibraries(self: *Self) !void {
        self.win32.handles.ntdll = module.loadWin32Module("ntdll.dll");
        if (self.win32.handles.ntdll) |*ntdll| {
            self.win32.functions.RtlVerifyVersionInfo = @ptrCast(proc_RtlVerifyVersionInfo, module.getModuleSymbol(ntdll.*, "RtlVerifyVersionInfo"));
        } else {
            // It's important for this module to be loaded since
            // it has the necessary function for figuring out
            // what windows version the system is runing
            // said version is used later to dynamically
            // select which code we run in certain sections.
            return InternalError.FailedToLoadNtdll;
        }
        self.win32.handles.user32 = module.loadWin32Module("user32.dll");
        if (self.win32.handles.user32) |*user32| {
            self.win32.functions.SetProcessDPIAware =
                @ptrCast(proc_SetProcessDPIAware, module.getModuleSymbol(user32.*, "SetProcessDPIAware"));
            self.win32.functions.SetProcessDpiAwarenessContext =
                @ptrCast(proc_SetProcessDpiAwarenessContext, module.getModuleSymbol(user32.*, "SetProcessDpiAwarenessContext"));
            self.win32.functions.GetDpiForWindow =
                @ptrCast(proc_GetDpiForWindow, module.getModuleSymbol(user32.*, "GetDpiForWindow"));
            self.win32.functions.EnableNonClientDpiScaling =
                @ptrCast(proc_EnableNonClientDpiScaling, module.getModuleSymbol(user32.*, "EnableNonClientDpiScaling"));
            self.win32.functions.AdjustWindowRectExForDpi =
                @ptrCast(proc_AdjustWindowRectExForDpi, module.getModuleSymbol(user32.*, "AdjustWindowRectExForDpi"));
        }
        self.win32.handles.shcore = module.loadWin32Module("Shcore.dll");
        if (self.win32.handles.shcore) |*shcore| {
            self.win32.functions.GetDpiForMonitor = @ptrCast(proc_GetDpiForMonitor, module.getModuleSymbol(shcore.*, "GetDpiForMonitor"));
            self.win32.functions.SetProcessDpiAwareness = @ptrCast(proc_SetProcessDpiAwareness, module.getModuleSymbol(shcore.*, "SetProcessDpiAwareness"));
        }
    }

    fn freeLibraries(self: *Self) void {
        if (self.win32.handles.ntdll) |*handle| {
            module.freeWin32Module(handle.*);
            self.win32.handles.ntdll = null;
            self.win32.functions.RtlVerifyVersionInfo = null;
        }
        if (self.win32.handles.user32) |*handle| {
            module.freeWin32Module(handle.*);
            self.win32.handles.user32 = null;
            self.win32.functions.SetProcessDPIAware = null;
            self.win32.functions.SetProcessDpiAwarenessContext = null;
            self.win32.functions.GetDpiForWindow = null;
            self.win32.functions.EnableNonClientDpiScaling = null;
            self.win32.functions.AdjustWindowRectExForDpi = null;
        }
        if (self.win32.handles.shcore) |*handle| {
            module.freeWin32Module(handle.*);
            self.win32.handles.shcore = null;
            self.win32.functions.SetProcessDpiAwareness = null;
            self.win32.functions.GetDpiForMonitor = null;
        }
    }
};

fn isWin32VersionMinimum(proc: proc_RtlVerifyVersionInfo, major: u32, minor: u32) bool {
    //If you must require a particular operating system,
    //be sure to use it as a minimum supported version,
    //rather than design the test for the one operating system.
    //This way, your detection code will continue to work on future versions of Windows.
    var vi: win32_sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = major;
    vi.dwMinorVersion = minor;
    const mask =
        @enumToInt(win32_sysinfo.VER_MAJORVERSION) |
        @enumToInt(win32_sysinfo.VER_MINORVERSION) |
        @enumToInt(win32_sysinfo.VER_SERVICEPACKMAJOR) |
        @enumToInt(win32_sysinfo.VER_SERVICEPACKMINOR);
    var cond_mask: u64 = 0;
    cond_mask = win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_MAJORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask = win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_MINORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask =
        win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_SERVICEPACKMAJOR,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask =
        win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_SERVICEPACKMINOR,
        win32.VER_GREATER_EQUAL,
    );
    // `VerifyVersionInfoW(&mut vi, mask, cond_mask) == TRUE`
    // Subject to windows manifestation on 8.1 or above
    // thus reporting false information for compatibility with older software.
    return proc(&vi, mask, cond_mask) == win32.NTSTATUS.SUCCESS; // STATUS_SUCCESS
}

fn isWin10BuildMinimum(proc: proc_RtlVerifyVersionInfo, build: u32) bool {
    var vi: win32_sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = 10;
    vi.dwMinorVersion = 0;
    vi.dwBuildNumber = build;
    const mask = @enumToInt(win32_sysinfo.VER_MAJORVERSION) | @enumToInt(win32_sysinfo.VER_MINORVERSION) |
        @enumToInt(win32_sysinfo.VER_BUILDNUMBER);
    var cond_mask: u64 = 0;
    cond_mask = win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_MAJORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask = win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_MINORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask = win32_sysinfo.VerSetConditionMask(
        cond_mask,
        win32_sysinfo.VER_BUILDNUMBER,
        win32.VER_GREATER_EQUAL,
    );
    return proc(&vi, mask, cond_mask) == win32.NTSTATUS.SUCCESS; // STATUS_SUCCESS
}

fn registerWindowClass(
    hinstance: win32.HINSTANCE,
) !u16 {
    const IMAGE_ICON = win32_window_messaging.GDI_IMAGE_TYPE.ICON;
    var window_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    window_class.style = @intToEnum(win32_window_messaging.WNDCLASS_STYLES, @enumToInt(win32_window_messaging.CS_HREDRAW) | @enumToInt(win32_window_messaging.CS_VREDRAW) | @enumToInt(win32_window_messaging.CS_OWNDC));
    window_class.lpfnWndProc = window_proc.windowProc;
    window_class.hInstance = hinstance;
    window_class.hCursor = win32_window_messaging.LoadCursorW(null, win32_window_messaging.IDC_ARROW);
    var buffer: [Internals.WINDOW_CLASS_NAME.len * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), Internals.WINDOW_CLASS_NAME) catch unreachable;
    window_class.lpszClassName = wide_class_name;
    // TODO :load ressource icon
    window_class.hIcon = null;
    if (window_class.hIcon == null) {
        // No Icon was provided or we failed.
        window_class.hIcon = @ptrCast(?win32_window_messaging.HICON, win32_window_messaging.LoadImageW(
            null,
            win32_window_messaging.IDI_APPLICATION,
            IMAGE_ICON,
            0,
            0,
            @intToEnum(win32_window_messaging.IMAGE_FLAGS, @enumToInt(win32_window_messaging.LR_SHARED) | @enumToInt(win32_window_messaging.LR_DEFAULTSIZE)),
        ));
    }
    const class = win32_window_messaging.RegisterClassExW(&window_class);
    if (class == 0) {
        return InternalError.WNDCLASSNotRegistered;
    }
    return class;
}

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling hardware related messages.
fn createHelperWindow(hinstance: win32.HINSTANCE, helper_handle: *u16, helper_window: *win32.HWND) !void {
    var helper_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    helper_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    helper_class.style = win32_window_messaging.CS_OWNDC;
    helper_class.lpfnWndProc = window_proc.helperWindowProc;
    helper_class.hInstance = hinstance;
    // Estimate five times the curent utf8 string len.
    var buffer: [(Internals.HELPER_CLASS_NAME.len + Internals.HELPER_TITLE.len) * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_CLASS_NAME) catch unreachable;
    helper_class.lpszClassName = wide_class_name;
    helper_handle.* = win32_window_messaging.RegisterClassExW(&helper_class);
    if (helper_handle.* == 0) {
        return InternalError.FailedToCreateHelper;
    }
    errdefer {
        _ = win32_window_messaging.UnregisterClassW(
            // utils.makeIntAtom(u16, helper_handle.*),
            wide_class_name,
            hinstance,
        );
    }

    const helper_title = try utils.utf8ToWideZ(fba.allocator(), Internals.HELPER_TITLE);
    helper_window.* = win32_window_messaging.CreateWindowExW(
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
        return InternalError.FailedToCreateHelper;
    };

    _ = win32_window_messaging.ShowWindow(helper_window.*, win32_window_messaging.SW_HIDE);
}

fn registerDevices(helper_window: win32.HWND, dbi_handle: **anyopaque, devices: *DeviceContext) void {
    // Drivers for HID collections register instances of this device interface
    // class to notify the operating system and applications of the presence of HID collections.

    _ = win32_window_messaging.SetWindowLongPtrW(helper_window, win32_window_messaging.GWLP_USERDATA, @intCast(isize, @ptrToInt(devices)));

    // Register window to recieve HID notification
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
// TODO try OCR_
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

// test "Internals.init()" {
//     const testing = std.testing;
//     var result = try Internals.create(testing.allocator);
//     registerDevices(result.win32.handles.helper_window, &result.devices);
//     defer result.destroy(testing.allocator);
// }
//
// test "MonitorStore.init()" {
//     const VideoMode = @import("common").video_mode.VideoMode;
//     const testing = std.testing;
//     var ph_dev = try MonitorStore.create(testing.allocator);
//     defer ph_dev.destroy();
//     var all_monitors = try monitor_impl.pollMonitors(testing.allocator);
//     defer {
//         for (all_monitors.items) |*monitor| {
//             // monitors contain heap allocated data that need
//             // to be freed.
//             monitor.deinit();
//         }
//         all_monitors.deinit();
//     }
//     var main_monitor = all_monitors.items[0];
//     try ph_dev.updateMonitors();
//     var primary_monitor = ph_dev.monitors_map.getPtr(main_monitor.handle).?;
//     const mode = VideoMode.init(1600, 900, 32, 60);
//     try primary_monitor.*.setVideoMode(&mode);
//     std.time.sleep(std.time.ns_per_s * 3);
//     std.debug.print("Restoring Original Mode....\n", .{});
//     primary_monitor.*.restoreOrignalVideo();
// }
