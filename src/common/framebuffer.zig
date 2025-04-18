const gl = @import("opengl");

pub const FBAccelrationTag = enum(u8) {
    none,
    opengl,
};

pub const FBAccelrationConfig = union(FBAccelrationTag) {
    none: void,
    opengl: gl.GLConfig,
};

pub const FBConfig = struct {
    depth_bits: u8 = 24,
    stencil_bits: u8 = 8,

    color: struct {
        red_bits: u4 = 8,
        green_bits: u4 = 8,
        blue_bits: u4 = 8,
        alpha_bits: u4 = 8,
    } = .{},
    accum: struct {
        red_bits: u4 = 0,
        green_bits: u4 = 0,
        blue_bits: u4 = 0,
        alpha_bits: u4 = 0,
    } = .{},
    flags: struct {
        double_buffered: bool = true,
        sRGB: bool = true,
        stereo: bool = false,
    } = .{},

    accel: FBAccelrationConfig = .{ .opengl = .{} },
};
