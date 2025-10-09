const std = @import("std");
const common = @import("common");
const dynlib = @import("dynlib.zig");
const win32_gl = @import("win32api/opengl.zig");
const win32_gfx = @import("win32api/graphics.zig");
const win32_macros = @import("win32api/macros.zig");

const mem = std.mem;
const io = std.io;
const debug = std.debug;
const win32 = std.os.windows;
const Win32Driver = @import("driver.zig").Win32Driver;
const FBConfig = common.fb.FBConfig;
const Win32Canvas = @import("window.zig").Win32Canvas;

const WGLError = error{
    PFDNoMatch,
    NoRC,
};

const WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
const WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
const WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
const WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002;
const WGL_CONTEXT_FLAGS_ARB = 0x2094;
const WGL_CONTEXT_DEBUG_BIT_ARB = 0x00000001;
const GL_ARRAY_BUFFER = 0x8892;
const GL_STATIC_DRAW = 0x88E4;
const GL_FRAGMENT_SHADER = 0x8B30;
const GL_VERTEX_SHADER = 0x8B31;
const GL_COMPILE_STATUS = 0x8B81;
const GL_LINK_STATUS = 0x8B82;
const GL_INFO_LOG_LENGTH = 0x8B84;
const GL_TEXTURE0 = 0x84C0;
const GL_BGRA = 0x80E1;
const GL_ELEMENT_ARRAY_BUFFER = 0x8893;

const WGL_NUMBER_PIXEL_FORMATS_ARB = 0x2000;
const WGL_DRAW_TO_WINDOW_ARB = 0x2001;
const WGL_DRAW_TO_BITMAP_ARB = 0x2002;
const WGL_ACCELERATION_ARB = 0x2003;
const WGL_NEED_PALETTE_ARB = 0x2004;
const WGL_NEED_SYSTEM_PALETTE_ARB = 0x2005;
const WGL_SWAP_LAYER_BUFFERS_ARB = 0x2006;
const WGL_SWAP_METHOD_ARB = 0x2007;
const WGL_NUMBER_OVERLAYS_ARB = 0x2008;
const WGL_NUMBER_UNDERLAYS_ARB = 0x2009;
const WGL_TRANSPARENT_ARB = 0x200A;
const WGL_TRANSPARENT_RED_VALUE_ARB = 0x2037;
const WGL_TRANSPARENT_GREEN_VALUE_AR = 0x2038;
const WGL_TRANSPARENT_BLUE_VALUE_ARB = 0x2039;
const WGL_TRANSPARENT_ALPHA_VALUE_AR = 0x203A;
const WGL_TRANSPARENT_INDEX_VALUE_AR = 0x203B;
const WGL_SHARE_DEPTH_ARB = 0x200C;
const WGL_SHARE_STENCIL_ARB = 0x200D;
const WGL_SHARE_ACCUM_ARB = 0x200E;
const WGL_SUPPORT_GDI_ARB = 0x200F;
const WGL_SUPPORT_OPENGL_ARB = 0x2010;
const WGL_DOUBLE_BUFFER_ARB = 0x2011;
const WGL_STEREO_ARB = 0x2012;
const WGL_PIXEL_TYPE_ARB = 0x2013;
const WGL_COLOR_BITS_ARB = 0x2014;
const WGL_RED_BITS_ARB = 0x2015;
const WGL_RED_SHIFT_ARB = 0x2016;
const WGL_GREEN_BITS_ARB = 0x2017;
const WGL_GREEN_SHIFT_ARB = 0x2018;
const WGL_BLUE_BITS_ARB = 0x2019;
const WGL_BLUE_SHIFT_ARB = 0x201A;
const WGL_ALPHA_BITS_ARB = 0x201B;
const WGL_ALPHA_SHIFT_ARB = 0x201C;
const WGL_ACCUM_BITS_ARB = 0x201D;
const WGL_ACCUM_RED_BITS_ARB = 0x201E;
const WGL_ACCUM_GREEN_BITS_ARB = 0x201F;
const WGL_ACCUM_BLUE_BITS_ARB = 0x2020;
const WGL_ACCUM_ALPHA_BITS_ARB = 0x2021;
const WGL_DEPTH_BITS_ARB = 0x2022;
const WGL_STENCIL_BITS_ARB = 0x2023;
const WGL_AUX_BUFFERS_ARB = 0x2024;
const WGL_NO_ACCELERATION_ARB = 0x2025;
const WGL_GENERIC_ACCELERATION_ARB = 0x2026;
const WGL_FULL_ACCELERATION_ARB = 0x2027;
const WGL_SWAP_EXCHANGE_ARB = 0x2028;
const WGL_SWAP_COPY_ARB = 0x2029;
const WGL_SWAP_UNDEFINED_ARB = 0x202A;
const WGL_TYPE_RGBA_ARB = 0x202B;
const WGL_TYPE_COLORINDEX_ARB = 0x202C;
const WGL_TRANSPARENT_GREEN_VALUE_ARB = 0x2038;
const WGL_TRANSPARENT_ALPHA_VALUE_ARB = 0x203A;
const WGL_TRANSPARENT_INDEX_VALUE_ARB = 0x203B;
const WGL_SAMPLE_BUFFERS_ARB = 0x2041;
const WGL_SAMPLES_ARB = 0x2042;
const WGL_FRAMEBUFFER_SRGB_CAPABLE_ARB = 0x20A9;

