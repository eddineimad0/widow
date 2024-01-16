pub const video_mode = @import("video_mode.zig");
pub const geometry = @import("geometry.zig");
pub const window_data = @import("window_data.zig");
pub const event = @import("event.zig");
pub const list = @import("queue.zig");
pub const keyboard_and_mouse = @import("keyboard_and_mouse.zig");
pub const cursor = @import("cursor.zig");
pub const joystick = @import("joystick.zig");

pub const IS_DEBUG = @import("builtin").mode == .Debug;
