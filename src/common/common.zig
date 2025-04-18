pub const video_mode = @import("video_mode.zig");
pub const geometry = @import("geometry.zig");
pub const window_data = @import("window_data.zig");
pub const event = @import("event.zig");
pub const keyboard_mouse = @import("keyboard_mouse.zig");
pub const cursor = @import("cursor.zig");
pub const fb = @import("framebuffer.zig");

const builtin = @import("builtin");
pub const unix = if (builtin.target.os.tag == .windows) {} else @import("unix/unix.zig");
pub const IS_DEBUG_BUILD = builtin.mode == .Debug;

const queue = @import("queue.zig");
const deque = @import("deque.zig");


test "common_mod_tests" {
    const std = @import("std");
    const testing = std.testing;

    testing.refAllDeclsRecursive(queue);
    testing.refAllDeclsRecursive(deque);

    try testing.expect(false);
}
