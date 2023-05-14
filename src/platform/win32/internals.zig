const std = @import("std");
const defs = @import("./defs.zig");
const module = @import("./module.zig");
const utils = @import("./utils.zig");
const winapi = @import("win32");
const monitor_impl = @import("./monitor_impl.zig");
const win32_sysinfo = winapi.system.system_information;
const win32_window_messaging = winapi.ui.windows_and_messaging;
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
    helper_window: ?HWND,
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
    FailedToSetDPIAwareness,
    FailedToCreateHelperWindow,
    FailedToRegisterWindowClass,
};

pub const PhysicalDevices = struct {
    monitors_map: std.AutoArrayHashMap(HMONITOR, monitor_impl.MonitorImpl),
    used_monitors: u8,
    expected_video_change: bool, // For skipping unwanted updates.
    allocator: std.mem.Allocator,
    const Self = @This();

    /// Initialize the `PhysicalDevices` struct.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .monitors_map = std.AutoArrayHashMap(HMONITOR, monitor_impl.MonitorImpl).init(allocator),
            .used_monitors = 0,
            .expected_video_change = false,
            .allocator = allocator,
        };
        var monitors = try monitor_impl.poll_monitors(allocator);
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

    /// Deinitialize the `PhysicalDevices` struct.
    /// this frees the monitors map and invalidate all monitors refrence.
    pub fn deinit(self: *Self) void {
        for (self.monitors_map.values()) |*monitor| {
            monitor.deinit();
        }
        self.monitors_map.deinit();
    }

    /// Updates the monitor map by removing all disconnected monitors
    /// and adding new connected ones.
    pub fn update_monitors(self: *Self) !void {
        const all_monitors = try monitor_impl.poll_monitors(self.allocator);
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

const Internals = struct {
    win32: Win32,

    const Self = @This();

    pub fn init() !Self {
        var self: Self = undefined;

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
        self.win32.handles.main_class = try register_window_class(
            self.win32.handles.hinstance,
        );

        errdefer {
            _ = win32_window_messaging.UnregisterClassW(
                utils.make_int_atom(u16, self.win32.handles.main_class),
                self.win32.handles.hinstance,
            );
        }

        // Load the required libraries.
        try self.load_libraries();
        errdefer self.free_libraries();
        // Setup windows version flags.
        if (is_win32_version_minimum(self.win32.functions.RtlVerifyVersionInfo.?, 6, 0)) {
            self.win32.flags.is_win_vista_or_above = true;

            if (is_win32_version_minimum(self.win32.functions.RtlVerifyVersionInfo.?, 6, 1)) {
                self.win32.flags.is_win7_or_above = true;

                if (is_win32_version_minimum(self.win32.functions.RtlVerifyVersionInfo.?, 6, 3)) {
                    self.win32.flags.is_win8point1_or_above = true;

                    if (is_win10_build_minimum(self.win32.functions.RtlVerifyVersionInfo.?, 1607)) {
                        self.win32.flags.is_win10b1607_or_above = true;

                        if (is_win10_build_minimum(self.win32.functions.RtlVerifyVersionInfo.?, 1703)) {
                            self.win32.flags.is_win10b1703_or_above = true;
                        }
                    }
                }
            }
        }
        // Declare DPI Awareness.
        if (self.win32.flags.is_win10b1703_or_above) {
            const result = self.win32.functions.SetProcessDpiAwarenessContext.?(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
            if (result == 0) {
                return InternalError.FailedToSetDPIAwareness;
            }
        } else if (self.win32.flags.is_win8point1_or_above) {
            const result = self.win32.functions.SetProcessDpiAwareness.?(PROCESS_PER_MONITOR_DPI_AWARE);
            if (result != 0) {
                return InternalError.FailedToSetDPIAwareness;
            }
        } else if (self.win32.flags.is_win_vista_or_above) {
            const result = self.win32.functions.SetProcessDPIAware.?();
            if (result == 0) {
                return InternalError.FailedToSetDPIAwareness;
            }
        }
        try create_helper_window(self.win32.handles.hinstance, &self.win32.handles.helper_class, &self.win32.handles.helper_window);

        // Poll the current connected monitors.
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
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free the loaded modules.
        self.free_libraries();
        // Unregister the window class.
        if (self.win32.handles.main_class != 0) {
            _ = win32_window_messaging.UnregisterClassW(
                utils.make_int_atom(u16, self.win32.handles.main_class),
                self.win32.handles.hinstance,
            );
        }

        if (self.win32.handles.helper_class != 0) {
            if (self.win32.handles.helper_window != null) {
                // Clear up the monitor map refrence
                _ = win32_window_messaging.SetWindowLongPtrW(self.win32.handles.helper_window, win32_window_messaging.GWLP_USERDATA, 0);
                _ = win32_window_messaging.DestroyWindow(self.win32.handles.helper_window);
            }
            _ = win32_window_messaging.UnregisterClassW(
                utils.make_int_atom(u16, self.win32.handles.helper_class),
                self.win32.handles.hinstance,
            );
        }
    }

    fn load_libraries(self: *Self) !void {
        self.win32.handles.ntdll = module.load_win32_module("ntdll.dll");
        if (self.win32.handles.ntdll) |*ntdll| {
            self.win32.functions.RtlVerifyVersionInfo = @ptrCast(defs.proc_RtlVerifyVersionInfo, module.get_module_symbol(ntdll.*, "RtlVerifyVersionInfo"));
        } else {
            // It's important for this module to be loaded since
            // it has the necessary function for figuring out
            // what windows version the system is runing
            // said version is used later to dynamically
            // select which code we run in certain sections.
            return error.FailedToLoadNtdll;
        }
        self.win32.handles.user32 = module.load_win32_module("user32.dll");
        if (self.win32.handles.user32) |*user32| {
            self.win32.functions.SetProcessDPIAware =
                @ptrCast(defs.proc_SetProcessDPIAware, module.get_module_symbol(user32.*, "SetProcessDPIAware"));
            self.win32.functions.SetProcessDpiAwarenessContext =
                @ptrCast(defs.proc_SetProcessDpiAwarenessContext, module.get_module_symbol(user32.*, "SetProcessDpiAwarenessContext"));
            self.win32.functions.GetDpiForWindow =
                @ptrCast(defs.proc_GetDpiForWindow, module.get_module_symbol(user32.*, "GetDpiForWindow"));
            self.win32.functions.EnableNonClientDpiScaling =
                @ptrCast(defs.proc_EnableNonClientDpiScaling, module.get_module_symbol(user32.*, "EnableNonClientDpiScaling"));
            self.win32.functions.AdjustWindowRectExForDpi =
                @ptrCast(defs.proc_AdjustWindowRectExForDpi, module.get_module_symbol(user32.*, "AdjustWindowRectExForDpi"));
        }
        self.win32.handles.shcore = module.load_win32_module("Shcore.dll");
        if (self.win32.handles.shcore) |*shcore| {
            self.win32.functions.GetDpiForMonitor = @ptrCast(defs.proc_GetDpiForMonitor, module.get_module_symbol(shcore.*, "GetDpiForMonitor"));
            self.win32.functions.SetProcessDpiAwareness = @ptrCast(defs.proc_SetProcessDpiAwareness, module.get_module_symbol(shcore.*, "SetProcessDpiAwareness"));
        }
    }

    fn free_libraries(self: *Self) void {
        if (self.win32.handles.ntdll) |*handle| {
            module.free_win32_module(handle.*);
            self.win32.handles.ntdll = null;
            self.win32.functions.RtlVerifyVersionInfo = null;
        }
        if (self.win32.handles.user32) |*handle| {
            module.free_win32_module(handle.*);
            self.win32.handles.user32 = null;
            self.win32.functions.SetProcessDPIAware = null;
            self.win32.functions.SetProcessDpiAwarenessContext = null;
            self.win32.functions.GetDpiForWindow = null;
            self.win32.functions.EnableNonClientDpiScaling = null;
            self.win32.functions.AdjustWindowRectExForDpi = null;
        }
        if (self.win32.handles.shcore) |*handle| {
            module.free_win32_module(handle.*);
            self.win32.handles.shcore = null;
            self.win32.functions.SetProcessDpiAwareness = null;
            self.win32.functions.GetDpiForMonitor = null;
        }
    }
};

fn is_win32_version_minimum(proc: defs.proc_RtlVerifyVersionInfo, major: u32, minor: u32) bool {
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

fn is_win10_build_minimum(proc: defs.proc_RtlVerifyVersionInfo, build: u32) bool {
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

fn register_window_class(
    hinstance: module.HINSTANCE,
) !u16 {
    const IMAGE_ICON = win32_window_messaging.GDI_IMAGE_TYPE.ICON;
    var window_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    window_class.style = @intToEnum(win32_window_messaging.WNDCLASS_STYLES, @enumToInt(win32_window_messaging.CS_HREDRAW) | @enumToInt(win32_window_messaging.CS_VREDRAW) | @enumToInt(win32_window_messaging.CS_OWNDC));
    window_class.lpfnWndProc = null;
    window_class.hInstance = hinstance;
    window_class.hCursor = win32_window_messaging.LoadCursorW(null, win32_window_messaging.IDC_ARROW);
    var buffer: [WINDOW_CLASS_NAME.len * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const wide_class_name = try utils.utf8_to_wide(allocator, WINDOW_CLASS_NAME);
    // defer allocator.free(wide_class_name); No need.
    window_class.lpszClassName = wide_class_name.ptr;
    window_class.hIcon = null;
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
fn create_helper_window(hinstance: module.HINSTANCE, helper_handle: *u16, helper_window: *?HWND) !void {
    const HELPER_CLASS_NAME = WINDOW_CLASS_NAME ++ "_HELPER";
    const HELPER_TITLE = "helper window";
    var helper_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    helper_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    helper_class.style = win32_window_messaging.CS_OWNDC;
    helper_class.lpfnWndProc = defs.helper_event_proc;
    helper_class.hInstance = hinstance;
    // Estimate five times the curent utf8 string len.
    var buffer: [(HELPER_CLASS_NAME.len + HELPER_TITLE.len) * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const wide_class_name = try utils.utf8_to_wide(allocator, HELPER_CLASS_NAME);
    // defer allocator.free(wide_class_name);
    helper_class.lpszClassName = wide_class_name;
    helper_handle.* = win32_window_messaging.RegisterClassExW(&helper_class);
    if (helper_handle.* == 0) {
        return InternalError.FailedToCreateHelperWindow;
    }
    errdefer {
        _ = win32_window_messaging.UnregisterClassW(
            utils.make_int_atom(u16, helper_handle.*),
            hinstance,
        );
    }
    const helper_title = try utils.utf8_to_wide(allocator, HELPER_TITLE);
    // defer allocator.free(helper_title);
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
    );

    if (helper_window.* == null) {
        return InternalError.FailedToCreateHelperWindow;
    }

    // let devices_ptr = &mut *(self.devices) as *mut PhysicalDevice as isize;
    //
    // unsafe {
    //     SetWindowLongPtrW(self.win32.helper_window_handle, GWLP_USERDATA, devices_ptr);
    // }

    _ = win32_window_messaging.ShowWindow(helper_window.*, win32_window_messaging.SW_HIDE);
}

test "Internals.init()" {
    var result = try Internals.init();
    defer result.deinit();
}

test "PhysicalDevices.init()" {
    const VideoMode = @import("../../core/video_mode.zig").VideoMode;
    const testing = std.testing;
    var ph_dev = try PhysicalDevices.init(testing.allocator);
    defer ph_dev.deinit();
    var all_monitors = try monitor_impl.poll_monitors(testing.allocator);
    defer {
        for (all_monitors.items) |*monitor| {
            // monitors contain heap allocated data that need
            // to be freed.
            monitor.deinit();
        }
        all_monitors.deinit();
    }
    var main_monitor = all_monitors.items[0];
    try ph_dev.update_monitors();
    var primary_monitor = ph_dev.monitors_map.getPtr(main_monitor.handle).?;
    const mode = VideoMode.init(1600, 900, 32, 60);
    try primary_monitor.*.set_video_mode(&mode);
    std.time.sleep(std.time.ns_per_s * 3);
    std.debug.print("Restoring Original Mode....\n", .{});
    primary_monitor.*.restore_orignal_video();
}
