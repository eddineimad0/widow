const std = @import("std");
const win32 = @import("win32_defs.zig");
const zigwin32 = @import("zigwin32");
const WidowError = @import("errors.zig").WidowWin32Error;
const mainWindowProc = @import("./window_proc.zig").mainWindowProc;
const module = @import("./module.zig");
const utils = @import("./utils.zig");
const win32_sysinfo = zigwin32.system.system_information;
const win32_window_messaging = zigwin32.ui.windows_and_messaging;

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
    wnd_class: u16,
    ntdll: ?win32.HINSTANCE,
    user32: ?win32.HINSTANCE,
    shcore: ?win32.HINSTANCE,
    hinstance: win32.HINSTANCE, // the hinstance of the process
};

const LoadedFunctions = struct {
    RtlVerifyVersionInfo: proc_RtlVerifyVersionInfo,
    SetProcessDPIAware: ?proc_SetProcessDPIAware,
    SetProcessDpiAwareness: ?proc_SetProcessDpiAwareness,
    SetProcessDpiAwarenessContext: ?proc_SetProcessDpiAwarenessContext,
    GetDpiForMonitor: ?proc_GetDpiForMonitor,
    GetDpiForWindow: ?proc_GetDpiForWindow,
    AdjustWindowRectExForDpi: ?proc_AdjustWindowRectExForDpi,
    EnableNonClientDpiScaling: ?proc_EnableNonClientDpiScaling,
};

