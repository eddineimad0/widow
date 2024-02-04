const std = @import("std");
const win32 = @import("win32_defs.zig");
const zigwin32 = @import("zigwin32");
const module = @import("module.zig");
const utils = @import("utils.zig");
const helperWindowProc = @import("window_proc.zig").helperWindowProc;
const mainWindowProc = @import("window_proc.zig").mainWindowProc;
const win32_sysinfo = zigwin32.system.system_information;
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const WidowError = @import("errors.zig").WidowWin32Error;

const Win32Flags = struct {
    is_win_vista_or_above: bool,
    is_win7_or_above: bool,
    is_win8point1_or_above: bool,
    is_win10b1607_or_above: bool,
    is_win10b1703_or_above: bool,
};

const Win32Handles = struct {
    ntdll: ?win32.HINSTANCE,
    user32: ?win32.HINSTANCE,
    shcore: ?win32.HINSTANCE,
    hinstance: win32.HINSTANCE,
    helper_class: u16,
    wnd_class: u16,
};

const LoadedFunctions = struct {
    RtlVerifyVersionInfo: win32.RtlVerifyVersionInfoProc,
    SetProcessDPIAware: ?win32.SetProcessDPIAwareProc,
    SetProcessDpiAwareness: ?win32.SetProcessDpiAwarenessProc,
    SetProcessDpiAwarenessContext: ?win32.SetProcessDpiAwarenessContextProc,
    GetDpiForMonitor: ?win32.GetDpiForMonitorProc,
    GetDpiForWindow: ?win32.GetDpiForWindowProc,
    AdjustWindowRectExForDpi: ?win32.AdjustWindowRectExForDpiProc,
    EnableNonClientDpiScaling: ?win32.EnableNonClientDpiScalingProc,
};

