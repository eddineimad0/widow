const std = @import("std");
const widow = @import("widow");

pub fn main() !void {
    const testing = std.testing;
    var cntxt = try widow.WidowContext.init(testing.allocator);
    defer cntxt.deinit();
    std.debug.print("Widow Struct size:{}", .{@sizeOf(widow.WidowContext)});
    var window = try widow.window.WindowBuilder.init("creation_test", 800, 600).build(&cntxt);
    window.deinit();
}