const wgl_ext = struct {
    var ChoosePixelFormatARB: ?*const fn (
        hdc: ?win32.HDC,
        piAttribIList: ?[*]c_int,
        pfAttribFList: ?[*]f32,
        nMaxFormats: win32.UINT,
        piFormats: ?[*]c_int,
        nNumFormats: *win32.UINT,
    ) callconv(.winapi) win32.BOOL = null;

    var GetPixelFormatAttribivARB: ?*const fn (
        hdc: ?win32.HDC,
        iPixelFormat: c_int,
        iLayerPlane: c_int,
        nAttributes: win32.UINT,
        piAttributes: ?[*]c_int,
        piValues: ?[*]c_int,
    ) callconv(.winapi) win32.BOOL = null;

    var CreateContextAttribsARB: ?*const fn (
        hdc: ?win32.HDC,
        hShareContext: ?win32.HGLRC,
        attribList: ?[*]c_int,
    ) callconv(.winapi) ?win32.HGLRC = null;

    var SwapIntervalEXT: ?*const fn (
        interval: c_int,
    ) callconv(.winapi) win32.BOOL = null;

    var GetExtensionsStringARB: ?*const fn (
        hdc: ?win32.HDC,
    ) callconv(.winapi) ?[*:0]const u8 = null;

    var supported_extensions: ?[:0]const u8 = null;
    var ARB_pixel_format: bool = false;
    var ARB_create_context: bool = false;
    var EXT_swap_control_tear: bool = false;

    var loaded: bool = false;
};

