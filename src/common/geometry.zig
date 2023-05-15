pub const WidowPoint2D = struct {
    x: i32,
    y: i32,
};

pub const WidowFPoint2D = struct {
    x: f64,
    y: f64,

    // const Self = @This();
    //
    // pub fn init(x: f64, y: f64) Self {
    //     return Self{
    //         .x = x,
    //         .y = y,
    //     };
    // }
};

pub const WidowSize = struct {
    width: i32,
    height: i32,

    const Self = @This();

    // pub fn init(width: i32, height: i32) Self {
    //     return Self{
    //         .width = width,
    //         .height = height,
    //     };
    // }

    pub fn scale(self: *Self, comptime scaler: comptime_float) void {
        self.width = @floatToInt(i32, (@intToFloat(@TypeOf(scaler), self.width) * scaler));
        self.height = @floatToInt(i32, (@intToFloat(@TypeOf(scaler), self.height) * scaler));
    }
};

pub const WidowFSize = struct {
    width: f64,
    height: f64,

    const Self = @This();

    pub fn scale(self: *Self, comptime scaler: comptime_float) void {
        self.width = self.width * scaler;
        self.height = self.height * scaler;
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

pub const WidowFArea = struct {
    top_left: WidowFPoint2D,
    size: WidowFSize,
    const Self = @This();
    pub fn init(x: f64, y: f64, width: f64, height: f64) Self {
        return Self{
            .top_left = WidowFPoint2D{ .x = x, .y = y },
            .size = WidowFSize{ .width = width, .height = height },
        };
    }
};
