const std = @import("std");
const win32 = @import("win32_defs.zig");
const zigwin32 = @import("zigwin32");
const mod = @import("module.zig");
const utils = @import("utils.zig");
const opts = @import("build-options");
const helperWindowProc = @import("window_proc.zig").helperWindowProc;
const mainWindowProc = @import("window_proc.zig").mainWindowProc;
const unicode = std.unicode;
const sysinfo = zigwin32.system.system_information;
const window_msg = zigwin32.ui.windows_and_messaging;

const DriverError = error{
    NtdllNotFound,
    DupWNDClass,
    DupHELPClass,
    NoProcessHandle,
};

const OsVersionHints = struct {
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

/// Holds pointer to functions that are not
/// supported in all windows NT versions.
const OptionalApi = struct {
    // RtlVerifyVersionInfo is guaranteed to be on all NT versions
    RtlVerifyVersionInfo: win32.RtlVerifyVersionInfoProc,
    SetProcessDPIAware: ?win32.SetProcessDPIAwareProc,
    SetProcessDpiAwareness: ?win32.SetProcessDpiAwarenessProc,
    SetProcessDpiAwarenessContext: ?win32.SetProcessDpiAwarenessContextProc,
    GetDpiForMonitor: ?win32.GetDpiForMonitorProc,
    GetDpiForWindow: ?win32.GetDpiForWindowProc,
    AdjustWindowRectExForDpi: ?win32.AdjustWindowRectExForDpiProc,
    EnableNonClientDpiScaling: ?win32.EnableNonClientDpiScalingProc,
};

pub const Win32Driver = struct {
    hints: OsVersionHints,
    handles: Win32Handles,
    opt_func: OptionalApi,
    // TODO: should we use the build script options for the names
    // var WINDOW_CLASS_NAME: []const u8 = opts.WIN32_WNDCLASS_NAME;
    // var HELPER_CLASS_NAME: []const u8 = opts.WIN32_WNDCLASS_NAME ++ "_HELPER";
    // var RESOURCE_ICON_NAME: []const u8 = "";
    var sing_guard: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;

    // A global readonly singelton
    // used to access loaded function, os hints and global handles.
    var globl_instance: Win32Driver = Win32Driver{
        .hints = OsVersionHints{
            .is_win_vista_or_above = false,
            .is_win7_or_above = false,
            .is_win8point1_or_above = false,
            .is_win10b1607_or_above = false,
            .is_win10b1703_or_above = false,
        },
        .opt_func = OptionalApi{
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

    pub fn initSingleton() !void {
        @setCold(true);

        Self.sing_guard.lock();
        defer Self.sing_guard.unlock();

        if (!Self.g_init) {
            if (mod.getProcessHandle()) |hinstance| {
                globl_instance.handles.hinstance = hinstance;
            } else {
                return DriverError.NoProcessHandle;
            }

            globl_instance.handles.wnd_class = try registerMainClass(
                globl_instance.handles.hinstance,
            );
            globl_instance.handles.helper_class = try registerHelperClass(
                globl_instance.handles.hinstance,
            );

            // Load the required libraries.
            try globl_instance.loadLibraries();
            errdefer globl_instance.freeLibraries();

            // Setup windows version hints.
            if (isWin32VersionMinimum(globl_instance.opt_func.RtlVerifyVersionInfo, 6, 0)) {
                globl_instance.hints.is_win_vista_or_above = true;

                if (isWin32VersionMinimum(globl_instance.opt_func.RtlVerifyVersionInfo, 6, 1)) {
                    globl_instance.hints.is_win7_or_above = true;

                    if (isWin32VersionMinimum(globl_instance.opt_func.RtlVerifyVersionInfo, 6, 3)) {
                        globl_instance.hints.is_win8point1_or_above = true;

                        if (isWin10BuildMinimum(globl_instance.opt_func.RtlVerifyVersionInfo, 1607)) {
                            globl_instance.hints.is_win10b1607_or_above = true;

                            if (isWin10BuildMinimum(globl_instance.opt_func.RtlVerifyVersionInfo, 1703)) {
                                globl_instance.hints.is_win10b1703_or_above = true;
                            }
                        }
                    }
                }
            }

            // Declare Process DPI Awareness.
            if (globl_instance.hints.is_win10b1703_or_above) {
                _ = globl_instance.opt_func.SetProcessDpiAwarenessContext.?(
                    win32.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
                );
            } else if (globl_instance.hints.is_win8point1_or_above) {
                _ = globl_instance.opt_func.SetProcessDpiAwareness.?(
                    win32.PROCESS_PER_MONITOR_DPI_AWARE,
                );
            } else if (globl_instance.hints.is_win_vista_or_above) {
                _ = globl_instance.opt_func.SetProcessDPIAware.?();
            }

            Self.g_init = true;
        }
    }

    fn loadLibraries(self: *Self) DriverError!void {
        self.handles.ntdll = mod.loadWin32Module("ntdll.dll");
        if (self.handles.ntdll) |*ntdll| {
            self.opt_func.RtlVerifyVersionInfo = @ptrCast(
                mod.getModuleSymbol(ntdll.*, "RtlVerifyVersionInfo"),
            );
        } else {
            // It's important for this module to be loaded since
            // it has the necessary function for figuring out
            // what windows version the system is runing
            // said version is used later to dynamically
            // select which code we run in certain sections.
            return DriverError.NtdllNotFound;
        }
        self.handles.user32 = mod.loadWin32Module("user32.dll");
        if (self.handles.user32) |*user32| {
            self.opt_func.SetProcessDPIAware = @ptrCast(mod.getModuleSymbol(
                user32.*,
                "SetProcessDPIAware",
            ));
            self.opt_func.SetProcessDpiAwarenessContext = @ptrCast(
                mod.getModuleSymbol(user32.*, "SetProcessDpiAwarenessContext"),
            );
            self.opt_func.GetDpiForWindow = @ptrCast(mod.getModuleSymbol(
                user32.*,
                "GetDpiForWindow",
            ));
            self.opt_func.EnableNonClientDpiScaling = @ptrCast(mod.getModuleSymbol(
                user32.*,
                "EnableNonClientDpiScaling",
            ));
            self.opt_func.AdjustWindowRectExForDpi = @ptrCast(mod.getModuleSymbol(
                user32.*,
                "AdjustWindowRectExForDpi",
            ));
        }
        self.handles.shcore = mod.loadWin32Module("Shcore.dll");
        if (self.handles.shcore) |*shcore| {
            self.opt_func.GetDpiForMonitor = @ptrCast(
                mod.getModuleSymbol(shcore.*, "GetDpiForMonitor"),
            );
            self.opt_func.SetProcessDpiAwareness = @ptrCast(
                mod.getModuleSymbol(shcore.*, "SetProcessDpiAwareness"),
            );
        }
    }

    fn freeLibraries(self: *Self) void {
        if (self.handles.ntdll) |*handle| {
            mod.freeWin32Module(handle.*);
            self.handles.ntdll = null;
        }
        if (self.handles.user32) |*handle| {
            mod.freeWin32Module(handle.*);
            self.handles.user32 = null;
            self.opt_func.SetProcessDPIAware = null;
            self.opt_func.SetProcessDpiAwarenessContext = null;
            self.opt_func.GetDpiForWindow = null;
            self.opt_func.EnableNonClientDpiScaling = null;
            self.opt_func.AdjustWindowRectExForDpi = null;
        }
        if (self.handles.shcore) |*handle| {
            mod.freeWin32Module(handle.*);
            self.handles.shcore = null;
            self.opt_func.SetProcessDpiAwareness = null;
            self.opt_func.GetDpiForMonitor = null;
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

fn isWin32VersionMinimum(
    proc: win32.RtlVerifyVersionInfoProc,
    major: u32,
    minor: u32,
) bool {
    // [MSDN]
    // If you must require a particular operating system,
    // be sure to use it as a minimum supported version,
    // rather than design the test for the one operating system.
    // This way, your detection code will continue to work on future versions of Windows.
    var vi: sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = major;
    vi.dwMinorVersion = minor;
    const mask = sysinfo.VER_FLAGS{
        .MINORVERSION = 1,
        .MAJORVERSION = 1,
        .SERVICEPACKMINOR = 1,
        .SERVICEPACKMAJOR = 1,
    };
    var cond_mask: u64 = 0;
    cond_mask = sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_MAJORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask = sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_MINORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask =
        sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_SERVICEPACKMAJOR,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask =
        sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_SERVICEPACKMINOR,
        win32.VER_GREATER_EQUAL,
    );
    return proc(&vi, @bitCast(mask), cond_mask) == win32.NTSTATUS.SUCCESS;
}

fn isWin10BuildMinimum(proc: win32.RtlVerifyVersionInfoProc, build: u32) bool {
    var vi: sysinfo.OSVERSIONINFOEXW = std.mem.zeroes(sysinfo.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(sysinfo.OSVERSIONINFOEXW);
    vi.dwMajorVersion = 10;
    vi.dwMinorVersion = 0;
    vi.dwBuildNumber = build;
    const mask = sysinfo.VER_FLAGS{
        .MINORVERSION = 1,
        .MAJORVERSION = 1,
        .BUILDNUMBER = 1,
    };
    var cond_mask: u64 = 0;
    cond_mask = sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_MAJORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask = sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_MINORVERSION,
        win32.VER_GREATER_EQUAL,
    );
    cond_mask = sysinfo.VerSetConditionMask(
        cond_mask,
        sysinfo.VER_BUILDNUMBER,
        win32.VER_GREATER_EQUAL,
    );
    return proc(&vi, @bitCast(mask), cond_mask) == win32.NTSTATUS.SUCCESS;
}

fn registerHelperClass(
    hinstance: win32.HINSTANCE,
) !u16 {
    var helper_class: window_msg.WNDCLASSEXW = std.mem.zeroes(window_msg.WNDCLASSEXW);
    helper_class.cbSize = @sizeOf(window_msg.WNDCLASSEXW);
    helper_class.style = window_msg.CS_OWNDC;
    helper_class.lpfnWndProc = helperWindowProc;
    helper_class.hInstance = hinstance;
    // var buffer: [helper_class_name.len * 4]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // Shoudln't fail since the buffer is big enough.
    // const wide_class_name = utils.utf8ToWideZ(
    //     fba.allocator(),
    //     helper_class_name,
    // ) catch unreachable;
    helper_class.lpszClassName = unicode.utf8ToUtf16LeStringLiteral(opts.WIN32_WNDCLASS_NAME ++ "_HELPER");
    const class = window_msg.RegisterClassExW(&helper_class);
    if (class == 0) {
        return DriverError.DupHELPClass;
    }
    return class;
}

fn registerMainClass(
    hinstance: win32.HINSTANCE,
) DriverError!u16 {
    var window_class: window_msg.WNDCLASSEXW = std.mem.zeroes(window_msg.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(window_msg.WNDCLASSEXW);
    window_class.style = window_msg.WNDCLASS_STYLES{
        .HREDRAW = 1,
        .VREDRAW = 1,
        .OWNDC = 1, //CS_OWNDC is required for the opengl context.
    };
    window_class.lpfnWndProc = mainWindowProc;
    window_class.hInstance = hinstance;
    window_class.hCursor = window_msg.LoadCursorW(null, window_msg.IDC_ARROW);
    // const icon_name_len = comptime if (res_icon_name) |name| name.len else 0;
    // var buffer: [(wnd_class_name.len + icon_name_len + 1) * 5]u8 = undefined;
    // var fba = std.heap.FixedBufferAllocator.init(&buffer);
    // const wide_class_name = utils.utf8ToWideZ(
    //     fba.allocator(),
    //     wnd_class_name,
    // ) catch unreachable;
    window_class.lpszClassName = unicode.utf8ToUtf16LeStringLiteral(opts.WIN32_WNDCLASS_NAME);
    // if (res_icon_name) |icon_name| {
    //     //TODO: both this and classname shoud be
    //     // converted at comptime.
    //     const wide_icon_name = utils.utf8ToWideZ(
    //         fba.allocator(),
    //         icon_name,
    //     ) catch unreachable;
    //     window_class.hIcon = @ptrCast(window_msg.LoadImageW(
    //         hinstance,
    //         wide_icon_name,
    //         window_msg.IMAGE_ICON,
    //         0,
    //         0,
    //         window_msg.IMAGE_FLAGS{ .SHARED = 1, .DEFAULTSIZE = 1 },
    //     ));
    // }
    if (window_class.hIcon == null) {
        // No Icon was provided or we failed.
        window_class.hIcon = @ptrCast(win32.LoadImageW(
            null,
            window_msg.IDI_APPLICATION,
            @intFromEnum(window_msg.IMAGE_ICON),
            0,
            0,
            @bitCast(window_msg.IMAGE_FLAGS{ .SHARED = 1, .DEFAULTSIZE = 1 }),
        ));
    }
    const class = window_msg.RegisterClassExW(&window_class);
    if (class == 0) {
        return DriverError.DupWNDClass;
    }
    return class;
}

test "Win32Driver init" {
    try Win32Driver.initSingleton("Test class", null);
    defer Win32Driver.deinitSingleton();
}
