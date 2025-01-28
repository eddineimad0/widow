const win32 = @import("std").os.windows;

//-------------------------
// Types
//-------------------------
pub const WNDCLASS_STYLES = packed struct(u32) {
    VREDRAW: u1 = 0,
    HREDRAW: u1 = 0,
    _2: u1 = 0,
    DBLCLKS: u1 = 0,
    _4: u1 = 0,
    OWNDC: u1 = 0,
    CLASSDC: u1 = 0,
    PARENTDC: u1 = 0,
    _8: u1 = 0,
    NOCLOSE: u1 = 0,
    _10: u1 = 0,
    SAVEBITS: u1 = 0,
    BYTEALIGNCLIENT: u1 = 0,
    BYTEALIGNWINDOW: u1 = 0,
    GLOBALCLASS: u1 = 0,
    _15: u1 = 0,
    IME: u1 = 0,
    DROPSHADOW: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};

pub const WNDPROC = *const fn (
    param0: win32.HWND,
    param1: u32,
    param2: win32.WPARAM,
    param3: win32.LPARAM,
) callconv(win32.WINAPI) win32.LRESULT;

pub const WNDCLASSEXW = extern struct {
    cbSize: u32,
    style: WNDCLASS_STYLES,
    lpfnWndProc: ?WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: ?win32.HINSTANCE,
    hIcon: ?win32.HICON,
    hCursor: ?win32.HCURSOR,
    hbrBackground: ?win32.HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: ?[*:0]const u16,
    hIconSm: ?win32.HICON,
};

//---------------------------
// Functions
//---------------------------

pub extern "user32" fn RegisterClassExW(
    unnamedParam1: ?*const WNDCLASSEXW,
) callconv(win32.WINAPI) u16;

pub extern "user32" fn UnregisterClassW(
    lpClassName: ?win32.LPCWSTR,
    hInstance: ?win32.HINSTANCE,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn MapVirtualKeyW(
    uCode: win32.UINT,
    uMapType: win32.UINT,
) callconv(win32.WINAPI) win32.UINT;

pub extern "user32" fn GetKeyState(
    nVirtKey: win32.INT,
) callconv(win32.WINAPI) win32.SHORT;

pub extern "user32" fn PostMessageW(
    hWnd: ?win32.HWND,
    Msg: win32.UINT,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(win32.WINAPI) win32.BOOL;
