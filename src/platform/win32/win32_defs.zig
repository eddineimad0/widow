const windows = @import("std").os.windows;
const zigwin32 = @import("zigwin32");
const builtin = @import("builtin");
const utils = @import("utils.zig");

// Windows Data Types:
pub const HINSTANCE = windows.HINSTANCE;
pub const HRESULT = windows.HRESULT;
pub const NTSTATUS = windows.NTSTATUS;
pub const WPARAM = windows.WPARAM;
pub const LPARAM = windows.LPARAM;
pub const LRESULT = windows.LRESULT;
pub const HDC = windows.HDC;
pub const HMENU = windows.HMENU;
pub const WINAPI = windows.WINAPI;
pub const BOOL = windows.BOOL;
pub const BYTE = windows.BYTE;
pub const LONG = windows.LONG;
pub const ULONG = windows.ULONG;
pub const UINT = windows.UINT;
pub const INT = windows.INT;
pub const DWORD = windows.DWORD;
pub const CHAR = windows.CHAR;
pub const WIN32_ERROR = zigwin32.foundation.WIN32_ERROR;
pub const HWND = zigwin32.foundation.HWND;
pub const RECT = zigwin32.foundation.RECT;
pub const FARPROC = zigwin32.foundation.FARPROC;
pub const HMONITOR = zigwin32.graphics.gdi.HMONITOR;
pub const PROCESS_DPI_AWARENESS = zigwin32.ui.hi_dpi.PROCESS_DPI_AWARENESS;
pub const DPI_AWARENESS_CONTEXT = zigwin32.ui.hi_dpi.DPI_AWARENESS_CONTEXT;
pub const MONITOR_DPI_TYPE = zigwin32.ui.hi_dpi.MONITOR_DPI_TYPE;
pub const OSVERSIONINFOEXW = zigwin32.system.system_information.OSVERSIONINFOEXW;
pub const GUID = zigwin32.zig.Guid;

// Constants.
pub const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = zigwin32.ui.hi_dpi.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2;
pub const PROCESS_PER_MONITOR_DPI_AWARE = zigwin32.ui.hi_dpi.PROCESS_PER_MONITOR_DPI_AWARE;
pub const DEVICE_NOTIFY_WINDOW_HANDLE = zigwin32.system.power.DEVICE_NOTIFY_WINDOW_HANDLE;
pub const TRUE = windows.TRUE;
pub const FALSE = windows.FALSE;
pub const S_OK = windows.S_OK;
pub const MDT_EFFECTIVE_DPI = zigwin32.ui.hi_dpi.MDT_EFFECTIVE_DPI;
pub const USER_DEFAULT_SCREEN_DPI = @as(u32, 96);
pub const USER_DEFAULT_SCREEN_DPI_F = @as(f64, 96.0);
pub const WHEEL_DELTA = @as(u32, 120);
pub const FWHEEL_DELTA = @as(f64, 120.0);
pub const CF_UNICODETEXT = @as(u32, 0x0D);
pub const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = @as(u32, 0x02);
pub const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = @as(u32, 0x04);

pub const VER_GREATER_EQUAL = @as(u32, 0x03);
pub const CW_USEDEFAULT = @as(i32, -2147483648);

pub const SC_SCREENSAVE = @as(u32, 0x0F140);
pub const SC_MONITORPOWER = @as(u32, 0x0F170);
pub const SC_KEYMENU = @as(u32, 0x0F100);
pub const WM_COPYGLOBALDATA = @as(u32, 0x0049);
pub const XINPUT_GAMEPAD_GUIDE = @as(u32, 0x0400);
pub const WAIT_TIMEOUT = @as(u32, 0x102);

// Mising or couldn't find them in zigwin32 library.
pub const WM_MOUSELEAVE = @as(u32, 0x02A3);
pub const WM_UNICHAR = @as(u32, 0x0109);
pub const DIDFT_OPTIONAL = @as(u32, 0x80000000);
pub const GUID_DEVINTERFACE_HID = GUID.initString("4D1E55B2-F16F-11CF-88CB-001111000030");
// In zigwin32 'EnumDisplaySettingsExW' uses enum(u32) as the type of `iModeNume` parameter
// with only 2 possible values and therfore doesn't allow enumerating all
// device's graphics mode incrementally through a loop.
// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaysettingsexw
pub const ENUM_CURRENT_SETTINGS = @as(u32, 0xFFFFFFFF);
pub const ENUM_REGISTRY_SETTINGS = @as(u32, 0xFFFFFFFE);

