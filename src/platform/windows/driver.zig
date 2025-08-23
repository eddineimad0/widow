const std = @import("std");
const win32 = std.os.windows;
const win32_macros = @import("win32api/macros.zig");
const win32_gfx = @import("win32api/graphics.zig");
const krnl32 = @import("win32api/kernel32.zig");
const dynlib = @import("dynlib.zig");
const utils = @import("utils.zig");
const opts = @import("build-options");

const unicode = std.unicode;

const helperWindowProc = @import("window_proc.zig").helperWindowProc;
const mainWindowProc = @import("window_proc.zig").mainWindowProc;

pub const Win32DriverError = error{
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
    ntdll: ?win32.HMODULE,
    user32: ?win32.HMODULE,
    shcore: ?win32.HMODULE,
    hinstance: win32.HINSTANCE,
    helper_class: u16,
    wnd_class: u16,
};

/// Holds pointer to functions that are not
/// supported in all windows NT versions.
const OptionalApi = struct {
    // Types
    // Functions
    const SetProcessDPIAwareProc = *const fn () callconv(.winapi) win32.BOOL;
    const RtlVerifyVersionInfoProc = *const fn (
        VersionInfo: *krnl32.OSVERSIONINFOEXW,
        TypeMask: u32,
        ConditionMask: u64,
    ) callconv(.winapi) win32.NTSTATUS;
    const SetProcessDpiAwarenessProc = *const fn (
        win32_gfx.PROCESS_DPI_AWARENESS,
    ) callconv(.winapi) win32.HRESULT;
    pub const SetProcessDpiAwarenessContextProc = *const fn (
        win32_gfx.DPI_AWARENESS_CONTEXT,
    ) callconv(.winapi) win32.HRESULT;
    const EnableNonClientDpiScalingProc = *const fn (win32.HWND) callconv(.winapi) win32.BOOL;
    const GetDpiForWindowProc = *const fn (win32.HWND) callconv(.winapi) win32.DWORD;
    const GetDpiForMonitorProc = *const fn (
        win32_gfx.HMONITOR,
        win32_gfx.MONITOR_DPI_TYPE,
        *u32,
        *u32,
    ) callconv(.winapi) win32.HRESULT;
    const AdjustWindowRectExForDpiProc = *const fn (
        *win32.RECT,
        u32,
        i32,
        u32,
        u32,
    ) callconv(.winapi) win32.BOOL;

    // RtlVerifyVersionInfo is guaranteed to be on all NT versions
    RtlVerifyVersionInfo: RtlVerifyVersionInfoProc,
    SetProcessDPIAware: ?SetProcessDPIAwareProc,
    SetProcessDpiAwareness: ?SetProcessDpiAwarenessProc,
    SetProcessDpiAwarenessContext: ?SetProcessDpiAwarenessContextProc,
    GetDpiForMonitor: ?GetDpiForMonitorProc,
    GetDpiForWindow: ?GetDpiForWindowProc,
    AdjustWindowRectExForDpi: ?AdjustWindowRectExForDpiProc,
    EnableNonClientDpiScaling: ?EnableNonClientDpiScalingProc,
};

