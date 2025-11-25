const std = @import("std");
const com = @import("com.zig");
const win32 = std.os.windows;

//--------------
// Constants
//-------------
const CLSCTX_INPROC_SERVER = @as(win32.DWORD, 0x1);
const CLSCTX_INPROC_HANDLER = @as(win32.DWORD, 0x2);
const CLSCTX_LOCAL_SERVER = @as(win32.DWORD, 0x4);
const CLSCTX_REMOTE_SERVER = @as(win32.DWORD, 0x10);

/// use this constant to tell COM to try every execution context that can host the requested object
pub const CLSCTX_ALL = CLSCTX_INPROC_SERVER | CLSCTX_INPROC_HANDLER | CLSCTX_REMOTE_SERVER | CLSCTX_LOCAL_SERVER;

//---------------------------
// Functions
//---------------------------
pub extern "Ole32" fn CoInitializeEx(pvReserved: ?*anyopaque, dwCoInit: win32.DWORD) callconv(.winapi) win32.HRESULT;
pub extern "Ole32" fn CoUninitialize() callconv(.winapi) void;
pub extern "Ole32" fn CoCreateInstance(
    rclsid: *const win32.GUID,
    pUnkOuter: ?*com.IUnknown,
    dwClsContext: win32.DWORD,
    riid: *const win32.GUID,
    ppv: *win32.LPVOID,
) callconv(.winapi) win32.HRESULT;

pub extern "Ole32" fn CoTaskMemFree(pv: win32.LPVOID) callconv(.winapi) void;

pub inline fn FAILED(result: win32.HRESULT) bool {
    return result < 0;
}
