const std = @import("std");
const platform = @import("platform");
const common = @import("common");

pub const WidowContext = struct {
    internals: *platform.internals.Internals,
    monitors: *platform.internals.MonitorStore,
    joysticks: ?*platform.joystick.JoystickSubSystem,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Creates an instance of the WidowContext.
    /// # Note
    /// An instance of the WidowContext is necessary to use
    /// the library, and is required to initialize a window
    /// instance.
    /// User should deinitialize the instance once done,
    /// to free the allocated ressources.
    /// There can only be one instance at a time trying
    /// to initialize more would throw an error.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .monitors = try platform.internals.MonitorStore.create(allocator),
            .internals = try platform.internals.Internals.create(allocator),
            .joysticks = null,
            .allocator = allocator,
        };
        self.internals.devices.monitor_store = self.monitors;
        return self;
    }

    /// Free allocated ressources.
    pub fn deinit(self: *Self) void {
        self.internals.destroy(self.allocator);
        self.internals = undefined;
        self.monitors.destroy(self.allocator);
        self.monitors = undefined;
        if (self.joysticks) |joys| {
            joys.destroy(self.allocator);
        }
        self.joysticks = null;
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

    /// Sets  the window's icon to the RGBA pixels data.
    /// # Note
    /// This function expects non-premultiplied, 32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha.
    pub inline fn setWindowIcon(target: *window.Window, pixels: []const u8, width: i32, height: i32) !void {
        std.debug.assert(width > 0 and height > 0);
        std.debug.assert(pixels.len == (width * height * 4));
        try platform.internals.createIcon(target.impl, pixels, width, height);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Note
    /// Unlike [`WidowContext.setWindowIcon`] this function also takes the cooridnates of the
    /// cursor hotspot which is the pixel that the system tracks to decide mouse click
    /// target, the `xhot` and `yhot` parameters represent the x and y coordinates
    /// of that pixel relative to the top left corner of the image, with the x axis directed
    /// to the right and the y axis directed to the bottom.
    /// This function expects non-premultiplied,32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha.
    pub inline fn setWindowCursor(target: *window.Window, pixels: []const u8, width: i32, height: i32, xhot: u32, yhot: u32) !void {
        std.debug.assert(width > 0 and height > 0);
        std.debug.assert(pixels.len == (width * height * 4));
        try platform.internals.createCursor(target.impl, pixels, width, height, xhot, yhot);
    }

    // /// Sets the Widow's cursor to an image from the system's standard cursors.
    // /// # Note
    // /// The new image used by the cursor is loaded by the system therefore,
    // /// the appearance will vary between platforms.
    // pub fn setWindowStdCursor(target: *window.Window, shape: cursor.CursorShape) !void {
    //     try platform.internals.createStandardCursor(target.impl, shape);
    // }

    pub fn initJoystickSubSyst(self: *Self, on_connection_change: common.hid.JoystickConnectCallBack) !void {
        self.joysticks = try platform.joystick.JoystickSubSystem.create(self.allocator, on_connection_change);
    }
};

test "Widow.init" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer cntxt.deinit();
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
    try testing.expect(copied_string.ptr == copied_string2.ptr); // no reallocation if the clipboard value didn't change.
    try cntxt.setClipboardText(string2);
    const copied_string3 = try cntxt.clipboardText();
    try testing.expect(copied_string3.ptr != copied_string.ptr);
    std.debug.print("\n 3rd clipboard value:{s}\n string length:{}\n", .{ copied_string3, copied_string2.len });
}

test "widow modules" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}

// Exports
pub const window = @import("window.zig");
pub const event = common.event;
pub const input = common.keyboard_and_mouse;
pub const cursor = common.cursor;
pub const geometry = common.geometry;
pub const FullScreenMode = common.window_data.FullScreenMode;
