const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");

const GetModuleHandleExW = zigwin32.system.library_loader.GetModuleHandleExW;
const LoadLibraryA = zigwin32.system.library_loader.LoadLibraryA;
const FreeLibrary = zigwin32.system.library_loader.FreeLibrary;
const GetProcAddress = zigwin32.system.library_loader.GetProcAddress;

pub const ModuleError = error{FailedToGetHandle};

pub inline fn loadWin32Module(module_name: [:0]const u8) ?win32.HINSTANCE {
    return LoadLibraryA(module_name.ptr);
}

pub inline fn freeWin32Module(module_handle: win32.HINSTANCE) void {
    _ = FreeLibrary(module_handle);
}

pub inline fn getModuleSymbol(module_handle: win32.HINSTANCE, symbol_name: [:0]const u8) ?win32.FARPROC {
    return GetProcAddress(module_handle, symbol_name.ptr);
}

pub fn getProcessHandle() !win32.HINSTANCE {
    var hinstance: ?win32.HINSTANCE = null;
    if (GetModuleHandleExW(
        win32.GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT | win32.GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
        @intToPtr(?[*:0]const u16, @ptrToInt(&getProcessHandle)),
        &hinstance,
    ) == 0) {
        return ModuleError.FailedToGetHandle;
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
