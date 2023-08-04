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
        return (self.width == other.width and
            self.height == other.height and
            self.color_depth == other.color_depth and
            self.frequency == other.frequency);
    }

    /// This function returns the closest possible video mode to the `desired_mode`
    /// from a slice of supported video modes.
    pub fn selectBestMatch(desired_mode: *const VideoMode, modes: []const VideoMode) *const VideoMode {
        var result = desired_mode;
        var size_diff: i32 = undefined;
        var width_diff: i32 = undefined;
        var height_diff: i32 = undefined;
        var rate_diff: i32 = undefined;
        var color_diff: i32 = undefined;
        var least_distance: u32 = MAX_U32;
        var current_distance: u32 = undefined;

        for (modes) |*mode| {

            // Euclidean distance.
            color_diff = @intCast(mode.color_depth);
            color_diff -= @intCast(desired_mode.color_depth);
            color_diff *|= color_diff;

            rate_diff = @intCast(mode.frequency);
            rate_diff -= @intCast(desired_mode.frequency);
            rate_diff *|= rate_diff;

            width_diff = mode.width - desired_mode.width;
            width_diff *|= width_diff;
            height_diff = mode.height - desired_mode.height;
            height_diff *|= height_diff;
            size_diff = width_diff +| height_diff;

            const distance_square: u32 = @intCast(color_diff +| rate_diff +| size_diff);
            current_distance = math.sqrt(distance_square);

            if (current_distance < least_distance) {
                result = mode;
                least_distance = @intCast(current_distance);
            }
        }
        return result;
    }
};
