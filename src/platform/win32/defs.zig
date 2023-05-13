const windows = @import("std").os.windows;
const winapi = @import("win32");
const win32_window_messaging = winapi.ui.windows_and_messaging;
const winabi = windows.WINAPI;
const HRESULT = windows.HRESULT;
const NTSTATUS = winapi.foundation.NTSTATUS;
const BOOL = winapi.foundation.BOOL;
const HWND = winapi.foundation.HWND;
const RECT = winapi.foundation.RECT;
const LPARAM = winapi.foundation.LPARAM;
const WPARAM = winapi.foundation.WPARAM;
const OSVERSIONINFOEXW = winapi.system.system_information.OSVERSIONINFOEXW;
const HMONITOR = winapi.graphics.gdi.HMONITOR;
const PROCESS_DPI_AWARENESS = winapi.ui.hi_dpi.PROCESS_DPI_AWARENESS;
const DPI_AWARENESS_CONTEXT = winapi.ui.hi_dpi.DPI_AWARENESS_CONTEXT;
const MONITOR_DPI_TYPE = winapi.ui.hi_dpi.MONITOR_DPI_TYPE;

pub const proc_SetProcessDPIAware = *const fn () callconv(winabi) BOOL;
pub const proc_RtlVerifyVersionInfo = *const fn (*OSVERSIONINFOEXW, u32, u64) callconv(winabi) NTSTATUS;
pub const proc_SetProcessDpiAwareness = *const fn (PROCESS_DPI_AWARENESS) callconv(winabi) HRESULT;
pub const proc_SetProcessDpiAwarenessContext = *const fn (DPI_AWARENESS_CONTEXT) callconv(winabi) HRESULT;
pub const proc_GetDpiForMonitor = *const fn (
    HMONITOR,
    MONITOR_DPI_TYPE,
    *u32,
    *u32,
) callconv(winabi) HRESULT;
pub const proc_GetDpiForWindow = *const fn (HWND) callconv(winabi) u32;
pub const proc_AdjustWindowRectExForDpi = *const fn (
    *RECT,
    u32,
    i32,
    u32,
    u32,
) callconv(winabi) BOOL;
pub const proc_EnableNonClientDpiScaling = *const fn (HWND) callconv(winabi) BOOL;

/// The procedure function for the helper window
pub fn helper_event_proc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) callconv(winabi) isize {
    switch (msg) {
        win32_window_messaging.WM_DISPLAYCHANGE => {
            // Monitor the WM_DISPLAYCHANGE notification
            // to detect when settings change or when a
            // display is added or removed.
            // var devices_ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA) as *mut PhysicalDevice;
            // match devices_ptr.as_mut() {
            //     Some(mut_borrow) => {
            //         if !(mut_borrow.change_expected.get()) {
            //             debug_println!("Updating Monitors");
            //             mut_borrow.update_monitors();
            //         }
            //     }
            //     None => {
            //         debug_println!("Failed to borrow devices_ptr.");
            //         return DefWindowProcW(hwnd, msg, wparam, lparam);
            //     }
            // };
        },
        // WM_DEVICECHANGE => {
        //     // I/O hardware
        // }
        else => {},
    }
    return win32_window_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
}