pub const Win32Driver = struct {
    hints: OsVersionHints,
    handles: Win32Handles,
    opt_func: OptionalApi,
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

    pub fn initSingleton() Win32DriverError!*const Self {
        @branchHint(.cold);

        Self.sing_guard.lock();
        defer Self.sing_guard.unlock();

        if (!Self.g_init) {
            if (dynlib.getProcessHandle()) |hinstance| {
                globl_instance.handles.hinstance = hinstance;
            } else {
                return Win32DriverError.NoProcessHandle;
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
                    win32_gfx.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
                );
            } else if (globl_instance.hints.is_win8point1_or_above) {
                _ = globl_instance.opt_func.SetProcessDpiAwareness.?(
                    win32_gfx.PROCESS_PER_MONITOR_DPI_AWARE,
                );
            } else if (globl_instance.hints.is_win_vista_or_above) {
                _ = globl_instance.opt_func.SetProcessDPIAware.?();
            }

            Self.g_init = true;
        }
        return &Self.globl_instance;
    }

    fn loadLibraries(self: *Self) Win32DriverError!void {
        self.handles.ntdll = dynlib.loadWin32Module("ntdll.dll");
        if (self.handles.ntdll) |*ntdll| {
            self.opt_func.RtlVerifyVersionInfo = @ptrCast(
                dynlib.getModuleSymbol(ntdll.*, "RtlVerifyVersionInfo"),
            );
        } else {
            // It's important for this module to be loaded since
            // it has the necessary function for figuring out
            // what windows version the system is runing
            // said version is used later to dynamically
            // select which code we run in certain sections.
            return Win32DriverError.NtdllNotFound;
        }
        self.handles.user32 = dynlib.loadWin32Module("user32.dll");
        if (self.handles.user32) |*user32| {
            self.opt_func.SetProcessDPIAware = @ptrCast(dynlib.getModuleSymbol(
                user32.*,
                "SetProcessDPIAware",
            ));
            self.opt_func.SetProcessDpiAwarenessContext = @ptrCast(
                dynlib.getModuleSymbol(user32.*, "SetProcessDpiAwarenessContext"),
            );
            self.opt_func.GetDpiForWindow = @ptrCast(dynlib.getModuleSymbol(
                user32.*,
                "GetDpiForWindow",
            ));
            self.opt_func.EnableNonClientDpiScaling = @ptrCast(dynlib.getModuleSymbol(
                user32.*,
                "EnableNonClientDpiScaling",
            ));
            self.opt_func.AdjustWindowRectExForDpi = @ptrCast(dynlib.getModuleSymbol(
                user32.*,
                "AdjustWindowRectExForDpi",
            ));
        }
        self.handles.shcore = dynlib.loadWin32Module("Shcore.dll");
        if (self.handles.shcore) |*shcore| {
            self.opt_func.GetDpiForMonitor = @ptrCast(
                dynlib.getModuleSymbol(shcore.*, "GetDpiForMonitor"),
            );
            self.opt_func.SetProcessDpiAwareness = @ptrCast(
                dynlib.getModuleSymbol(shcore.*, "SetProcessDpiAwareness"),
            );
        }
    }

    fn freeLibraries(self: *Self) void {
        if (self.handles.ntdll) |*handle| {
            dynlib.freeWin32Module(handle.*);
            self.handles.ntdll = null;
        }
        if (self.handles.user32) |*handle| {
            dynlib.freeWin32Module(handle.*);
            self.handles.user32 = null;
            self.opt_func.SetProcessDPIAware = null;
            self.opt_func.SetProcessDpiAwarenessContext = null;
            self.opt_func.GetDpiForWindow = null;
            self.opt_func.EnableNonClientDpiScaling = null;
            self.opt_func.AdjustWindowRectExForDpi = null;
        }
        if (self.handles.shcore) |*handle| {
            dynlib.freeWin32Module(handle.*);
            self.handles.shcore = null;
            self.opt_func.SetProcessDpiAwareness = null;
            self.opt_func.GetDpiForMonitor = null;
        }
    }

    inline fn WNDClassName() []const u8 {
        return Self.WINDOW_CLASS_NAME;
    }

    /// !!! Calling this function Unregister the main WNDCLASS effectively crashing any window
    /// that hasn't been destroyed yet.
    /// INFO: This isn't called at all and for now we rely on the os to do the cleanup
    fn deinitSingleton() void {
        if (Self.g_init) {
            Self.g_init = false;

            // Unregister the window class.
            _ = win32_gfx.UnregisterClassW(
                win32_macros.MAKEINTATOM(globl_instance.handles.wnd_class),
                Self.globl_instance.handles.hinstance,
            );

            // Unregister the helper class.
            _ = win32_gfx.UnregisterClassW(
                win32_macros.MAKEINTATOM(globl_instance.handles.helper_class),
                Self.globl_instance.handles.hinstance,
            );

            freeLibraries(&Self.globl_instance);
        }
    }
};