pub const Win32Context = struct {
    flags: Win32Flags,
    handles: Win32Handles,
    functions: LoadedFunctions,
    var WINDOW_CLASS_NAME: []const u8 = "";
    var HELPER_CLASS_NAME: []const u8 = "";
    var RESOURCE_ICON_NAME: []const u8 = "";
    var mutex: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;

    // A global readonly singelton
    // used to access loaded function, os flag and handles.
    var globl_instance: Win32Context = Win32Context{
        .flags = Win32Flags{
            .is_win_vista_or_above = false,
            .is_win7_or_above = false,
            .is_win8point1_or_above = false,
            .is_win10b1607_or_above = false,
            .is_win10b1703_or_above = false,
        },
        .functions = LoadedFunctions{
            .SetProcessDPIAware = null,
            .SetProcessDpiAwareness = null,
            .SetProcessDpiAwarenessContext = null,
            .GetDpiForMonitor = null,
            .GetDpiForWindow = null,
            .AdjustWindowRectExForDpi = null,
            .EnableNonClientDpiScaling = null,
            .RtlVerifyVersionInfo = undefined,
        },
        .handles = Win32Handles{
            .wnd_class = 0,
            .helper_class = 0,
            .ntdll = null,
            .user32 = null,
            .shcore = null,
            .hinstance = undefined, // the hinstance of the process
        },
    };

    const Self = @This();

    pub fn initSingleton(comptime wnd_class_name: []const u8, comptime res_icon_name: ?[]const u8) !void {
        @setCold(true);
        const g_instance = &Self.globl_instance;

        Self.mutex.lock();
        defer mutex.unlock();

        if (!Self.g_init) {
            g_instance.handles.hinstance = try module.getProcessHandle();

            g_instance.handles.wnd_class = try registerMainClass(
                wnd_class_name,
                res_icon_name,
                g_instance.handles.hinstance,
            );
            g_instance.handles.helper_class = try registerHelperClass(
                wnd_class_name ++ "_HELPER",
                g_instance.handles.hinstance,
            );

            Self.WINDOW_CLASS_NAME = wnd_class_name;
            Self.HELPER_CLASS_NAME = wnd_class_name ++ "_HELPER";
            Self.RESOURCE_ICON_NAME = res_icon_name orelse "";

            // Load the required libraries.
            try g_instance.loadLibraries();
            errdefer g_instance.freeLibraries();

            // Setup windows version flags.
            if (isWin32VersionMinimum(g_instance.functions.RtlVerifyVersionInfo, 6, 0)) {
                g_instance.flags.is_win_vista_or_above = true;

                if (isWin32VersionMinimum(g_instance.functions.RtlVerifyVersionInfo, 6, 1)) {
                    g_instance.flags.is_win7_or_above = true;

                    if (isWin32VersionMinimum(g_instance.functions.RtlVerifyVersionInfo, 6, 3)) {
                        g_instance.flags.is_win8point1_or_above = true;

                        if (isWin10BuildMinimum(g_instance.functions.RtlVerifyVersionInfo, 1607)) {
                            g_instance.flags.is_win10b1607_or_above = true;

                            if (isWin10BuildMinimum(g_instance.functions.RtlVerifyVersionInfo, 1703)) {
                                g_instance.flags.is_win10b1703_or_above = true;
                            }
                        }
                    }
                }
            }

            // Declare Process DPI Awareness.
            if (g_instance.flags.is_win10b1703_or_above) {
                _ = g_instance.functions.SetProcessDpiAwarenessContext.?(win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
            } else if (g_instance.flags.is_win8point1_or_above) {
                _ = g_instance.functions.SetProcessDpiAwareness.?(win32.PROCESS_PER_MONITOR_DPI_AWARE);
            } else if (g_instance.flags.is_win_vista_or_above) {
                _ = g_instance.functions.SetProcessDPIAware.?();
            }

            @atomicStore(bool, &Self.g_init, true, .Release);
        }
    }

    fn loadLibraries(self: *Self) !void {
        self.handles.ntdll = module.loadWin32Module("ntdll.dll");
        if (self.handles.ntdll) |*ntdll| {
            self.functions.RtlVerifyVersionInfo = @ptrCast(
                module.getModuleSymbol(ntdll.*, "RtlVerifyVersionInfo"),
            );
        } else {
            // It's important for this module to be loaded since
            // it has the necessary function for figuring out
            // what windows version the system is runing
            // said version is used later to dynamically
            // select which code we run in certain sections.
            return WidowError.NtdllNotFound;
        }
        self.handles.user32 = module.loadWin32Module("user32.dll");
        if (self.handles.user32) |*user32| {
            self.functions.SetProcessDPIAware =
                @ptrCast(module.getModuleSymbol(user32.*, "SetProcessDPIAware"));
            self.functions.SetProcessDpiAwarenessContext =
                @ptrCast(
                module.getModuleSymbol(user32.*, "SetProcessDpiAwarenessContext"),
            );
            self.functions.GetDpiForWindow =
                @ptrCast(module.getModuleSymbol(user32.*, "GetDpiForWindow"));
            self.functions.EnableNonClientDpiScaling =
                @ptrCast(module.getModuleSymbol(user32.*, "EnableNonClientDpiScaling"));
            self.functions.AdjustWindowRectExForDpi =
                @ptrCast(module.getModuleSymbol(user32.*, "AdjustWindowRectExForDpi"));
        }
        self.handles.shcore = module.loadWin32Module("Shcore.dll");
        if (self.handles.shcore) |*shcore| {
            self.functions.GetDpiForMonitor = @ptrCast(
                module.getModuleSymbol(shcore.*, "GetDpiForMonitor"),
            );
            self.functions.SetProcessDpiAwareness = @ptrCast(
                module.getModuleSymbol(shcore.*, "SetProcessDpiAwareness"),
            );
        }
    }

    fn freeLibraries(self: *Self) void {
        if (self.handles.ntdll) |*handle| {
            module.freeWin32Module(handle.*);
            self.handles.ntdll = null;
        }
        if (self.handles.user32) |*handle| {
            module.freeWin32Module(handle.*);
            self.handles.user32 = null;
            self.functions.SetProcessDPIAware = null;
            self.functions.SetProcessDpiAwarenessContext = null;
            self.functions.GetDpiForWindow = null;
            self.functions.EnableNonClientDpiScaling = null;
            self.functions.AdjustWindowRectExForDpi = null;
        }
        if (self.handles.shcore) |*handle| {
            module.freeWin32Module(handle.*);
            self.handles.shcore = null;
            self.functions.SetProcessDpiAwareness = null;
            self.functions.GetDpiForMonitor = null;
        }
    }

    inline fn WNDClassName() []const u8 {
        return Self.WINDOW_CLASS_NAME;
    }

    // Enfoce readonly.
    pub fn singleton() *const Self {
        std.debug.assert(g_init == true);
        return &Self.globl_instance;
    }

    /// !!! Calling this function Unregister the main WNDCLASS effectively crashing any window
    /// that hasn't been destroyed yet !!!.
    pub fn deinitSingleton() void {
        @setCold(true);
        if (Self.g_init) {
            Self.g_init = false;
            // var buffer: [(Win32Context.HELPER_CLASS_NAME.len + Win32Context.WNDClassName().len) * 5]u8 = undefined;
            // var fba = std.heap.FixedBufferAllocator.init(&buffer);
            // const fballocator = fba.allocator();
            //
            // // Shoudln't fail since the buffer is big enough.
            // const wide_class_name = utils.utf8ToWideZ(fballocator, Win32Context.WINDOW_CLASS_NAME) catch unreachable;
            // const helper_class_name = utils.utf8ToWideZ(fballocator, Win32Context.HELPER_CLASS_NAME) catch unreachable;

            // Unregister the window class.
            _ = win32.UnregisterClassW(
                utils.MAKEINTATOM(globl_instance.handles.wnd_class),
                Self.globl_instance.handles.hinstance,
            );

            // Unregister the helper class.
            _ = win32.UnregisterClassW(
                utils.MAKEINTATOM(globl_instance.handles.helper_class),
                Self.globl_instance.handles.hinstance,
            );

            freeLibraries(&Self.globl_instance);
        }
    }
};

fn isWin32VersionMinimum(proc: win32.RtlVerifyVersionInfoProc, major: u32, minor: u32) bool {
    // [MSDN]
    // If you must require a particular operating system,
    // be sure to use it as a minimum supported version,
    // rather than design the test for the one operating system.
    // This way, your detection code will continue to work on future versions of Windows.
    var vi: win32_sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = major;
    vi.dwMinorVersion = minor;
    const mask =
        @intFromEnum(win32_sysinfo.VER_MAJORVERSION) |
        @intFromEnum(win32_sysinfo.VER_MINORVERSION) |
        @intFromEnum(win32_sysinfo.VER_SERVICEPACKMAJOR) |
        @intFromEnum(win32_sysinfo.VER_SERVICEPACKMINOR);
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
    return proc(&vi, mask, cond_mask) == win32.NTSTATUS.SUCCESS;
}

fn isWin10BuildMinimum(proc: win32.RtlVerifyVersionInfoProc, build: u32) bool {
    var vi: win32_sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(win32_sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = 10;
    vi.dwMinorVersion = 0;
    vi.dwBuildNumber = build;
    const mask = @intFromEnum(win32_sysinfo.VER_MAJORVERSION) |
        @intFromEnum(win32_sysinfo.VER_MINORVERSION) |
        @intFromEnum(win32_sysinfo.VER_BUILDNUMBER);
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
    return proc(&vi, mask, cond_mask) == win32.NTSTATUS.SUCCESS;
}

fn registerHelperClass(comptime helper_class_name: []const u8, hinstance: win32.HINSTANCE) !u16 {
    var helper_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    helper_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    helper_class.style = win32_window_messaging.CS_OWNDC;
    helper_class.lpfnWndProc = helperWindowProc;
    helper_class.hInstance = hinstance;
    var buffer: [helper_class_name.len * 4]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), helper_class_name) catch unreachable;
    helper_class.lpszClassName = wide_class_name;
    const class = win32_window_messaging.RegisterClassExW(&helper_class);
    if (class == 0) {
        return WidowError.FailedToRegisterHELPCLASS;
    }
    return class;
}