fn fillPFDstruct(pfd: *win32_gl.PIXELFORMATDESCRIPTOR, cfg: *const FBConfig) void {
    pfd.nSize = @sizeOf(win32_gl.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = win32_gl.PFD_FLAGS{
        .DRAW_TO_WINDOW = 1,
        .SUPPORT_OPENGL = 1,
    };

    if (cfg.flags.double_buffered) {
        pfd.dwFlags.DOUBLEBUFFER = 1;
    }
    pfd.iPixelType = win32_gl.PFD_TYPE_RGBA;
    pfd.iLayerType = win32_gl.PFD_MAIN_PLANE;
    pfd.cColorBits = @as(u8, cfg.color_bits.red_bits) + cfg.color_bits.green_bits +
        cfg.color_bits.blue_bits;
    pfd.cRedBits = cfg.color_bits.red_bits;
    pfd.cRedShift = 0;
    pfd.cGreenBits = cfg.color_bits.green_bits;
    pfd.cGreenShift = 0;
    pfd.cBlueBits = cfg.color_bits.blue_bits;
    pfd.cBlueShift = 0;
    pfd.cAlphaBits = cfg.color_bits.alpha_bits;
    pfd.cAlphaShift = 0;
    pfd.cAccumBits = @as(u8, cfg.accum_bits.red_bits) + cfg.accum_bits.green_bits +
        cfg.accum_bits.blue_bits + cfg.accum_bits.alpha_bits;
    pfd.cAccumRedBits = cfg.accum_bits.red_bits;
    pfd.cAccumGreenBits = cfg.accum_bits.green_bits;
    pfd.cAccumBlueBits = cfg.accum_bits.blue_bits;
    pfd.cAccumAlphaBits = cfg.accum_bits.alpha_bits;
    pfd.cDepthBits = cfg.depth_bits;
    pfd.cStencilBits = cfg.stencil_bits;
    pfd.cAuxBuffers = 0;
    pfd.bReserved = 0;
    pfd.dwLayerMask = 0;
    pfd.dwVisibleMask = 0;
    pfd.dwDamageMask = 0;
}

fn createTempContext(
    window: win32.HWND,
) WGLError!win32.HGLRC {
    var pfd = mem.zeroes(win32_gl.PIXELFORMATDESCRIPTOR);
    pfd.nSize = @sizeOf(win32_gl.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = win32_gl.PFD_FLAGS{
        .DRAW_TO_WINDOW = 1,
        .SUPPORT_OPENGL = 1,
        .DOUBLEBUFFER = 1,
    };

    const wdc = win32_gfx.GetDC(window);

    const pfi = win32_gl.ChoosePixelFormat(wdc, &pfd);
    if (pfi == 0) {
        return WGLError.PFDNoMatch;
    }

    if (win32_gl.SetPixelFormat(wdc, pfi, &pfd) == win32.FALSE) {
        return WGLError.PFDNoMatch;
    }

    const glc = win32_gl.wglCreateContext(wdc);
    if (glc == null) {
        return WGLError.NoRC;
    }

    _ = win32_gfx.ReleaseDC(window, wdc);

    return glc.?;
}

fn loadGLExtensions(driver: *const Win32Driver) bool {

    // Create a temp window
    const tmp_wndw = win32_gfx.CreateWindowExW(
        0,
        win32_macros.MAKEINTATOM(driver.handles.wnd_class),
        &[_:0]u16{ 0x00, 0x00 },
        win32_gfx.WS_POPUP | win32_gfx.WS_DISABLED,
        0,
        0,
        16,
        16,
        null,
        null,
        driver.handles.hinstance,
        null,
    );

    if (tmp_wndw == null) {
        return false;
    }

    _ = win32_gfx.ShowWindow(tmp_wndw, win32_gfx.SHOW_WINDOW_CMD{});

    defer _ = win32_gfx.DestroyWindow(tmp_wndw);

    const tmp_glc = createTempContext(tmp_wndw.?) catch {
        return false;
    };

    defer _ = win32_gl.wglDeleteContext(tmp_glc);

    const wdc = win32_gfx.GetDC(tmp_wndw);
    defer _ = win32_gfx.ReleaseDC(tmp_wndw, wdc);

    if (win32_gl.wglMakeCurrent(wdc, tmp_glc) != win32.TRUE) {
        return false;
    }

    wgl_ext.GetExtensionsStringARB = @ptrCast(win32_gl.wglGetProcAddress(
        "wglGetExtensionsStringARB",
    ));

    if (wgl_ext.GetExtensionsStringARB == null) {
        // we can't query extensions available on the hardware.
        return true;
    }

    const extensions = wgl_ext.GetExtensionsStringARB.?(wdc);
    if (extensions) |exts| {
        wgl_ext.supported_extensions = mem.span(exts);

        if (common.fb.glHasExtension("WGL_ARB_pixel_format", wgl_ext.supported_extensions.?)) {
            wgl_ext.ARB_pixel_format = true;
            wgl_ext.ChoosePixelFormatARB = @ptrCast(win32_gl.wglGetProcAddress(
                "wglChoosePixelFormatARB",
            ));
            wgl_ext.GetPixelFormatAttribivARB = @ptrCast(win32_gl.wglGetProcAddress(
                "wglGetPixelFormatAttribivARB",
            ));
        }

        if (common.fb.glHasExtension("WGL_EXT_swap_control", wgl_ext.supported_extensions.?)) {
            wgl_ext.SwapIntervalEXT = @ptrCast(win32_gl.wglGetProcAddress(
                "wglSwapIntervalEXT",
            ));

            if (common.fb.glHasExtension("WGL_EXT_swap_control_tear", wgl_ext.supported_extensions.?)) {
                wgl_ext.EXT_swap_control_tear = true;
            }
        }

        if (common.fb.glHasExtension("WGL_ARB_create_context", wgl_ext.supported_extensions.?)) {
            wgl_ext.ARB_create_context = true;
            wgl_ext.CreateContextAttribsARB = @ptrCast(win32_gl.wglGetProcAddress(
                "wglCreateContextAttribsARB",
            ));
        }
    }

    return true;
}

fn createGLContext(window: win32.HWND, cfg: *const FBConfig) ?win32.HGLRC {
    var pfd_attrib_list: [48]c_int = undefined;
    var gl_attrib_list: [16]c_int = undefined;
    var pfd_fattrib_list = [1]f32{0};
    var pixel_format = [1]c_int{0};
    var format_count: u32 = 0;
    var index: usize = 0;
    var pfd: win32_gl.PIXELFORMATDESCRIPTOR = undefined;

    const dc = win32_gfx.GetDC(window);
    const helper = struct {
        pub inline fn setAttribute(list: []c_int, idx: *usize, attrib: c_int, val: c_int) void {
            debug.assert(idx.* < list.len);
            list[idx.*] = attrib;
            list[idx.* + 1] = val;
            idx.* += 2;
        }
    };

    if (wgl_ext.ARB_pixel_format) {

        // pfd_attrib_list
        {
            // Support for OpenGL rendering.
            helper.setAttribute(&pfd_attrib_list, &index, WGL_SUPPORT_OPENGL_ARB, 1);

            // Support for rendering to a window.
            helper.setAttribute(&pfd_attrib_list, &index, WGL_DRAW_TO_WINDOW_ARB, 1);

            // Specifiy color bits count.
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_COLOR_BITS_ARB,
                @as(c_int, cfg.color_bits.red_bits) + cfg.color_bits.blue_bits +
                    cfg.color_bits.green_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_RED_BITS_ARB,
                cfg.color_bits.red_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_GREEN_BITS_ARB,
                cfg.color_bits.green_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_BLUE_BITS_ARB,
                cfg.color_bits.blue_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ALPHA_BITS_ARB,
                cfg.color_bits.alpha_bits,
            );

            // Specifiy accum bits count.
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ACCUM_BITS_ARB,
                @as(c_int, cfg.accum_bits.red_bits) + cfg.accum_bits.blue_bits +
                    cfg.accum_bits.green_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ACCUM_RED_BITS_ARB,
                cfg.accum_bits.red_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ACCUM_GREEN_BITS_ARB,
                cfg.accum_bits.green_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ACCUM_BLUE_BITS_ARB,
                cfg.accum_bits.blue_bits,
            );
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ACCUM_ALPHA_BITS_ARB,
                cfg.accum_bits.alpha_bits,
            );

            // Support for hardware acceleration.
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_ACCELERATION_ARB,
                WGL_FULL_ACCELERATION_ARB,
            );

            if (cfg.flags.double_buffered) {
                // Support for double buffer.
                helper.setAttribute(
                    &pfd_attrib_list,
                    &index,
                    WGL_DOUBLE_BUFFER_ARB,
                    1,
                );
            }

            // Stencil bits
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_STENCIL_BITS_ARB,
                cfg.stencil_bits,
            );

            // Support for var bit depth buffer.
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_DEPTH_BITS_ARB,
                cfg.depth_bits,
            );

            // Support for swapping front and back buffer.
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_SWAP_METHOD_ARB,
                WGL_SWAP_EXCHANGE_ARB,
            );

            if (cfg.flags.stereo) {
                // color buffer has left/right pairs
                helper.setAttribute(&pfd_attrib_list, &index, WGL_STEREO_ARB, 1);
            }

            if (cfg.flags.sRGB) {
                helper.setAttribute(
                    &pfd_attrib_list,
                    &index,
                    WGL_FRAMEBUFFER_SRGB_CAPABLE_ARB,
                    1,
                );
            }

            // Support for the RGBA pixel type.
            helper.setAttribute(
                &pfd_attrib_list,
                &index,
                WGL_PIXEL_TYPE_ARB,
                WGL_TYPE_RGBA_ARB,
            );
        }
        // Null terminate the attribute list.
        pfd_attrib_list[index] = 0;

        if (wgl_ext.ChoosePixelFormatARB.?(
            dc,
            &pfd_attrib_list,
            &pfd_fattrib_list,
            1,
            &pixel_format,
            &format_count,
        ) != win32.TRUE or format_count == 0) {
            // Fallback
            fillPFDstruct(&pfd, cfg);
            pixel_format[0] = win32_gl.ChoosePixelFormat(dc, &pfd);
        }
    } else {
        fillPFDstruct(&pfd, cfg);
        pixel_format[0] = win32_gl.ChoosePixelFormat(dc, &pfd);
    }

    if (win32_gl.SetPixelFormat(dc, pixel_format[0], &pfd) != win32.TRUE) {
        return null;
    }

    if (cfg.accel.opengl.ver.major < 3 or !wgl_ext.ARB_create_context) {
        return win32_gl.wglCreateContext(dc);
    }

    // gl_attrib_list
    {
        index = 0;
        helper.setAttribute(&gl_attrib_list, &index, WGL_CONTEXT_MAJOR_VERSION_ARB, cfg.accel.opengl.ver.major);
        helper.setAttribute(&gl_attrib_list, &index, WGL_CONTEXT_MINOR_VERSION_ARB, cfg.accel.opengl.ver.minor);
        helper.setAttribute(
            &gl_attrib_list,
            &index,
            WGL_CONTEXT_PROFILE_MASK_ARB,
            if (cfg.accel.opengl.profile == .Core)
                WGL_CONTEXT_CORE_PROFILE_BIT_ARB
            else
                WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
        );

        var flag: c_int = 0;
        if (cfg.accel.opengl.is_debug) {
            flag |= WGL_CONTEXT_DEBUG_BIT_ARB;
        }

        if (flag != 0) {
            helper.setAttribute(&gl_attrib_list, &index, WGL_CONTEXT_FLAGS_ARB, flag);
        }

        gl_attrib_list[index] = 0;
    }

    return wgl_ext.CreateContextAttribsARB.?(dc, null, &gl_attrib_list);
}

