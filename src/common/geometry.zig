const std = @import("std");
pub const WidowPoint2D = struct {
    x: i32,
    y: i32,
};

// Shhhhhh.
pub const WidowAspectRatio = WidowPoint2D;

pub const WidowSize = struct {
    // The width and hight are both i32 and not u32
    // for best compatibility with the API functions
    // that expects int data type for both width and height.
    width: i32,
    height: i32,

    const Self = @This();

    pub fn scaleBy(self: *Self, scaler: f64) void {
        std.debug.assert(scaler > 0.0);
        const fwidth: f64 = @floatFromInt(self.width);
        const fheight: f64 = @floatFromInt(self.height);
        self.width = @intFromFloat(fwidth * scaler);
        self.height = @intFromFloat(fheight * scaler);
    }
};

pub const WidowArea = struct {
    top_left: WidowPoint2D,
    size: WidowSize,

    const Self = @This();
    pub fn init(x: i32, y: i32, width: i32, height: i32) Self {
        return Self{
            .top_left = WidowPoint2D{ .x = x, .y = y },
            .size = WidowSize{ .width = width, .height = height },
        };
    }
};
