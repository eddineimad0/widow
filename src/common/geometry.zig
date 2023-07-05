pub const WidowPoint2D = struct {
    x: i32,
    y: i32,
};

// Shhhhhh.
pub const AspectRatio = WidowPoint2D;

pub const WidowSize = struct {
    width: i32,
    height: i32,

    const Self = @This();

    pub fn scaleBy(self: *Self, scaler: f64) void {
        self.width = @floatToInt(i32, (@intToFloat(f64, self.width) * scaler));
        self.height = @floatToInt(i32, (@intToFloat(f64, self.height) * scaler));
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