pub const GLContext = struct {
    glrc: win32.HGLRC,
    owner: win32.HWND,
    driver: struct {
        hardware: [*:0]const u8,
        vendor: [*:0]const u8,
        version: [*:0]const u8,
    },
    const Self = @This();

    pub fn init(window: win32.HWND, driver: *const Win32Driver, cfg: *const FBConfig) WGLError!Self {
        const prev_dc = win32_gl.wglGetCurrentDC();
        const prev_glc = win32_gl.wglGetCurrentContext();
        defer _ = win32_gl.wglMakeCurrent(prev_dc, prev_glc);

        if (!wgl_ext.loaded) {
            wgl_ext.loaded = loadGLExtensions(driver);
        }

        const rc = createGLContext(window, cfg);
        if (rc == null) {
            return WGLError.NoRC;
        }

        const wdc = win32_gfx.GetDC(window);
        _ = win32_gl.wglMakeCurrent(wdc, rc);

        var vend: [*:0]const u8 = undefined;
        var rend: [*:0]const u8 = undefined;
        var ver: [*:0]const u8 = undefined;

        var glGetString: ?*const fn (name: u32) callconv(.winapi) ?[*:0]const u8 = null;
        glGetString = @ptrCast(glLoaderFunc("glGetString"));
        if (glGetString) |func| {
            const GL_UNKOWN_VENDOR = "Vendor_Unknown";
            const GL_UNKOWN_RENDER = "Renderer_Unknown";
            vend = func(win32_gl.GL_VENDOR) orelse GL_UNKOWN_VENDOR;
            rend = func(win32_gl.GL_RENDERER) orelse GL_UNKOWN_RENDER;
            ver = func(win32_gl.GL_VERSION) orelse "";
        }

        _ = win32_gfx.ReleaseDC(window, wdc);

        return .{
            .glrc = rc.?,
            .owner = window,
            .driver = .{
                .hardware = rend,
                .vendor = vend,
                .version = ver,
            },
        };
    }

    pub inline fn deinit(self: *const Self) void {
        _ = win32_gl.wglMakeCurrent(null, null);
        _ = win32_gl.wglDeleteContext(self.glrc);
    }

    pub inline fn makeCurrent(self: *const Self) bool {
        const wdc = win32_gfx.GetDC(self.owner);
        const success = win32_gl.wglMakeCurrent(wdc, self.glrc) == win32.TRUE;
        _ = win32_gfx.ReleaseDC(self.owner, wdc);
        return success;
    }

    pub inline fn swapBuffers(self: *const Self) bool {
        const wdc = win32_gfx.GetDC(self.owner);
        const success = win32_gl.SwapBuffers(wdc) == win32.TRUE;
        _ = win32_gfx.ReleaseDC(self.owner, wdc);
        return success;
    }

    pub fn setSwapInterval(_: *const Self, interval: common.fb.SwapInterval) bool {
        if (wgl_ext.SwapIntervalEXT) |func| {
            if (interval == .Adaptive and wgl_ext.EXT_swap_control_tear == false) {
                return false;
            }
            const interval_int = @intFromEnum(interval);
            return func(interval_int) == win32.TRUE;
        }
        return false;
    }
};