fn registerMainClass(
    comptime wnd_class_name: []const u8,
    comptime res_icon_name: ?[]const u8,
    hinstance: win32.HINSTANCE,
) !u16 {
    var window_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    window_class.style = @enumFromInt(
        @intFromEnum(win32_window_messaging.CS_HREDRAW) |
            @intFromEnum(win32_window_messaging.CS_VREDRAW) |
            @intFromEnum(win32_window_messaging.CS_OWNDC),
    );
    window_class.lpfnWndProc = mainWindowProc;
    window_class.hInstance = hinstance;
    window_class.hCursor = win32_window_messaging.LoadCursorW(null, win32_window_messaging.IDC_ARROW);
    const icon_name_len = comptime if (res_icon_name != null) res_icon_name.?.len else 0;
    var buffer: [(wnd_class_name.len + icon_name_len + 1) * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), wnd_class_name) catch unreachable;
    window_class.lpszClassName = wide_class_name;
    if (res_icon_name) |icon_name| {
        const wide_icon_name = utils.utf8ToWideZ(fba.allocator(), icon_name) catch unreachable;
        window_class.hIcon = @ptrCast(win32_window_messaging.LoadImageW(
            hinstance,
            wide_icon_name,
            win32_window_messaging.IMAGE_ICON,
            0,
            0,
            @enumFromInt(@intFromEnum(win32_window_messaging.LR_DEFAULTSIZE) |
                @intFromEnum(win32_window_messaging.LR_SHARED)),
        ));
    }
    if (window_class.hIcon == null) {
        // No Icon was provided or we failed.
        window_class.hIcon = @ptrCast(win32_window_messaging.LoadImageW(
            null,
            win32_window_messaging.IDI_APPLICATION,
            win32_window_messaging.IMAGE_ICON,
            0,
            0,
            @enumFromInt(
                @intFromEnum(win32_window_messaging.LR_SHARED) | @intFromEnum(win32_window_messaging.LR_DEFAULTSIZE),
            ),
        ));
    }
    const class = win32_window_messaging.RegisterClassExW(&window_class);
    if (class == 0) {
        return WidowError.FailedToRegisterWNDCLASS;
    }
    return class;
}

test "Win32Context_init" {
    try Win32Context.initSingleton("Init_Test_Class", null);
    defer Win32Context.deinitSingleton();
}
