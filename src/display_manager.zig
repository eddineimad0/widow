const std = @import("std");
const mem = std.mem;
const platform = @import("platform");

pub const DisplayManager = struct {
    impl: platform.DisplayManager,
    allocator: mem.Allocator,
    const Self = @This();

    pub fn init(allocator: mem.Allocator) !Self {
        // INFO: the platform implementation should alway be heap
        // allocated to avoid pointer issues with callbacks.
        const impl = try allocator.create(platform.DisplayManager);
        errdefer allocator.destroy(impl);
        impl.* = platform.DisplayManager.init(allocator);
        try impl.initDisplays();

        return .{ .impl = impl, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.impl.deinit();
        self.allocator.destroy(self.impl);
        self.impl = undefined;
    }
};
