const winapi = @import("win32");

pub const HINSTANCE = winapi.foundation.HINSTANCE;
pub const GetModuleHandleExW = winapi.system.library_loader.GetModuleHandleExW;
pub const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT =
    winapi.system.library_loader.GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
pub const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS =
    winapi.system.library_loader.GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS;

const FARPROC = winapi.foundation.FARPROC;
const LoadLibraryA = winapi.system.library_loader.LoadLibraryA;
const FreeLibrary = winapi.system.library_loader.FreeLibrary;
const GetProcAddress = winapi.system.library_loader.GetProcAddress;

pub inline fn loadWin32Module(module_name: [:0]const u8) ?HINSTANCE {
    return LoadLibraryA(module_name.ptr);
}

pub inline fn freeWin32Module(module_handle: HINSTANCE) void {
    _ = FreeLibrary(module_handle);
}

pub inline fn getModuleSymbol(module_handle: HINSTANCE, symbol_name: [:0]const u8) ?FARPROC {
    return GetProcAddress(module_handle, symbol_name.ptr);
}

pub fn getProcessHandle() !HINSTANCE {
    var hinstance: ?HINSTANCE = null;
    if (GetModuleHandleExW(
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT | GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
        @intToPtr(?[*:0]const u16, @ptrToInt(&getProcessHandle)),
        &hinstance,
    ) == 0) {
        return error.FailedToGetModuleHandle;
    }
    return hinstance.?;
}

test "Loading and freeing win32 libraries" {
    const std = @import("std");
    const testing = std.testing;
    const hinstance = try getProcessHandle();
    std.debug.print("\nProcess hinstance:{*}\n", .{hinstance});
    const module = loadWin32Module("ntdll.dll");
    try testing.expect(@ptrToInt(module) != 0);
    const symbol = getModuleSymbol(module.?, "RtlVerifyVersionInfo");
    try testing.expect(@ptrToInt(symbol) != 0);
    freeWin32Module(module.?);
}
