const std = @import("std");
const platform = @import("platform");
const Display = platform.Display;

pub const DisplayManager = struct {
    monitors: std.ArrayList(Display),
    used_monitors: u8,
    expected_video_change: bool, // For skipping unnecessary updates.
    // prev_exec_state: sys_power.EXECUTION_STATE,
    const Self = @This();
};
