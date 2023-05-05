const math = @import("std").math;
const MAX_U32 = math.maxInt(u32);
/// Holds the Display's current video mode
pub const VideoMode = struct {
    width: i32,
    height: i32,
    frequency: u16,
    color_depth: u8,

    const Self = @This();

    pub fn init(width: i32, height: i32, color_depth: u8, frequency: u16) Self {
        return Self{
            .width = width,
            .height = height,
            .color_depth = color_depth,
            .frequency = frequency,
        };
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        return (self.width == other.width and self.height == other.height and self.color_depth == other.color_depth and self.frequency == other.frequency);
    }

    /// As implemented by [`GLFW`] library this function returns the
    /// best closest video mode to the `desired_mode` from a slice of supported video modes.
    pub fn select_best_match(desired_mode: *const Self, modes: []const Self) *const Self {
        var ret_val = desired_mode;
        var size_diff: i32 = undefined;
        var least_size_diff: u32 = MAX_U32;
        var rate_diff: i32 = undefined;
        var least_rate_diff: u32 = MAX_U32;
        var color_diff: i32 = undefined;
        var least_color_diff: u32 = MAX_U32;
        var width_diff: i32 = undefined;
        var height_diff: i32 = undefined;

        for (modes) |mode| {
            color_diff = math.absInt(@intCast(i32, mode.color_depth) - @intCast(i32, desired_mode.color_depth)) catch 0;
            width_diff = desired_mode.width - mode.width;
            width_diff *|= width_diff;
            height_diff = desired_mode.height - mode.height;
            height_diff *|= height_diff;
            size_diff = width_diff +| height_diff;
            rate_diff = math.absInt(@intCast(i32, mode.frequency) - @intCast(i32, desired_mode.frequency)) catch 0;

            if (color_diff < least_color_diff or (color_diff == least_color_diff and size_diff < least_size_diff) or (color_diff == least_color_diff and size_diff == least_size_diff and rate_diff < least_rate_diff)) {
                ret_val = &mode;
                least_color_diff = @intCast(u32, color_diff);
                least_size_diff = @intCast(u32, size_diff);
                least_rate_diff = @intCast(u32, rate_diff);
            }
        }
        return desired_mode;
    }
};
