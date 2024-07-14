const time = @import("platform").time;

pub const Timer = struct {
    freq: u64,

    const Self = @This();

    pub fn init() Self {
        return .{
            .freq = time.getTimerFrequency(),
        };
    }

    pub inline fn ticksCount() i64 {
        return time.getTimerTicks();
    }

    pub fn now(self: *const Self) f64 {
        const ticks = ticksCount();
        return @as(f64, @floatFromInt(ticks)) /
            @as(f64, @floatFromInt(self.freq));
    }
};

test "Timer API" {
    const std = @import("std");
    const testing = std.testing;
    const t = Timer.init();

    const initial_ticks = t.ticksCount();
    while (t.now() < 3.0) {
        asm volatile ("nop");
    }
    const elapsed_ticks = t.ticksCount() - initial_ticks;
    const elapsed = @as(f64, @floatFromInt(elapsed_ticks)) /
        @as(f64, @floatFromInt(t.freq));

    try testing.expectApproxEqRel(elapsed, @as(f64, 3.0), std.math.floatEps(f64));
}
