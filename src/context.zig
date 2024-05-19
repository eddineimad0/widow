const std = @import("std");
const mem = std.mem;
const platform = @import("platform");
const common = @import("common");
const geometry = common.geometry;

/// TODO: redoc
/// A widow context represent an interface to the platform
/// and is required by other entities in the library
/// to communicate with platform
pub const WidowContext = struct {
    platform_internals: *platform.Internals,
    monitor_store: *platform.MonitorStore,
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

    // /// Retrieves an event from the event queue,
    // /// returns false if the queue is empty, true if the `event` parameter was populated.
    // /// # Parameters
    // /// `event`: pointer to an event variable to be populated.
    // pub inline fn pollEvents(self: *Self, event: *common.event.Event) bool {
    //     return self.events_queue.popEvent(event);
    // }

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
    pub inline fn nextWindowId(self: *Self) u32 {
        self.next_window_id += 1;
        return self.next_window_id;
    }
};

test "WidowContext init" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer cntxt.deinit(testing.allocator);
}