pub const Win32Context = struct {
    flags: Win32Flags,
    handles: Win32Handles,
    functions: LoadedFunctions,
    // TODO: can we change this to a user comptime string.
    pub const WINDOW_CLASS_NAME = "WIDOW";
    var mutex: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;

    // A global readonly singelton
    // used to access loaded function and os flag and handles.
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
            .ntdll = null,
            .user32 = null,
            .shcore = null,
            .hinstance = undefined, // the hinstance of the process
        },
    };

    const Self = @This();

    fn initSingleton() !void {
        @setCold(true);
        // Determine the current HInstance.
        const g_instance = &Self.globl_instance;

        Self.mutex.lock();
        defer mutex.unlock();

        if (!Self.g_init) {
            g_instance.handles.hinstance = try module.getProcessHandle();

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
            // Register the window class
            g_instance.handles.wnd_class = try registerMainClass(g_instance.handles.hinstance);

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
                proc_RtlVerifyVersionInfo,
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
                @ptrCast(proc_SetProcessDPIAware, module.getModuleSymbol(user32.*, "SetProcessDPIAware"));
            self.functions.SetProcessDpiAwarenessContext =
                @ptrCast(
                proc_SetProcessDpiAwarenessContext,
                module.getModuleSymbol(user32.*, "SetProcessDpiAwarenessContext"),
            );
            self.functions.GetDpiForWindow =
                @ptrCast(proc_GetDpiForWindow, module.getModuleSymbol(user32.*, "GetDpiForWindow"));
            self.functions.EnableNonClientDpiScaling =
                @ptrCast(proc_EnableNonClientDpiScaling, module.getModuleSymbol(user32.*, "EnableNonClientDpiScaling"));
            self.functions.AdjustWindowRectExForDpi =
                @ptrCast(proc_AdjustWindowRectExForDpi, module.getModuleSymbol(user32.*, "AdjustWindowRectExForDpi"));
        }
        self.handles.shcore = module.loadWin32Module("Shcore.dll");
        if (self.handles.shcore) |*shcore| {
            self.functions.GetDpiForMonitor = @ptrCast(
                proc_GetDpiForMonitor,
                module.getModuleSymbol(shcore.*, "GetDpiForMonitor"),
            );
            self.functions.SetProcessDpiAwareness = @ptrCast(
                proc_SetProcessDpiAwareness,
                module.getModuleSymbol(shcore.*, "SetProcessDpiAwareness"),
            );
        }
    }

    fn freeLibraries(self: *Self) void {
        if (self.handles.ntdll) |*handle| {
            module.freeWin32Module(handle.*);
            self.handles.ntdll = null;
            // self.functions.RtlVerifyVersionInfo = undefined;
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

    // Enfoce readonly.
    pub fn singleton() ?*const Self {
        if (!@atomicLoad(bool, &Self.g_init, .Acquire)) {
            initSingleton() catch |err| {
                std.log.err("[Win32]: Failed to init Win32Context,{}\n", .{err});
                return null;
            };
        }
        return &Self.globl_instance;
    }

    // !!! Calling this function Unregister the main WNDCLASS effectively crashing any window
    // that hasn't been destroyed yet !!!.
    // for now let windows handle cleaning once the program exit.
    // pub fn deinitSingleton() void {
    //     if (Self.global_instance.initialzied) {
    //         freeLibraries(&Self.global_instance);
    //         var buffer: [(Self.WINDOW_CLASS_NAME.len) * 5]u8 = undefined;
    //         var fba = std.heap.FixedBufferAllocator.init(&buffer);
    //         const fballocator = fba.allocator();
    //         // Shouldn't fail since the buffer is big enough.
    //         const wide_class_name = utils.utf8ToWideZ(fballocator, Self.WINDOW_CLASS_NAME) catch unreachable;
    //
    //         // Unregister the window class.
    //         _ = win32_window_messaging.UnregisterClassW(
    //             // utils.makeIntAtom(u8, self.handles.wnd_class),
    //             wide_class_name,
    //             Self.global_instance.handles.hinstance,
    //         );
    //         Self.global_instance.initialzied = false;
    //     }
    // }
};

fn registerMainClass(hinstance: win32.HINSTANCE) !u16 {
    const IMAGE_ICON = win32_window_messaging.GDI_IMAGE_TYPE.ICON;
    var window_class: win32_window_messaging.WNDCLASSEXW = std.mem.zeroes(win32_window_messaging.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_window_messaging.WNDCLASSEXW);
    window_class.style = @intToEnum(win32_window_messaging.WNDCLASS_STYLES, @enumToInt(win32_window_messaging.CS_HREDRAW) | @enumToInt(win32_window_messaging.CS_VREDRAW) | @enumToInt(win32_window_messaging.CS_OWNDC));
    window_class.lpfnWndProc = mainWindowProc;
    window_class.hInstance = hinstance;
    window_class.hCursor = win32_window_messaging.LoadCursorW(null, win32_window_messaging.IDC_ARROW);
    var buffer: [Win32Context.WINDOW_CLASS_NAME.len * 5]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), Win32Context.WINDOW_CLASS_NAME) catch unreachable;
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
            @intToEnum(win32_window_messaging.IMAGE_FLAGS, @enumToInt(win32_window_messaging.LR_SHARED) |
                @enumToInt(win32_window_messaging.LR_DEFAULTSIZE)),
        ));
    }
    const class = win32_window_messaging.RegisterClassExW(&window_class);
    if (class == 0) {
        return WidowError.FailedToRegisterWNDCLASS;
    }
    return class;
}

fn isWin32VersionMinimum(proc: proc_RtlVerifyVersionInfo, major: u32, minor: u32) bool {
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
    return proc(&vi, mask, cond_mask) == win32.NTSTATUS.SUCCESS;
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
    return proc(&vi, mask, cond_mask) == win32.NTSTATUS.SUCCESS;
}

test "Win32Context Thread safety" {
    const testing = std.testing;
    const builtin = @import("builtin");
    if (builtin.single_threaded) {
        const singleton = Win32Context.singleton();
        const singleton2 = Win32Context.singleton();
        try testing.expect(singleton != null);
        try testing.expect(singleton2 != null);
    } else {
        var threads: [10]std.Thread = undefined;
        defer for (threads) |handle| handle.join();

        for (&threads) |*handle| {
            handle.* = try std.Thread.spawn(.{}, struct {
                fn thread_fn() void {
                    _ = Win32Context.singleton();
                }
            }.thread_fn, .{});
        }
    }
}

test "Win32Context init" {
    const testing = std.testing;
    const singleton = Win32Context.singleton();
    try testing.expect(singleton != null);
    std.debug.print("Win32 execution context: {any}\n", .{singleton.?});
}
