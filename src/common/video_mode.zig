const std = @import("std");
const math = std.math;

/// Holds the Display's current video mode
pub const VideoMode = struct {
    width: u32,
    height: u32,
    frequency: u16,
    color_depth: u8,

    const Self = @This();

    pub fn init(width: u32, height: u32, frequency: u16, color_depth: u8) Self {
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

    /// This function returns the index of the closest possible video mode to the `desired_mode`
    /// from a slice of supported modes.
    pub fn selectBestMatch(desired_mode: *const VideoMode, modes: []const VideoMode) usize {
        // avoids garbage result.
        std.debug.assert(modes.len != 0);
        var best_index: usize = 0;
        // var result = desired_mode;
        var size_diff: isize = undefined;
        var width_diff: isize = undefined;
        var height_diff: isize = undefined;
        var rate_diff: isize = undefined;
        var color_diff: isize = undefined;
        var least_distance: usize = math.maxInt(usize);
        var current_distance: usize = undefined;

        for (0..modes.len, modes) |i, *mode| {

            // Euclidean distance.
            color_diff = @as(isize, mode.color_depth);
            color_diff -= @as(isize, desired_mode.color_depth);
            color_diff *|= color_diff;

            rate_diff = @as(isize, mode.frequency);
            rate_diff -= @as(isize, desired_mode.frequency);
            rate_diff *|= rate_diff;

            width_diff = @as(isize, mode.width) - @as(isize, desired_mode.width);
            width_diff *|= width_diff;
            height_diff = @as(isize, mode.height) - @as(isize, desired_mode.height);
            height_diff *|= height_diff;
            size_diff = width_diff +| height_diff;

            const distance_square: usize = @as(usize, @intCast(color_diff)) +| @as(usize, @intCast(rate_diff)) +| @as(usize, @intCast(size_diff));
            current_distance = math.sqrt(distance_square);

            if (current_distance < least_distance) {
                best_index = i;
                least_distance = current_distance;
            }
        }
        return best_index;
    }
};
