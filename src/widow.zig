const std = @import("std");
const platform = @import("platform");

pub const window = @import("./window");

pub const WidowContext = struct {
    internals: *platform.internals.Internals,
    is_init: bool,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .internals = try platform.internals.Internals.create(allocator),
            .is_init = true,
        };
    }

    pub fn deinit(self: *Self) void {
        self.internals.destroy();
        self.is_init = false;
    }
};

test "should init Widow" {
    const testing = std.testing;
    var cntxt = try WidowContext.init(testing.allocator);
    defer {
        cntxt.deinit();
        std.debug.print("Deinit success:{}\n", .{!cntxt.is_init});
    }
    std.debug.print("Init success:{}\n", .{cntxt.is_init});
    std.debug.print("Widow Struct size:{}\n", .{@sizeOf(WidowContext)});
}
