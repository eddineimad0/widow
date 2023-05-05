const win32api = @import("win32");

pub const HINSTANCE = win32api.foundation.HINSTANCE;
const FARPROC = win32api.foundation.FARPROC;

const LoadLibraryA = win32api.system.library_loader.LoadLibraryA;
const FreeLibrary = win32api.system.library_loader.FreeLibrary;
const GetProcAddress = win32api.system.library_loader.GetProcAddress;

pub fn load_win32_module(module_name: [:0]const u8) ?HINSTANCE {
    return LoadLibraryA(module_name.ptr);
}

pub fn free_win32_module(module_handle: HINSTANCE) void {
    _ = FreeLibrary(module_handle);
}

pub fn get_module_symbol(module_handle: HINSTANCE, symbol_name: [:0]const u8) ?FARPROC {
    return GetProcAddress(module_handle, symbol_name.ptr);
}

test "Loading and freeing win32 libraries" {
    const testing = @import("std").testing;
    const module = load_win32_module("ntdll.dll");
    try testing.expect(@ptrToInt(module) != 0);
    const symbol = get_module_symbol(module.?, "RtlVerifyVersionInfo");
    try testing.expect(@ptrToInt(symbol) != 0);
    free_win32_module(module.?);
}
