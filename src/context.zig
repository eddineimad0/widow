const std = @import("std");
const mem = std.mem;
const platform = @import("platform");
const Window = @import("window.zig").Window;
const common = @import("common");
const geometry = common.geometry;

/// A widow context represent an interface to the platform
/// and is required by other entities in the library
/// to communicate with platform
pub const WidowContext = struct {
    platform_internals: *platform.Internals,
    monitor_store: *platform.MonitorStore,
    events_queue: common.event.EventQueue,
    allocator: mem.Allocator,
    next_window_id: u32, // keeps track of assigned ids.

    const Self = @This();

    /// Creates an instance of the WidowContext.
    /// # Parameters
    /// `allocator`: the memory allocator to be used by the libaray.
    /// # Notes
    /// An instance of the WidowContext is necessary to use
    /// the library, and is required to initialize a window
    /// instance.
    /// User should destroy the instance once done using the library,
    /// to free allocated ressources.
    /// There can only be one instance at a time trying
    /// to initialize more would throw an error.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation failure.
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self: Self = undefined;
        self.platform_internals = try platform.Internals.create(allocator);
        errdefer self.platform_internals.destroy(allocator);
        // TODO: remove this refrence.
        self.monitor_store = try self.platform_internals.initMonitorStoreImpl(allocator);
        self.events_queue = common.event.EventQueue.init(allocator);
        self.allocator = allocator;
        self.next_window_id = 0;
        return self;
    }

    /// deinitialize the instance and free allocated ressources.
    /// # Parameters
    /// `allocator`: the memory allocator used during initialization.
    /// # Note
    /// the WidowContext instance should be the last thing you deinitialize,
    /// as all other created library entities hold
    /// a refrence to it, deinitializing this one before the others will cause
    /// undefined behaviour and crash you application.
    pub fn deinit(self: *Self) void {
        self.platform_internals.destroy(self.allocator);
    }

    /// Retrieves an event from the event queue,
    /// returns false if the queue is empty, true if the `event` parameter was populated.
    /// # Parameters
    /// `event`: pointer to an event variable to be populated.
    pub inline fn pollEvents(self: *Self, event: *common.event.Event) bool {
        return self.events_queue.popEvent(event);
    }

    /// Returns the current text content of the system clipboard.
    /// # Notes
    /// This function fails if the clipboard doesn't contain a proper unicode formatted string.
    /// On success the clipboard value is cached for future calls until the clipboard is updated.
    /// The caller doesn't own the returned slice and shouldn't free it.
    pub inline fn clipboardText(self: *Self) ![]const u8 {
        return self.platform_internals.clipboardText(self.allocator);
    }

    /// Copys the given `text` slice to the system clipboard.
    /// # Parameters
    /// `text`: a slice of the unicode data to be copied.
    pub inline fn setClipboardText(self: *Self, text: []const u8) !void {
        return self.platform_internals.setClipboardText(self.allocator, text);
    }

    /// Returns the next available window ID.
    inline fn nextWindowId(self: *Self) u32 {
        self.next_window_id += 1;
        return self.next_window_id;
    }
};

