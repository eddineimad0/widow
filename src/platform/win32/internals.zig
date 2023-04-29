const win32api = @import("win32");
const Win32Flags = struct {
    is_win7_or_above: bool,
    is_win_vist_or_above: bool,
    is_win8point1_or_above: bool,
    is_win10b1607_or_above: bool,
    is_win10b1703_or_above: bool,
};

const Win32Handles = struct { main_class_handle: u16, helper_class_handle: u16, helper_window_handle: isize, main_class_name: ?[]u8 };

const Win32 = struct {
    flags: Win32Flags,
    handles: Win32Handles,
};

// const rtlverifyversioninfo =  extern fn(
//          versioninfo: *mut osversioninfoexw,
//          typemask: u32,
//          conditionmask: u64,
//      ) win32api.;
//     pub type SetProcessDPIAware = unsafe extern "system" fn() -> BOOL;
//     pub type SetProcessDpiAwareness =
//         unsafe extern "system" fn(value: PROCESS_DPI_AWARENESS) -> HRESULT;
//     pub type SetProcessDpiAwarenessContext =
//         unsafe extern "system" fn(value: DPI_AWARENESS_CONTEXT) -> HRESULT;
//     pub type GetDpiForMonitor = unsafe extern "system" fn(
//         hmonitor: HMONITOR,
//         dpiType: MONITOR_DPI_TYPE,
//         dpiX: *mut u32,
//         dpiY: *mut u32,
//     ) -> HRESULT;
//     pub type GetDpiForWindow = unsafe extern "system" fn(hwnd: HWND) -> u32;
//     pub type AdjustWindowRectExForDpi = unsafe extern "system" fn(
//         lpRect: *mut RECT,
//         dwStyle: u32,
//         bMenu: i32,
//         dwExStyle: u32,
//         dpi: u32,
//     ) -> BOOL;
//     pub type EnableNonClientDpiScaling = unsafe extern "system" fn(hwnd: HWND) -> BOOL;

