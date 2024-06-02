pub const GLProfile = enum {
    Compat,
    Core,
};

pub const GLConfig = struct {
    ver: struct {
        major: u8 = 4,
        minor: u8 = 6,
    } = .{},

    color: struct {
        red_bits: u4 = 8,
        green_bits: u4 = 8,
        blue_bits: u4 = 8,
        alpha_bits: u4 = 8,
    } = .{},

    accum: struct {
        red_bits: u4 = 8,
        green_bits: u4 = 8,
        blue_bits: u4 = 8,
        alpha_bits: u4 = 8,
    } = .{},

    depth_bits: u8 = 24,
    stencil_bits: u8 = 8,
    flags: struct {
        double_buffered: bool = true,
        accelerated: bool = true,
        sRGB: bool = true,
        stereo: bool = true,
    } = .{},
    profile: GLProfile = .Core,
};
