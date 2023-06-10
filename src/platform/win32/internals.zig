const std = @import("std");
const defs = @import("./defs.zig");
const module = @import("./module.zig");
const utils = @import("./utils.zig");
const WindowImpl = @import("window_impl.zig").WindowImpl;
const winapi = @import("win32");
const monitor_impl = @import("./monitor_impl.zig");
const icon = @import("./icon.zig");
const clipboard = @import("./clipboard.zig");
const common = @import("common");
const CursorShape = common.cursor.CursorShape;

const win32_sysinfo = winapi.system.system_information;
const win32_window_messaging = winapi.ui.windows_and_messaging;
const win32_system_power = winapi.system.power;
const GetModuleHandleExW = winapi.system.library_loader.GetModuleHandleExW;
const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT =
    winapi.system.library_loader.GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS =
    winapi.system.library_loader.GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS;
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = winapi.ui.hi_dpi.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2;
const PROCESS_PER_MONITOR_DPI_AWARE = winapi.ui.hi_dpi.PROCESS_PER_MONITOR_DPI_AWARE;
const VER_GREATER_EQUAL = winapi.system.system_services.VER_GREATER_EQUAL;
const STATUS_SUCCESS = winapi.foundation.STATUS_SUCCESS;
const HWND = winapi.foundation.HWND;
const HMONITOR = winapi.graphics.gdi.HMONITOR;
const CW_USEDEFAULT = win32_window_messaging.CW_USEDEFAULT;

const WINDOW_CLASS_NAME = "WIDOW_CLASS";

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
    helper_window: HWND,
    ntdll: ?module.HINSTANCE,
    user32: ?module.HINSTANCE,
    shcore: ?module.HINSTANCE,
    hinstance: module.HINSTANCE, // the hinstance of the process
};

const LoadedFunctions = struct {
    RtlVerifyVersionInfo: ?defs.proc_RtlVerifyVersionInfo,
    SetProcessDPIAware: ?defs.proc_SetProcessDPIAware,
    SetProcessDpiAwareness: ?defs.proc_SetProcessDpiAwareness,
    SetProcessDpiAwarenessContext: ?defs.proc_SetProcessDpiAwarenessContext,
    GetDpiForMonitor: ?defs.proc_GetDpiForMonitor,
    GetDpiForWindow: ?defs.proc_GetDpiForWindow,
    AdjustWindowRectExForDpi: ?defs.proc_AdjustWindowRectExForDpi,
    EnableNonClientDpiScaling: ?defs.proc_EnableNonClientDpiScaling,
};

const Win32 = struct {
    flags: Win32Flags,
    handles: Win32Handles,
    functions: LoadedFunctions,
};

pub const InternalError = error{
    FailedToGetModuleHandle,
    FailedToCreateHelperWindow,
    FailedToRegisterWindowClass,
};

