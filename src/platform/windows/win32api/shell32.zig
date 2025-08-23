const win32 = @import("std").os.windows;

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
) callconv(.winapi) u32;

pub extern "shell32" fn DragFinish(
    hDrop: ?HDROP,
) callconv(.winapi) void;

pub extern "shell32" fn DragAcceptFiles(
    hWnd: ?win32.HWND,
    fAccept: win32.BOOL,
) callconv(.winapi) void;
