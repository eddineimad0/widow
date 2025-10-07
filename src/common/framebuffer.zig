const std = @import("std");
const mem = std.mem;

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

pub const FBAccelrationTag = enum(u8) {
    software,
    opengl,
};

pub const FBAccelration = union(FBAccelrationTag) {
    software: void,
    opengl: GLConfig,
};

pub const FBConfig = struct {
    color_bits: packed struct(u16) {
        red_bits: u4,
        green_bits: u4,
        blue_bits: u4,
        alpha_bits: u4,
    },

    accum_bits: packed struct(u16) {
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
        var cdepth: u8 = 0;
        cdepth += self.red_bits;
        cdepth += self.green_bits;
        cdepth += self.blue_bits;
        cdepth += self.alpha_bits;
        return cdepth;
    }
};
