const math = @import("std").math;
const MAX_U32 = math.maxInt(u32);

/// Holds the Display's current video mode
pub const VideoMode = struct {
    width: i32,
    height: i32,
    frequency: u16,
    color_depth: u8,

    const Self = @This();

    pub fn init(width: i32, height: i32, frequency: u16, color_depth: u8) Self {
        return Self{
            .width = width,
            .height = height,
            .frequency = frequency,
            .color_depth = color_depth,
        };
    }

    pub fn equals(self: *const Self, other: *const Self) bool {
        return (self.width == other.width and self.height == other.height and self.color_depth == other.color_depth and self.frequency == other.frequency);
    }

    /// this function returns the closest video mode to the `desired_mode`
    /// from a slice of supported video modes.
    pub fn selectBestMatch(desired_mode: *const VideoMode, modes: []const VideoMode) *const VideoMode {
        var ret_val = desired_mode;
        var size_diff: i32 = undefined;
        var width_diff: i32 = undefined;
        var height_diff: i32 = undefined;
        var rate_diff: i32 = undefined;
        var color_diff: i32 = undefined;
        var least_distance: u32 = MAX_U32;
        var current_distance: u32 = undefined;

        for (modes) |*mode| {

            // Euclidean distance.
            color_diff = @intCast(i32, mode.color_depth) - @intCast(i32, desired_mode.color_depth);
            color_diff *|= color_diff;
            rate_diff = @intCast(i32, mode.frequency) - @intCast(i32, desired_mode.frequency);
            rate_diff *|= rate_diff;
            width_diff = mode.width - desired_mode.width;
            width_diff *|= width_diff;
            height_diff = mode.height - desired_mode.height;
            height_diff *|= height_diff;
            size_diff = width_diff +| height_diff;
            current_distance = math.sqrt(@intCast(u32, color_diff + rate_diff + size_diff));
            if (current_distance < least_distance) {
                ret_val = mode;
                least_distance = @intCast(u32, current_distance);
            }
        }
        return ret_val;
    }
};
