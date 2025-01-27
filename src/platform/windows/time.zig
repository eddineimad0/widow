const perf = @import("zigwin32").system.performance;

pub inline fn getTimerFrequency() u64 {
    var f: i64 = undefined;
    _ = perf.QueryPerformanceFrequency(&f);
    return @intCast(f);
}

pub inline fn getTimerTicks() i64 {
    var f: i64 = undefined;
    _ = perf.QueryPerformanceCounter(&f);
    return f;
}