fn isWin32VersionMinimum(
    func: OptionalApi.RtlVerifyVersionInfoProc,
    major: u32,
    minor: u32,
) bool {
    // [MSDN]
    // If you must require a particular operating system,
    // be sure to use it as a minimum supported version,
    // rather than design the test for the one operating system.
    // This way, your detection code will continue to work on future versions of Windows.
    var vi: krnl32.OSVERSIONINFOEXW = std.mem.zeroes(krnl32.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(krnl32.OSVERSIONINFOEXW);
    vi.dwMajorVersion = major;
    vi.dwMinorVersion = minor;
    const mask = krnl32.VER_FLAGS{
        .MINORVERSION = 1,
        .MAJORVERSION = 1,
        .SERVICEPACKMINOR = 1,
        .SERVICEPACKMAJOR = 1,
    };
    var cond_mask: u64 = 0;
    cond_mask = krnl32.VerSetConditionMask(
        cond_mask,
        krnl32.VER_MAJORVERSION,
        krnl32.VER_GREATER_EQUAL,
    );
    cond_mask = krnl32.VerSetConditionMask(
        cond_mask,
        krnl32.VER_MINORVERSION,
        krnl32.VER_GREATER_EQUAL,
    );
    cond_mask =
        krnl32.VerSetConditionMask(
            cond_mask,
            krnl32.VER_SERVICEPACKMAJOR,
            krnl32.VER_GREATER_EQUAL,
        );
    cond_mask =
        krnl32.VerSetConditionMask(
            cond_mask,
            krnl32.VER_SERVICEPACKMINOR,
            krnl32.VER_GREATER_EQUAL,
        );
    return func(&vi, @bitCast(mask), cond_mask) == win32.NTSTATUS.SUCCESS;
}

fn isWin10BuildMinimum(func: OptionalApi.RtlVerifyVersionInfoProc, build: u32) bool {
    var vi: krnl32.OSVERSIONINFOEXW = std.mem.zeroes(krnl32.OSVERSIONINFOEXW);
    vi.dwOSVersionInfoSize = @sizeOf(krnl32.OSVERSIONINFOEXW);
    vi.dwMajorVersion = 10;
    vi.dwMinorVersion = 0;
    vi.dwBuildNumber = build;
    const mask = krnl32.VER_FLAGS{
        .MINORVERSION = 1,
        .MAJORVERSION = 1,
        .BUILDNUMBER = 1,
    };
    var cond_mask: u64 = 0;
    cond_mask = krnl32.VerSetConditionMask(
        cond_mask,
        krnl32.VER_MAJORVERSION,
        krnl32.VER_GREATER_EQUAL,
    );
    cond_mask = krnl32.VerSetConditionMask(
        cond_mask,
        krnl32.VER_MINORVERSION,
        krnl32.VER_GREATER_EQUAL,
    );
    cond_mask = krnl32.VerSetConditionMask(
        cond_mask,
        krnl32.VER_BUILDNUMBER,
        krnl32.VER_GREATER_EQUAL,
    );
    return func(&vi, @bitCast(mask), cond_mask) == win32.NTSTATUS.SUCCESS;
}

fn registerMainClass(
    hinstance: win32.HINSTANCE,
) Win32DriverError!u16 {
    var window_class: win32_gfx.WNDCLASSEXW = std.mem.zeroes(win32_gfx.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_gfx.WNDCLASSEXW);
    window_class.style = win32_gfx.WNDCLASS_STYLES{
        .HREDRAW = 1,
        .VREDRAW = 1,
        .OWNDC = 1, //CS_OWNDC is required for the opengl context.
    };
    window_class.lpfnWndProc = mainWindowProc;
    window_class.hInstance = hinstance;
    window_class.hCursor = win32_gfx.LoadCursorW(null, win32_gfx.IDC_ARROW);
    window_class.lpszClassName = unicode.utf8ToUtf16LeStringLiteral(
        opts.WIN32_WNDCLASS_NAME,
    );

    if (opts.WIN32_ICON_RES_NAME) |icon_name| {
        window_class.hIcon = @ptrCast(win32_gfx.LoadImageW(
            hinstance,
            unicode.utf8ToUtf16LeStringLiteral(icon_name),
            win32_gfx.IMAGE_ICON,
            0,
            0,
            @bitCast(win32_gfx.IMAGE_FLAGS{ .SHARED = 1, .DEFAULTSIZE = 1 }),
        ));
    }

    // even if an icon name was provided loading the image might fail
    // in this case leave hIcon set to null for default Application icon.

    const class = win32_gfx.RegisterClassExW(&window_class);
    if (class == 0) {
        return Win32DriverError.DupWNDClass;
    }
    return class;
}

fn registerHelperClass(
    hinstance: win32.HINSTANCE,
) Win32DriverError!u16 {
    var window_class: win32_gfx.WNDCLASSEXW = std.mem.zeroes(win32_gfx.WNDCLASSEXW);
    window_class.cbSize = @sizeOf(win32_gfx.WNDCLASSEXW);
    window_class.lpfnWndProc = helperWindowProc;
    window_class.hInstance = hinstance;
    window_class.lpszClassName = unicode.utf8ToUtf16LeStringLiteral(
        opts.WIN32_WNDCLASS_NAME ++ "_HELPER",
    );

    const class = win32_gfx.RegisterClassExW(&window_class);
    if (class == 0) {
        return Win32DriverError.DupWNDClass;
    }
    return class;
}

test "Win32Driver init" {
    try Win32Driver.initSingleton();
    defer Win32Driver.deinitSingleton();
}