///! IDC_Standard Cursors.
pub const IDC_ARROW = utils.MAKEINTRESOURCESA(32512); // Normal select.
pub const IDC_IBEAM = utils.MAKEINTRESOURCESA(32513); // Text select.
pub const IDC_WAIT = utils.MAKEINTRESOURCESA(32514); // Busy.
pub const IDC_CROSS = utils.MAKEINTRESOURCESA(32515); // Precision select.
pub const IDC_SIZEALL = utils.MAKEINTRESOURCESA(32646); // Move.
pub const IDC_NO = utils.MAKEINTRESOURCESA(32648); // Unavailable.
pub const IDC_HAND = utils.MAKEINTRESOURCESA(32649); // Link select.
pub const IDC_APPSTARTING = utils.MAKEINTRESOURCESA(32650); // Working in background.
pub const IDC_HELP = utils.MAKEINTRESOURCESA(32651); // Help select.

///! OCR_Standard Cursors.
pub const OCR_NORMAL = @as(u16, 32512);
pub const OCR_IBEAM = @as(u16, 32513);
pub const OCR_WAIT = @as(u16, 32514);
pub const OCR_CROSS = @as(u16, 32515);
pub const OCR_UP = @as(u16, 32516);
pub const OCR_SIZENWSE = @as(u16, 32642);
pub const OCR_SIZENESW = @as(u16, 32643);
pub const OCR_SIZEWE = @as(u16, 32644);
pub const OCR_SIZENS = @as(u16, 32645);
pub const OCR_SIZEALL = @as(u16, 32646);
pub const OCR_NO = @as(u16, 32648);

///! Functions
pub extern "user32" fn EnumDisplaySettingsExW(
    lpszDeviceName: ?[*:0]const u16,
    iModeNum: u32,
    lpDevMode: ?*zigwin32.graphics.gdi.DEVMODEW,
    dwFlags: u32,
) callconv(WINAPI) BOOL;

pub const LPCWSTR = if (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .i386)
    [*:0]align(1) const u16
else
    [*:0]const u16;

pub extern "user32" fn UnregisterClassW(
    lpClassName: ?LPCWSTR,
    hInstance: ?HINSTANCE,
) callconv(WINAPI) BOOL;

pub extern "user32" fn CreateWindowExW(
    dwExStyle: u32,
    lpClassName: ?LPCWSTR,
    lpWindowName: ?[*:0]const u16,
    dwStyle: u32,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(WINAPI) ?HWND;

pub extern "user32" fn LoadImageW(
    hInst: ?HINSTANCE,
    name: ?LPCWSTR,
    type: u32,
    cx: i32,
    cy: i32,
    fuLoad: u32,
) callconv(WINAPI) ?windows.HANDLE;

pub const SetProcessDPIAwareProc = *const fn () callconv(WINAPI) BOOL;

pub const RtlVerifyVersionInfoProc = *const fn (
    *OSVERSIONINFOEXW,
    u32,
    u64,
) callconv(WINAPI) NTSTATUS;

pub const SetProcessDpiAwarenessProc = *const fn (
    PROCESS_DPI_AWARENESS,
) callconv(WINAPI) HRESULT;

pub const SetProcessDpiAwarenessContextProc = *const fn (
    DPI_AWARENESS_CONTEXT,
) callconv(WINAPI) HRESULT;

pub const EnableNonClientDpiScalingProc = *const fn (HWND) callconv(WINAPI) BOOL;

pub const GetDpiForWindowProc = *const fn (HWND) callconv(WINAPI) DWORD;

pub const GetDpiForMonitorProc = *const fn (
    HMONITOR,
    MONITOR_DPI_TYPE,
    *u32,
    *u32,
) callconv(WINAPI) HRESULT;

pub const AdjustWindowRectExForDpiProc = *const fn (
    *RECT,
    u32,
    i32,
    u32,
    u32,
) callconv(WINAPI) BOOL;
