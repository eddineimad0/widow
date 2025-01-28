const win32 = @import("std").os.windows;

//====================
// Constants
//===================

//====================
// Types
//====================
pub const HDROP = *opaque {};

//====================
// Functions
//====================
pub extern "shell32" fn DragQueryFileW(
    hDrop: ?HDROP,
    iFile: u32,
    lpszFile: ?[*:0]u16,
    cch: u32,
) callconv(win32.WINAPI) u32;

pub extern "shell32" fn DragFinish(
    hDrop: ?HDROP,
) callconv(win32.WINAPI) void;

pub extern "shell32" fn DragAcceptFiles(
    hWnd: ?win32.HWND,
    fAccept: win32.BOOL,
) callconv(win32.WINAPI) void;
