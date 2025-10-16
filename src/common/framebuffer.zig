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
        updateSoftwareBuffer: ?*const fn (
            ctx: *anyopaque,
            w: i32,
            h: i32,
        ) bool = null,
        makeCurrent: ?*const fn (ctx: *anyopaque) bool = null,
        setSwapInterval: *const fn (ctx: *anyopaque, intrvl: SwapInterval) bool,
    },
    fb_format_info: px.PixelFormatInfo,
    render_backend: RenderApi,

    const Self = @This();

    pub inline fn deinit(self: *const Self) void {
        self._vtable.deinit(self.ctx);
    }

    /// signal to canvas driver/rendering backend to copy the backbuffer
    /// into the window framebuffer
    /// returns true on success, false on failure
    pub inline fn swapBuffers(self: *const Self) bool {
        return self._vtable.swapBuffers(self.ctx);
    }

    pub inline fn setSwapInterval(self: *const Self, intrvl: SwapInterval) bool {
        return self._vtable.setSwapInterval(self.ctx, intrvl);
    }

    /// write details about the canvas driver/rendering backend.
    /// for hardware backends such as OpenGL this includes hardware name,
    /// hardware vendor name and also the kernel driver version running on the platform.
    /// returns false if the writer ran out of space, otherwise returns true.
    /// # Parameters:
    /// 'wr': the writer into which the details string is written
    pub inline fn getDriverInfo(self: *const Self, wr: *io.Writer) bool {
        return self._vtable.getDriverInfo(self.ctx, wr);
    }

    /// Returns a string identifier of the canvas driver/rendering backend
    /// possible return values = ["Software","OpenGL"]
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

    /// This function is for software canvas driver/rendering backend only.
    /// it returns the software framebuffer used for the window + the canvas
    /// width, height and pitch/stride i.e number of bytes in one row or scanline
    /// of the framebuffer.
    /// returns false on all non software backends
    /// # Parameters
    /// `pixels`: pointer to the variable that receives the framebuffer slice,
    /// `width`: pointer to the variable that receives the width,
    /// `height`: pointer to the variable that receives the height,
    /// `pitch`: pointer to the framebuffer pitch/stride,
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

    /// This function is for software canvas driver/rendering backend only.
    /// it attempt to resize the software framebuffer used for the window.
    /// returns false on all non software backends, and true if it succeeds.
    /// # WARNING
    /// on success, values previously returned by *getSoftwareBuffer*
    /// are invalidated even if the width and height parameters are the same
    /// as the previous returned values.
    /// in short each time you call this call *getSoftwareBuffer* after to avoid
    /// crashing.
    /// # Parameters
    /// `width`: new width of the framebuffer,
    /// `height`: new height of the framebuffer,
    pub inline fn updateSoftwareBuffer(
        self: *const Self,
        width: i32,
        height: i32,
    ) bool {
        if (self._vtable.updateSoftwareBuffer) |f| {
            return f(self.ctx, width, height);
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
