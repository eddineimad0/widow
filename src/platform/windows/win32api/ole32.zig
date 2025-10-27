const std = @import("std");
const win32 = std.os.windows;

//---------------------------
// Functions
//---------------------------
pub extern "Ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: win32.DWORD) callconv(.winapi) win32.HRESULT;
pub extern "Ole32" fn CoUninitialize() callconv(.winapi) void;
