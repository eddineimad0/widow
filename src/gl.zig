const platform = @import("platform");

pub const GLConfig = struct {
    ver: struct {
        major: u8,
        minor: u8,
    },

    color: struct {
        red_bits: u4 = 8,
        green_bits: u4 = 8,
        blue_bits: u4 = 8,
        alpha_bits: u4 = 8,
    },

    accum: struct {
        red_bits: u4 = 8,
        green_bits: u4 = 8,
        blue_bits: u4 = 8,
        alpha_bits: u4 = 8,
    },

    depth_bits: u8 = 24,
    stencil_bits: u8 = 8,
    flags: struct {
        double_buffered: bool = true,
        accelerated: bool = true,
    },
};

const GLCanvas = struct {
    cntxt: platform.GLDriver,
};
