const std = @import("std");
const platform = @import("platform");
const common = @import("common");

pub const WidowContext = struct {
    internals: ?*platform.internals.Internals,
    allocator: std.mem.Allocator,
    is_init: bool,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .internals = try platform.internals.Internals.create(allocator),
            .allocator = allocator,
            .is_init = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.internals.?.destroy(self.allocator);
        self.internals = null;
        self.is_init = false;
    }

    /// returns the string contained inside the system clipboard.
    /// # Note
    /// This function fails if the clipboard doesn't contain a proper unicode formatted string.
    /// The caller is responsible for freeing the returned string.
    /// The allocator use for allocating the string is the same one passed during initialization of this WidowContext
    /// instance.
    pub inline fn clipboardText(self: *Self) ![:0]u8 {
        return self.internals.?.clipboardText(self.allocator);
    }

    /// Copys the given `text` to the system clipboard.
    pub inline fn setClipboardText(self: *Self, text: []const u8) !void {
        return self.internals.?.setClipboardText(self.allocator, text);
    }
};

test "Should init Widow" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer {
        cntxt.deinit();
    }
}

// Exports
pub const window = @import("window.zig");
pub const event = common.event;
pub const input = common.input;
pub const cursor = common.cursor;
pub const geometry = common.geometry;
pub const FullScreenMode = common.window_data.FullScreenMode;
