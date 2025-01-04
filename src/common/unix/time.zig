const std = @import("std");
const posix = std.posix;
const time = std.time;

var __clock: i32 = posix.CLOCK.MONOTONIC;
pub inline fn getTimerFrequency() u64 {
    var res: posix.timespec = undefined;
    posix.clock_getres(__clock, &res) catch |e| {
        switch (e) {
            posix.ClockGetTimeError.UnsupportedClock => {
                __clock = posix.CLOCK.REALTIME; // Fallback to realtime clock
                return getTimerFrequency();
            },
            else => return 0,
        }
    };
    return @intCast(res.tv_nsec + (res.tv_sec * time.ns_per_s));
}

pub inline fn getTimerTicks() i64 {
    var res: posix.timespec = undefined;
    posix.clock_gettime(__clock, &res) catch |e| {
        switch (e) {
            posix.ClockGetTimeError.UnsupportedClock => {
                __clock = posix.CLOCK.REALTIME; // Fallback to realtime clock
                return getTimerTicks();
            },
            else => return 0,
        }
    };
    return res.tv_nsec + (res.tv_sec * time.ns_per_s);
}
