const gl = @import("opengl");

pub const FBAccelrationTag = enum(u8) {
    none,
    opengl,
};

pub const FBAccelration = union(FBAccelrationTag) {
    none: void,
    opengl: gl.GLConfig,
};

pub const FBConfig = struct {
    depth_bits: u8,
    stencil_bits: u8,

    color_bits: struct {
        red_bits: u4,
        green_bits: u4,
        blue_bits: u4,
        alpha_bits: u4,
    },

    accum_bits: struct {
        red_bits: u4,
        green_bits: u4,
        blue_bits: u4,
        alpha_bits: u4,
    },

    flags: struct {
        double_buffered: bool,
        sRGB: bool,
        stereo: bool,
    },

    accel: FBAccelration,
};