pub const WindowBuilder = struct {
    allocator: std.mem.Allocator,
    context: *WidowContext,
    window_attributes: common.window_data.WindowData,
    title: []u8,
    const Self = @This();

    /// Creates a window builder instance.
    /// The window builder wraps the creation attributes of the window,
    /// and the functions necessary to changes those attributes.
    /// # Parameters
    /// `title`: the title to be displayed in the window's caption bar.
    /// `width`: intial width of the window.
    /// `height`: intial height of the window.
    /// `context`: a pointer to the WidowContext instance.
    /// # Notes
    /// The context parameter should point to an initialzed WidowContext instance that lives
    /// as long as the window, i.e destroying the WidowContext instance before the window is destroyed
    /// causes undefined behaviour.
    /// Call `deinit()` when done using the WindowBuilder.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation Failure.
    pub fn init(
        title: []const u8,
        width: i32,
        height: i32,
        context: *WidowContext,
    ) !Self {
        std.debug.assert(width > 0 and height > 0);
        // Can't be sure of the title's lifetime so copy it first.
        const new_title = try context.allocator.alloc(u8, title.len);
        std.mem.copyForwards(u8, new_title, title);
        return Self{
            .allocator = context.allocator,
            .context = context,
            .title = new_title,
            // Defalut attributes
            .window_attributes = common.window_data.WindowData{
                .id = 0,
                .client_area = common.geometry.WidowArea.init(
                    platform.window_impl.WindowImpl.WINDOW_DEFAULT_POSITION.x,
                    platform.window_impl.WindowImpl.WINDOW_DEFAULT_POSITION.y,
                    width,
                    height,
                ),
                .min_size = null,
                .max_size = null,
                .aspect_ratio = null,
                .flags = .{
                    .is_visible = true,
                    .is_maximized = false,
                    .is_minimized = false,
                    .is_resizable = false,
                    .is_decorated = true,
                    .is_topmost = false,
                    .is_focused = false,
                    .is_fullscreen = false,
                    .cursor_in_client = false,
                    .is_dpi_aware = false,
                },
                .input = common.keyboard_mouse.InputState.init(),
            },
        };
    }

    // Frees allocated ressources.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title);
        self.title = undefined;
    }

    /// Creates and returns the built window instance.
    /// # Notes
    /// The user should deinitialize the Window instance when done.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn build(self: *Self) !Window {
        // First window has id of 1,
        self.window_attributes.id = self.context.nextWindowId();
        // The Window should copy the title if needed.
        const window = Window.init(
            self.allocator,
            self.title,
            &self.window_attributes,
            &self.context.events_queue,
            self.context.platform_internals,
        );
        return window;
    }

    /// Set the window title.
    /// # Parameters
    /// `title`: the new title to replace the current one.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn withTitle(self: *Self, title: []const u8) !*Self {
        const new_title = try self.allocator.alloc(u8, title.len);
        std.mem.copyForwards(u8, new_title, title);
        self.allocator.free(self.title);
        self.title = new_title;
        return self;
    }

    /// Set the window width and height.
    /// # Parameters
    /// `width`: the new width to replace the current one.
    /// `height`: the new height to replace the current one.
    /// # Notes
    /// If the window is DPI aware the final width and height
    /// might be diffrent in window mode but the video mode for
    /// exclusive fullscreen mode retain the given widht and height.
    pub fn withSize(self: *Self, width: i32, height: i32) *Self {
        std.debug.assert(width > 0 and height > 0);
        self.window_attributes.client_area.size.width = width;
        self.window_attributes.client_area.size.height = height;
        return self;
    }

    /// Whether the window is visible(true) or hidden(false).
    /// if not set the default is visible.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withVisibility(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_visible = value;
        return self;
    }

    /// Choose the position of the client(content area)'s top left corner.
    /// If not set the default is decided by the system.
    /// # Parameters
    /// `x`: the y coordinates of the client's top left corner.
    /// `y`: the y coordinates of the client's top left corner.
    pub fn withPosition(self: *Self, x: i32, y: i32) *Self {
        self.window_attributes.client_area.top_left.x = x;
        self.window_attributes.client_area.top_left.y = y;
        return self;
    }

    /// Make the window resizable.
    /// The window is not resizable by default.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withResize(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_resizable = value;
        return self;
    }

    /// Whether the window has a frame or not.
    /// The default is true.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDecoration(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_decorated = value;
        return self;
    }

    /// Whether the window should stay on top even if it lose focus.
    /// The default is false.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withTopMost(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_topmost = value;
        return self;
    }

    /// Specify a minimum and maximum window size for resizable windows.
    /// No size limitation is applied by default.
    /// # Paramters
    /// `min_size`: the minimum possible size for the window.
    /// `max_size`: the maximum possible size fo the window.
    pub fn withSizeLimit(self: *Self, min_size: *const geometry.WidowSize, max_size: *const geometry.WidowSize) *Self {
        self.window_attributes.min_size = min_size.*;
        self.window_attributes.max_size = max_size.*;
        return self;
    }

    /// Specify whether the window size should be scaled by the monitor Dpi.
    /// scaling is not applied by default.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDPIAware(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_dpi_aware = value;
        return self;
    }
};

test "Widow.init" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer cntxt.deinit(testing.allocator);
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
