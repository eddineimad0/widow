pub const video_mode = @import("video_mode.zig");
pub const geometry = @import("geometry.zig");
pub const window_data = @import("window_data.zig");
pub const event = @import("event.zig");
pub const keyboard_mouse = @import("keyboard_mouse.zig");
pub const cursor = @import("cursor.zig");
pub const fb = @import("framebuffer.zig");
pub const pixel = @import("pixel.zig");
pub const envinfo = @import("envinfo.zig");
pub const audio = @import("audio.zig");

/// bunch of options to customize the WidowContext creation
pub const WidowContextOptions = struct {
    /// if true the compiled can't have more than one instance running at a time
    /// this done:
    /// * on windows: by opening a lock non shareable file in the executable directory
    /// said file is deleted upon program exist
    force_single_instance: bool = false,

    win32: struct {
        wndclass_name: []const u8 = "WIDOW_APPLICATION_CLASS",
        icon_res_name: ?[]const u8 = null,
    } = .{},
    x11: struct {
        class_name: []const u8 = "WIDOW_APPLICATION_CLASS",
        res_name: []const u8 = "WIDOW_APPLICATION",
    } = .{},
};

const builtin = @import("builtin");
pub const unix = if (builtin.target.os.tag == .windows)
{} else @import("unix/unix.zig");
pub const IS_DEBUG_BUILD = builtin.mode == .Debug;

const queue = @import("queue.zig");
const deque = @import("deque.zig");

test "common_module_tests" {
    const std = @import("std");
    const testing = std.testing;

    testing.refAllDecls(queue);
    testing.refAllDecls(deque);
}
