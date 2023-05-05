const windows = @import("std").os.windows;
const win32api = @import("win32");
const winabi = windows.WINAPI;
const HRESULT = windows.HRESULT;
const NTSTATUS = win32api.foundation.NTSTATUS;
const BOOL = win32api.foundation.BOOL;
const HWND = win32api.foundation.HWND;
const RECT = win32api.foundation.RECT;
const OSVERSIONINFOEXW = win32api.system.system_information.OSVERSIONINFOEXW;
const HMONITOR = win32api.graphics.gdi.HMONITOR;
const PROCESS_DPI_AWARENESS = win32api.ui.hi_dpi.PROCESS_DPI_AWARENESS;
const DPI_AWARENESS_CONTEXT = win32api.ui.hi_dpi.DPI_AWARENESS_CONTEXT;
const MONITOR_DPI_TYPE = win32api.ui.hi_dpi.MONITOR_DPI_TYPE;

pub const proc_SetProcessDPIAware = *fn () callconv(winabi) BOOL;
pub const proc_RtlVerifyVersionInfo = *fn (*OSVERSIONINFOEXW, u32, u64) callconv(winabi) NTSTATUS;
pub const proc_SetProcessDpiAwareness = *fn (PROCESS_DPI_AWARENESS) callconv(winabi) HRESULT;
pub const proc_SetProcessDpiAwarenessContext = *fn (DPI_AWARENESS_CONTEXT) callconv(winabi) HRESULT;
pub const proc_GetDpiForMonitor = *fn (
    HMONITOR,
    MONITOR_DPI_TYPE,
    *u32,
    *u32,
) callconv(winabi) HRESULT;
pub const proc_GetDpiForWindow = *fn (HWND) callconv(winabi) u32;
pub const proc_AdjustWindowRectExForDpi = *fn (
    *RECT,
    u32,
    i32,
    u32,
    u32,
) callconv(winabi) BOOL;
pub const EnableNonClientDpiScaling = *fn (HWND) callconv(winabi) BOOL;