pub fn glLoaderFunc(symbol_name: [*:0]const u8) ?*const anyopaque {
    var symbol_ptr = win32_gl.wglGetProcAddress(symbol_name);
    // wglGetProcAddress returns NULL on failure,
    // some implementations will return other values. 1, 2, and 3 are used, as well as -1
    if (symbol_ptr == null or
        @intFromPtr(symbol_ptr) == 0x1 or
        @intFromPtr(symbol_ptr) == 0x2 or
        @intFromPtr(symbol_ptr) == 0x3 or
        @intFromPtr(symbol_ptr) == @as(usize, @bitCast(@as(isize, -0x1))))
    {
        // wglGetProcAddress will not return function pointers from any OpenGL functions
        // that are directly exported by the OpenGL32.DLL itself.
        // This means the old ones from OpenGL version 1.1. Fortunately those functions
        // can be obtained by the Win32's GetProcAddress.
        const module = dynlib.loadWin32Module("opengl32.dll");
        if (module) |m| {
            symbol_ptr = @ptrCast(dynlib.getModuleSymbol(m, symbol_name));
        } else {
            return null;
        }
    }
    return symbol_ptr;
}

//===========================
// opengl rendering hooks
//============================

pub fn glSwapBuffers(ctx: *anyopaque) bool {
    const c: *Win32Canvas = @ptrCast(@alignCast(ctx));
    return c.gl_ctx.swapBuffers();
}

pub fn glSetSwapInterval(ctx: *anyopaque, interval: common.fb.SwapInterval) bool {
    const c: *Win32Canvas = @ptrCast(@alignCast(ctx));
    return c.gl_ctx.setSwapInterval(interval);
}

pub fn glMakeCurrent(ctx: *anyopaque) bool {
    const c: *Win32Canvas = @ptrCast(@alignCast(ctx));
    return c.gl_ctx.makeCurrent();
}

pub fn glGetDriverInfo(ctx: *anyopaque, wr: *io.Writer) bool {
    const c: *Win32Canvas = @ptrCast(@alignCast(ctx));
    wr.print("Driver: {s}, for Hardware: {s}, Made by: {s}", .{
        c.gl_ctx.driver.version,
        c.gl_ctx.driver.hardware,
        c.gl_ctx.driver.vendor,
    }) catch return false;
    return true;
}

pub fn glDestroyCanvas(ctx: *anyopaque) void {
    const c: *Win32Canvas = @ptrCast(@alignCast(ctx));
    c.gl_ctx.deinit();
    c.* = .{ .invalid = {} };
}
