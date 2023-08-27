const std = @import("std");
const libc = std.c;

extern "c" fn dlerror() ?[*:0]const u8;

pub inline fn loadPosixModule(module_path: [:0]const u8) ?*anyopaque {
    const RTLD_LAZY = @as(c_int, 0x00001);
    const RTLD_LOCAL = @as(c_int, 0);
    return libc.dlopen(module_path.ptr, RTLD_LAZY | RTLD_LOCAL);
}

inline fn moduleError() [*:0]const u8 {
    return dlerror().?;
}

pub inline fn freePosixModule(module_handle: *anyopaque) void {
    _ = libc.dlclose(module_handle);
}

pub inline fn moduleSymbol(module_handle: *anyopaque, symbol_name: [:0]const u8) ?*anyopaque {
    return libc.dlsym(module_handle, symbol_name.ptr);
}

test "Loading and freeing win32 libraries" {
    const testing = std.testing;
    const module = loadPosixModule("libXrandr.so.2");
    try testing.expect(@intFromPtr(module) != 0);
    const symbol = moduleSymbol(module.?, "XRRGetScreenResourcesCurrent");
    try testing.expect(@intFromPtr(symbol) != 0);
    freePosixModule(module.?);
}
