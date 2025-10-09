const std = @import("std");
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

pub const Canvas = struct {
    ctx: *anyopaque,
    _vtable: struct {
        swapBuffers: *const fn (ctx: *anyopaque) bool,
        getDriverInfo: *const fn (ctx: *anyopaque, wr: *io.Writer) bool,
        deinit: *const fn (ctx: *anyopaque) void,
        getSoftwareBuffer: ?*const fn (
            ctx: *anyopaque,
            pixels: *[]u32,
            w: *u32,
            h: *u32,
            pitch: *u32,
        ) void = null,
        makeCurrent: ?*const fn (ctx: *anyopaque) bool = null,
        setSwapInterval: *const fn (ctx: *anyopaque, intrvl: SwapInterval) bool,
    },
    render_backend: RenderApi,

    const Self = @This();

    pub inline fn deinit(self: *Self) void {
        self._vtable.deinit(self.ctx);
    }

    pub inline fn swapBuffers(self: *const Self) bool {
        return self._vtable.swapBuffers(self.ctx);
    }

    pub inline fn setSwapInterval(self: *Self, intrvl: SwapInterval) bool {
        return self._vtable.setSwapInterval(self.ctx, intrvl);
    }

    pub inline fn getDriverInfo(self: *Self, wr: *io.Writer) bool {
        return self._vtable.getDriverInfo(self.ctx, wr);
    }

    pub inline fn getDriverName(self: *const Self) [*:0]const u8 {
        return switch (self.render_backend) {
            .software => "Software",
            .opengl => "OpenGL",
        };
    }

    pub inline fn makeCurrent(self: *const Self) bool {
        if (self._vtable.makeCurrent) |f| {
            return f(self.ctx);
        }
        return false;
    }

    pub inline fn getSoftwareBuffer(
        self: *const Self,
        pixels: *[]u32,
        width: *u32,
        height: *u32,
        pitch: *u32,
    ) bool {
        if (self._vtable.getSoftwareBuffer) |f| {
            f(self.ctx, pixels, width, height, pitch);
            return true;
        }
        return false;
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
