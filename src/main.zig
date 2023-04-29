const std = @import("std");
const testing = std.testing;
const geometry = @import("./core/geometry.zig");

export fn add(a: i32, b: i32) i32 {
    var size = geometry.WidowSize.init(a, a) catch {
        return 0;
    };
    size.scale(@intToFloat(f64, b)) catch {
        std.debug.print("Failed to scale the size by parameter {}", .{b});
    };
    return size.width;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 21);
}
