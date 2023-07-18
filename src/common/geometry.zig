pub const WidowPoint2D = struct {
    x: i32,
    y: i32,
};

// Shhhhhh.
pub const AspectRatio = WidowPoint2D;

pub const WidowSize = struct {
    // The width and hight are both i32 and not u32
    // for best compatibility with the API functions
    // that expects i32 data type for both width and height.
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
