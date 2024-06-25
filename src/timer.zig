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