pub const Win32Context = struct {
    monitors_map: std.AutoArrayHashMap(HMONITOR, monitor_impl.MonitorImpl),
    used_monitors: u8,
    expected_video_change: bool, // For skipping unwanted updates.
    previous_exec_state: win32_system_power.EXECUTION_STATE,
    clipboard_change: bool,
    next_clipboard_viewer: ?HWND,
    const Self = @This();

    /// Initialize the `Win32Context` struct.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .monitors_map = std.AutoArrayHashMap(HMONITOR, monitor_impl.MonitorImpl).init(allocator),
            .used_monitors = 0,
            .expected_video_change = false,
            .previous_exec_state = win32_system_power.ES_SYSTEM_REQUIRED,
            .next_clipboard_viewer = null,
            .clipboard_change = false,
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

    /// Deinitialize the `Win32Context` struct.
    /// this frees the monitors map and invalidate all monitors refrence.
    pub fn deinit(self: *Self) void {
        for (self.monitors_map.values()) |*monitor| {
            monitor.deinit();
        }
        self.monitors_map.deinit();
    }

    /// Updates the monitor map by removing all disconnected monitors
    /// and adding new connected ones.
    pub fn updateMonitors(self: *Self) !void {
        const all_monitors = try monitor_impl.pollMonitors(self.monitors_map.allocator);
        // used in case of an error to free the remaining monitors.
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
};

pub const Internals = struct {
    win32: Win32,
    devices: Win32Context,
    clipboard_text: ?[]u8,
    const Self = @This();

    pub fn create(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Determine the current HInstance.
        var hinstance: ?module.HINSTANCE = null;
        if (GetModuleHandleExW(
            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT | GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
            @intToPtr(?[*:0]const u16, @ptrToInt(&WINDOW_CLASS_NAME)),
            &hinstance,
        ) == 0) {
            return InternalError.FailedToGetModuleHandle;
        }

        self.win32.handles.hinstance = hinstance.?;
        // Register the window class
        self.win32.handles.main_class = try registerWindowClass(
            self.win32.handles.hinstance,
        );

        errdefer {
            _ = win32_window_messaging.UnregisterClassW(
                utils.makeIntAtom(u16, self.win32.handles.main_class),
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
        if (self.win32.flags.is_win10b1703_or_above) {
            _ = self.win32.functions.SetProcessDpiAwarenessContext.?(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        } else if (self.win32.flags.is_win8point1_or_above) {
            _ = self.win32.functions.SetProcessDpiAwareness.?(PROCESS_PER_MONITOR_DPI_AWARE);
        } else if (self.win32.flags.is_win_vista_or_above) {
            _ = self.win32.functions.SetProcessDPIAware.?();
        }

        try createHelperWindow(self.win32.handles.hinstance, &self.win32.handles.helper_class, &self.win32.handles.helper_window);
        self.devices = try Win32Context.init(allocator);
        registerDevices(self.win32.handles.helper_window, &self.devices);
        self.clipboard_text = null;
        self.devices.next_clipboard_viewer = try clipboard.registerClipboardViewer(self.win32.handles.helper_window);
        return self;
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {

        // Free the loaded modules.
        self.freeLibraries();

        // Unregister the window class.
        _ = win32_window_messaging.UnregisterClassW(
            utils.makeIntAtom(u16, self.win32.handles.main_class),
            self.win32.handles.hinstance,
        );

        // Clear up the Devices refrence
        _ = win32_window_messaging.SetWindowLongPtrW(self.win32.handles.helper_window, win32_window_messaging.GWLP_USERDATA, 0);

        _ = win32_window_messaging.DestroyWindow(self.win32.handles.helper_window);

        // Unregister the helper class.
        _ = win32_window_messaging.UnregisterClassW(
            utils.makeIntAtom(u16, self.win32.handles.helper_class),
            self.win32.handles.hinstance,
        );

        if (self.clipboard_text) |text| {
            allocator.free(text);
            self.clipboard_text = null;
        }
        clipboard.unregisterClipboardViewer(self.win32.handles.helper_window, self.devices.next_clipboard_viewer);

        self.devices.deinit();

        allocator.destroy(self);
    }

    pub inline fn clipboardText(self: *Self, allocator: std.mem.Allocator) ![]u8 {
        if (self.devices.clipboard_change or self.clipboard_text == null) {
            // refetching clipboard data
            if (self.clipboard_text) |text| {
                allocator.free(text);
                errdefer self.clipboard_text = null;
            }
            self.clipboard_text = try clipboard.clipboardText(allocator, self.win32.handles.helper_window);
            self.devices.clipboard_change = false;
        }
        return self.clipboard_text.?;
    }

    pub inline fn setClipboardText(self: *Self, allocator: std.mem.Allocator, text: []const u8) !void {
        // refetch on the next call to Internals.clipboardText.
        return clipboard.setClipboardText(allocator, self.win32.handles.helper_window, text);
    }

    pub fn setMonitorWindow(
        self: *Self,
        monitor_handle: HMONITOR,
        window: *WindowImpl,
        mode: ?*const common.video_mode.VideoMode,
        monitor_area: *common.geometry.WidowArea,
    ) !void {
        const monitor = self.devices.monitors_map.getPtr(monitor_handle) orelse {
            return error.MonitorNotFound;
        };

        // ChangeDisplaySettigns sends a WM_DISPLAYCHANGED message
        // We Set this here to avoid wastefully updating the monitors map.
        self.devices.expected_video_change = true;
        try monitor.setVideoMode(mode);
        self.devices.expected_video_change = false;

        if (self.devices.used_monitors == 0) {
            const thread_exec_state = comptime @enumToInt(win32_system_power.ES_CONTINUOUS) | @enumToInt(win32_system_power.ES_DISPLAY_REQUIRED);
            // first time acquiring a  monitor
            // prevent the system from entering sleep or turning off.
            self.devices.previous_exec_state = win32_system_power.SetThreadExecutionState(@intToEnum(win32_system_power.EXECUTION_STATE, thread_exec_state));
        } else {
            if (monitor.window) |old_window| {
                if (window.handle != old_window.handle) {
                    old_window.requestRestore();
                }
                self.devices.used_monitors -= 1;
            }
        }

        monitor.setWindow(window);
        self.devices.used_monitors += 1;
        monitor.fullscreenArea(monitor_area);
    }

    pub fn restoreMonitor(self: *Self, monitor_handle: HMONITOR) !void {
        const monitor = self.devices.monitors_map.getPtr(monitor_handle) orelse {
            return error.MonitorNotFound;
        };
        monitor.setWindow(null);
        if (monitor.mode_changed) {
            self.devices.expected_video_change = true;
            monitor.restoreOrignalVideo();
            self.devices.expected_video_change = false;
        }
        self.devices.used_monitors -= 1;
        if (self.devices.used_monitors == 0) {
            _ = win32_system_power.SetThreadExecutionState(self.devices.previous_exec_state);
        }
    }

    fn loadLibraries(self: *Self) !void {
        self.win32.handles.ntdll = module.loadWin32Module("ntdll.dll");
        if (self.win32.handles.ntdll) |*ntdll| {
            self.win32.functions.RtlVerifyVersionInfo = @ptrCast(defs.proc_RtlVerifyVersionInfo, module.getModuleSymbol(ntdll.*, "RtlVerifyVersionInfo"));
        } else {
            // It's important for this module to be loaded since
            // it has the necessary function for figuring out
            // what windows version the system is runing
            // said version is used later to dynamically
            // select which code we run in certain sections.
            return error.FailedToLoadNtdll;
        }
        self.win32.handles.user32 = module.loadWin32Module("user32.dll");
        if (self.win32.handles.user32) |*user32| {
            self.win32.functions.SetProcessDPIAware =
                @ptrCast(defs.proc_SetProcessDPIAware, module.getModuleSymbol(user32.*, "SetProcessDPIAware"));
            self.win32.functions.SetProcessDpiAwarenessContext =
                @ptrCast(defs.proc_SetProcessDpiAwarenessContext, module.getModuleSymbol(user32.*, "SetProcessDpiAwarenessContext"));
            self.win32.functions.GetDpiForWindow =
                @ptrCast(defs.proc_GetDpiForWindow, module.getModuleSymbol(user32.*, "GetDpiForWindow"));
            self.win32.functions.EnableNonClientDpiScaling =
                @ptrCast(defs.proc_EnableNonClientDpiScaling, module.getModuleSymbol(user32.*, "EnableNonClientDpiScaling"));
            self.win32.functions.AdjustWindowRectExForDpi =
                @ptrCast(defs.proc_AdjustWindowRectExForDpi, module.getModuleSymbol(user32.*, "AdjustWindowRectExForDpi"));
        }
        self.win32.handles.shcore = module.loadWin32Module("Shcore.dll");
        if (self.win32.handles.shcore) |*shcore| {
            self.win32.functions.GetDpiForMonitor = @ptrCast(defs.proc_GetDpiForMonitor, module.getModuleSymbol(shcore.*, "GetDpiForMonitor"));
            self.win32.functions.SetProcessDpiAwareness = @ptrCast(defs.proc_SetProcessDpiAwareness, module.getModuleSymbol(shcore.*, "SetProcessDpiAwareness"));
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

fn isWin32VersionMinimum(proc: defs.proc_RtlVerifyVersionInfo, major: u32, minor: u32) bool {
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
    cond_mask = win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_MAJORVERSION, VER_GREATER_EQUAL);
    cond_mask = win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_MINORVERSION, VER_GREATER_EQUAL);
    cond_mask =
        win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_SERVICEPACKMAJOR, VER_GREATER_EQUAL);
    cond_mask =
        win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_SERVICEPACKMINOR, VER_GREATER_EQUAL);
    // VerifyVersionInfoW(&mut vi, mask, cond_mask) == TRUE
    // Subject to windows manifestation on 8.1 or above
    // thus reporting false information for compatibility with older software.
    return proc(&vi, mask, cond_mask) == STATUS_SUCCESS;
}

fn isWin10BuildMinimum(proc: defs.proc_RtlVerifyVersionInfo, build: u32) bool {
    var vi: win32_sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = 10;
    vi.dwMinorVersion = 0;
    vi.dwBuildNumber = build;
    const mask = @enumToInt(win32_sysinfo.VER_MAJORVERSION) | @enumToInt(win32_sysinfo.VER_MINORVERSION) |
        @enumToInt(win32_sysinfo.VER_BUILDNUMBER);
    var cond_mask: u64 = 0;
    cond_mask = win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_MAJORVERSION, VER_GREATER_EQUAL);
    cond_mask = win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_MINORVERSION, VER_GREATER_EQUAL);
    cond_mask = win32_sysinfo.VerSetConditionMask(cond_mask, win32_sysinfo.VER_BUILDNUMBER, VER_GREATER_EQUAL);
    return proc(&vi, mask, cond_mask) == STATUS_SUCCESS;
}

fn registerWindowClass(
    hinstance: module.HINSTANCE,
) !u16 {
    const IMAGE_ICON = win32_window_messaging.GDI_IMAGE_TYPE.ICON;
    var window_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    window_class.style = @intToEnum(win32_window_messaging.WNDCLASS_STYLES, @enumToInt(win32_window_messaging.CS_HREDRAW) | @enumToInt(win32_window_messaging.CS_VREDRAW) | @enumToInt(win32_window_messaging.CS_OWNDC));
    window_class.lpfnWndProc = defs.windowProc;
    window_class.hInstance = hinstance;
    window_class.hCursor = win32_window_messaging.LoadCursorW(null, win32_window_messaging.IDC_ARROW);
    var buffer: [WINDOW_CLASS_NAME.len * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const wide_class_name = try utils.utf8ToWideZ(allocator, WINDOW_CLASS_NAME);
    window_class.lpszClassName = wide_class_name.ptr;
    window_class.hIcon = null;
    //     TODO
    //     match icon_id {
    //         // Load icon provided through application's resource definition.
    //         Some(name) => LoadImageW(
    //             hinstance,
    //             utf8_to_wide(name).as_ptr(),
    //             IMAGE_ICON,
    //             0,
    //             0,
    //             LR_SHARED | LR_DEFAULTSIZE,
    //         ),
    //         None => 0,
    //     }
    // };
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
        return InternalError.FailedToRegisterWindowClass;
    }
    return class;
}

/// Create an invisible helper window that lives as long as the internals struct.
/// the helper window is used for handeling hardware related messages.
fn createHelperWindow(hinstance: module.HINSTANCE, helper_handle: *u16, helper_window: *HWND) !void {
    const HELPER_CLASS_NAME = WINDOW_CLASS_NAME ++ "_HELPER";
    const HELPER_TITLE = "helper window";
    var helper_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    helper_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    helper_class.style = win32_window_messaging.CS_OWNDC;
    helper_class.lpfnWndProc = defs.helperWindowProc;
    helper_class.hInstance = hinstance;
    // Estimate five times the curent utf8 string len.
    var buffer: [(HELPER_CLASS_NAME.len + HELPER_TITLE.len) * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const wide_class_name = try utils.utf8ToWideZ(allocator, HELPER_CLASS_NAME);
    helper_class.lpszClassName = wide_class_name;
    helper_handle.* = win32_window_messaging.RegisterClassExW(&helper_class);
    if (helper_handle.* == 0) {
        return InternalError.FailedToCreateHelperWindow;
    }
    errdefer {
        _ = win32_window_messaging.UnregisterClassW(
            utils.makeIntAtom(u16, helper_handle.*),
            hinstance,
        );
    }
    const helper_title = try utils.utf8ToWideZ(allocator, HELPER_TITLE);
    helper_window.* = win32_window_messaging.CreateWindowExW(
        @intToEnum(win32_window_messaging.WINDOW_EX_STYLE, 0),
        wide_class_name,
        helper_title,
        win32_window_messaging.WS_OVERLAPPED,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        null,
        null,
        hinstance,
        null,
    ) orelse {
        return InternalError.FailedToCreateHelperWindow;
    };

    _ = win32_window_messaging.ShowWindow(helper_window.*, win32_window_messaging.SW_HIDE);
}

fn registerDevices(helper_window: HWND, devices: *Win32Context) void {
    _ = win32_window_messaging.SetWindowLongPtrW(helper_window, win32_window_messaging.GWLP_USERDATA, @intCast(isize, @ptrToInt(devices)));

    // TODO
    // Register raw_input_devices
    //
    // self.is_initialized = true;
    // let r_mouse_id = RAWINPUTDEVICE {
    //     usUsagePage: 0x01,
    //     usUsage: 0x02,
    //     dwFlags: 0,
    //     hwndTarget: 0,
    // };
    // let result =
    //     unsafe { RegisterRawInputDevices(&r_mouse_id, 1, size_of_val(&r_mouse_id) as u32) };
    // if result == 0 {
    //     return Err("Failed to register Raw Device".to_owned());
    // }
}

pub fn createStandardCursor(window: *WindowImpl, shape: CursorShape) !void {
    const cursor_id = switch (shape) {
        CursorShape.PointingHand => win32_window_messaging.IDC_HAND,
        CursorShape.Crosshair => win32_window_messaging.IDC_CROSS,
        CursorShape.Text => win32_window_messaging.IDC_IBEAM,
        CursorShape.Wait => win32_window_messaging.IDC_WAIT,
        CursorShape.Help => win32_window_messaging.IDC_HELP,
        CursorShape.Busy => win32_window_messaging.IDC_APPSTARTING,
        CursorShape.Forbidden => win32_window_messaging.IDC_NO,
        else => win32_window_messaging.IDC_ARROW,
    };
    // LoadCursorW takes a handle to an instance of the module
    // whose executable file contains the cursor to be loaded.
    const handle = win32_window_messaging.LoadCursorW(0, cursor_id);
    if (handle == 0) {
        // We failed.
        return error.FailedToLoadStdCursor;
    }
    window.setCursorShape(&icon.Cursor{ .handle = handle, .shared = true, .mode = common.cursor.CursorMode.Normal });
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

test "Internals.init()" {
    const testing = std.testing;
    var result = try Internals.create(testing.allocator);
    registerDevices(result.win32.handles.helper_window, &result.devices);
    defer result.destroy(testing.allocator);
}

test "Win32Context.init()" {
    const VideoMode = @import("common").video_mode.VideoMode;
    const testing = std.testing;
    var ph_dev = try Win32Context.init(testing.allocator);
    defer ph_dev.deinit();
    var all_monitors = try monitor_impl.pollMonitors(testing.allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            // monitors contain heap allocated data that need
            // to be freed.
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    var main_monitor = all_monitors.items[0];
    try ph_dev.updateMonitors();
    var primary_monitor = ph_dev.monitors_map.getPtr(main_monitor.handle).?;
    const mode = VideoMode.init(1600, 900, 32, 60);
    try primary_monitor.*.setVideoMode(&mode);
    std.time.sleep(std.time.ns_per_s * 3);
    std.debug.print("Restoring Original Mode....\n", .{});
    primary_monitor.*.restoreOrignalVideo();
}
