const krnl32 = @import("win32api/kernel32.zig");

pub inline fn getTimerFrequency() u64 {
    var f: i64 = undefined;
    _ = krnl32.QueryPerformanceFrequency(&f);
    return @intCast(f);
}

pub inline fn getTimerTicks() i64 {
    var f: i64 = undefined;
    _ = krnl32.QueryPerformanceCounter(&f);
    return f;
}
