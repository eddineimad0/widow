const std = @import("std");
const platform = @import("platform");

const Widow = struct {
    internals: platform.internals.Internals,
    devices: platform.internals.PhysicalDevices,
    allocator: std.mem.Allocator,
    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) !Self {
        var self: Self = undefined;
        self.internals = try platform.internals.Internals.init();
        errdefer self.internals.deinit();
        self.devices = try platform.internals.PhysicalDevices.init(allocator);
        self.allocator = allocator;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.internals.deinit();
        self.devices.deinit();
    }
};

test "should init Widow" {
    const testing = std.testing;
    var cntxt = try Widow.init(testing.allocator);
    defer cntxt.deinit();
}
