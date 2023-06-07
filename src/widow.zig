const std = @import("std");
const platform = @import("platform");
const common = @import("common");

pub const WidowContext = struct {
    internals: *platform.internals.Internals,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .internals = try platform.internals.Internals.create(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.internals.destroy(self.allocator);
        self.internals = undefined;
    }

    /// returns the string contained inside the system clipboard.
    /// # Note
    /// This function fails if the clipboard doesn't contain a proper unicode formatted string.
    /// On success the clipboard value is cached for future calls until the clipboard value change.
    /// The Caller shouldn't free the returned slice.
    pub inline fn clipboardText(self: *Self) ![]const u8 {
        return self.internals.clipboardText(self.allocator);
    }

    /// Copys the given `text` to the system clipboard.
    pub inline fn setClipboardText(self: *Self, text: []const u8) !void {
        return self.internals.setClipboardText(self.allocator, text);
    }
};

test "Widow.init" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer {
        cntxt.deinit();
    }
}

test "widow.clipboardText" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer cntxt.deinit();
    const string1 = "Clipboard Test String👌.";
    const string2 = "Maybe widow is a terrible name for the library.";
    try cntxt.setClipboardText(string1);
    const copied_string = try cntxt.clipboardText();
    std.debug.print("\n 1st clipboard value:{s}\n string length:{}\n", .{ copied_string, copied_string.len });
    const copied_string2 = try cntxt.clipboardText();
    std.debug.print("\n 2nd clipboard value:{s}\n string length:{}\n", .{ copied_string2, copied_string2.len });
    testing.expect(copied_string.ptr == copied_string2.ptr); // no reallocation if the clipboard value didn't change.
    try cntxt.setClipboardText(string2);
    const copied_string3 = try cntxt.clipboardText();
    testing.expect(copied_string3.ptr != copied_string.ptr);
    std.debug.print("\n 3rd clipboard value:{s}\n string length:{}\n", .{ copied_string3, copied_string2.len });
}

// Exports
pub const window = @import("window.zig");
pub const event = common.event;
pub const input = common.input;
pub const cursor = common.cursor;
pub const geometry = common.geometry;
pub const FullScreenMode = common.window_data.FullScreenMode;
