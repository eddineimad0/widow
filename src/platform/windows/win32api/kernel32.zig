//! This file holds windows kernel bindings
const std = @import("std");
const win32 = std.os.windows;

//==========================
// Constants
//==========================
pub const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = @as(u32, 0x02);
pub const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = @as(u32, 0x04);
pub const VER_GREATER_EQUAL = @as(u32, 0x03);

//===========================
// Types
//==========================
pub const OSVERSIONINFOEXW = extern struct {
    dwOSVersionInfoSize: win32.ULONG,
    dwMajorVersion: win32.ULONG,
    dwMinorVersion: win32.ULONG,
    dwBuildNumber: win32.ULONG,
    dwPlatformId: win32.ULONG,
    szCSDVersion: [128]win32.WCHAR,
    wServicePackMajor: win32.USHORT,
    wServicePackMinor: win32.USHORT,
    wSuiteMask: win32.USHORT,
    wProductType: win32.UCHAR,
    wReserved: win32.UCHAR,
};
pub const VER_FLAGS = packed struct(u32) {
    MINORVERSION: u1 = 0,
    MAJORVERSION: u1 = 0,
    BUILDNUMBER: u1 = 0,
    PLATFORMID: u1 = 0,
    SERVICEPACKMINOR: u1 = 0,
    SERVICEPACKMAJOR: u1 = 0,
    SUITENAME: u1 = 0,
    PRODUCT_TYPE: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
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
pub const VER_MINORVERSION = VER_FLAGS{ .MINORVERSION = 1 };
pub const VER_MAJORVERSION = VER_FLAGS{ .MAJORVERSION = 1 };
pub const VER_BUILDNUMBER = VER_FLAGS{ .BUILDNUMBER = 1 };
pub const VER_PLATFORMID = VER_FLAGS{ .PLATFORMID = 1 };
pub const VER_SERVICEPACKMINOR = VER_FLAGS{ .SERVICEPACKMINOR = 1 };
pub const VER_SERVICEPACKMAJOR = VER_FLAGS{ .SERVICEPACKMAJOR = 1 };
pub const VER_SUITENAME = VER_FLAGS{ .SUITENAME = 1 };
pub const VER_PRODUCT_TYPE = VER_FLAGS{ .PRODUCT_TYPE = 1 };

//---------------------------
// Functions
//---------------------------
pub extern "kernel32" fn FreeLibrary(hLibModule: win32.HMODULE) callconv(win32.WINAPI) win32.BOOL;

pub extern "kernel32" fn GetProcAddress(
    hModule: win32.HMODULE,
    lpProcName: [*:0]const u8,
) callconv(win32.WINAPI) ?win32.FARPROC;

pub extern "kernel32" fn LoadLibraryA(
    lpLibFileName: [*:0]const u8,
) callconv(win32.WINAPI) ?win32.HMODULE;

pub extern "kernel32" fn GetLastError() callconv(win32.WINAPI) win32.DWORD;
pub extern "kernel32" fn SetLastError(dwErrCode: win32.DWORD) callconv(win32.WINAPI) void;
pub extern "kernel32" fn GetModuleFileNameW(
    hModule: ?win32.HMODULE,
    lpFilename: win32.LPWSTR,
    nSize: win32.DWORD,
) callconv(win32.WINAPI) win32.DWORD;
pub extern "kernel32" fn GetCurrentDirectoryW(
    nBufferLength: win32.DWORD,
    lpBuffer: ?win32.LPWSTR,
) callconv(win32.WINAPI) win32.DWORD;
pub extern "kernel32" fn GetComputerNameA(
    lpBuffer: win32.LPSTR,
    nSize: *win32.DWORD,
) callconv(win32.WINAPI) win32.BOOL;
pub extern "kernel32" fn GetLargePageMinimum() callconv(win32.WINAPI) win32.SIZE_T;

pub extern "kernel32" fn GetModuleHandleExW(
    dwFlags: win32.DWORD,
    lpModuleName: win32.LPCWSTR,
    phModule: ?win32.HMODULE,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "kernel32" fn VerSetConditionMask(
    ConditionMask: u64,
    TypeMask: VER_FLAGS,
    Condition: u8,
) callconv(@import("std").os.windows.WINAPI) u64;
