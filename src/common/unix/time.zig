const std = @import("std");
const time = std.time;
const posix = std.posix;

const clock_config = struct {
    var clock_id: posix.clockid_t = undefined;
    var config_initialized = std.atomic.Value(bool).init(false);
};

fn initClockConfig() void {
    clock_config.clock_id = .MONOTONIC_RAW;
    _ = posix.clock_gettime(clock_config.clock_id) catch {
        clock_config.clock_id = .MONOTONIC;
    };
    return;
}

pub inline fn getMonotonicClockFrequency() u64 {
    return time.ns_per_s;
}

pub inline fn getMonotonicClockTicks() u64 {
    if (clock_config.config_initialized.load(.acquire) == false) {
        initClockConfig();
        clock_config.config_initialized.store(true, .release);
    }

    var ticks_ns: i64 = 0;
    const now = posix.clock_gettime(clock_config.clock_id) catch return 0;
    ticks_ns += now.sec;
    ticks_ns *= time.ns_per_s;
    ticks_ns += now.nsec;
    return @intCast(ticks_ns);
}

pub fn waitForNs(timeout_ns: u64) void {
    const secs = (timeout_ns / time.ns_per_s);
    const nano_secs = (timeout_ns % time.ns_per_s);
    posix.nanosleep(secs, nano_secs);
}
