const std = @import("std");
const px = @import("pixel.zig");
const mem = std.mem;
const io = std.io;

pub const RenderApi = enum(u8) {
    software,
    opengl,
};

pub const FBAccelration = union(RenderApi) {
    software: void,
    opengl: GLConfig,
};

pub const FBConfig = struct {
    color: packed struct(u16) {
        red_bits: u4,
        green_bits: u4,
        blue_bits: u4,
        alpha_bits: u4,
    },

    accum: packed struct(u16) {
        red_bits: u4,
        green_bits: u4,
        blue_bits: u4,
        alpha_bits: u4,
    },

    accel: FBAccelration,

    depth_bits: u8,
    stencil_bits: u8,

    flags: struct {
        double_buffered: bool,
        sRGB: bool,
        stereo: bool,
    },

    const Self = @This();

    pub inline fn getColorDepth(self: *const Self) u16 {
        var cdepth: u16 = 0;
        cdepth += self.color.red_bits;
        cdepth += self.color.green_bits;
        cdepth += self.color.blue_bits;
        cdepth += self.color.alpha_bits;
        return cdepth;
    }

    pub inline fn getAccumulatorDepth(self: *const Self) u16 {
        var adepth: u16 = 0;
        adepth += self.accum.red_bits;
        adepth += self.accum.green_bits;
        adepth += self.accum.blue_bits;
        adepth += self.accum.alpha_bits;
        return adepth;
    }
};

//=============
// OpenGL
//=============
pub const GLProfile = enum(u1) {
    Compat,
    Core,
};

/// Holds configuration for customizing created
/// opengl context.
pub const GLConfig = struct {
    ver: struct {
        major: u8,
        minor: u8,
    },
    is_debug: bool,
    profile: GLProfile,
};

pub const SwapInterval = enum(i8) {
    Adaptive = -1,
    Immediate = 0,
    Synced = 1,
};

/// Returns true if the `target` extension is in the `ext_list` string
pub fn glHasExtension(target: [*:0]const u8, ext_list: [:0]const u8) bool {
    var haystack = ext_list;
    while (true) {
        const start = mem.indexOf(u8, haystack, mem.span(target));
        if (start) |s| {
            const end = s + mem.len(target);
            if (s == 0 or haystack[s - 1] == ' ') {
                if (haystack[end] == ' ' or haystack[end] == 0) {
                    return true;
                }
            }
            haystack = ext_list[end..];
        } else {
            return false;
        }
    }
}
