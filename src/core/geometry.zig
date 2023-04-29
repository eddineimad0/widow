// Failed Generic attempt.
// pub fn WidowSize(comptime T: type) type {
//     return struct {
//         width: T,
//         height: T,
//
//         const Self = @This();
//
//         pub fn init(width: T, height: T) !Self {
//             if (width < 0 or height < 0) {
//                 return WidowSizeError.NegativeSize;
//             }
//             return Self{
//                 .width = width,
//                 .height = height,
//             };
//         }
//
//         pub fn scale(self: *Self, scaler: f64) !void {
//             if (scaler < 0.0) {
//                 return WidowSizeError.NegativeScaler;
//             }
//             self.width = @ceil((@intToFloat(f64, self.width) * scaler));
//             self.height = @ceil((@intToFloat(f64, self.height) * scaler));
//         }
//     };
// }
//

pub const WidowPoint2D = struct {
    x: i32,
    y: i32,

    const Self = @This();

    pub fn init(x: i32, y: i32) Self {
        return Self{
            .x = x,
            .y = y,
        };
    }
};

pub const WidowFPoint2D = struct {
    x: f64,
    y: f64,

    const Self = @This();

    pub fn init(x: f64, y: f64) Self {
        return Self{
            .x = x,
            .y = y,
        };
    }
};

pub const WidowSize = struct {
    width: i32,
    height: i32,

    const Self = @This();

    pub fn init(width: i32, height: i32) Self {
        return Self{
            .width = width,
            .height = height,
        };
    }

    pub fn scale(self: *Self, scaler: f64) void {
        self.width = @floatToInt(i32, (@intToFloat(f64, self.width) * scaler));
        self.height = @floatToInt(i32, (@intToFloat(f64, self.height) * scaler));
    }
};

pub const WidowFSize = struct {
    width: f64,
    height: f64,

    const Self = @This();

    pub fn init(width: f64, height: f64) Self {
        return Self{
            .width = width,
            .height = height,
        };
    }

    pub fn scale(self: *Self, scaler: f64) void {
        self.width = self.width * scaler;
        self.height = self.height * scaler;
    }
};
