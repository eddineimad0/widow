pub const video_mode = @import("video_mode.zig");
pub const geometry = @import("geometry.zig");
pub const window_data = @import("window_data.zig");
pub const event = @import("event.zig");
pub const list = @import("queue.zig");
pub const keyboard_and_mouse = @import("keyboard_and_mouse.zig");
pub const cursor = @import("cursor.zig");

const builtin = @import("builtin");
pub const posix = if (builtin.target.os.tag == .windows) {} else @import("posix/posix.zig");
pub const IS_DEBUG = builtin.mode == .Debug;

//TODO: can this be set through build flags ?.
pub const LOG_WINDOW_EVENTS = true;
