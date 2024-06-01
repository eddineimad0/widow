const std = @import("std");
const mem = std.mem;
const debug = std.debug;
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const opengl = zigwin32.graphics.open_gl;
const gdi = zigwin32.graphics.gdi;
const window_msg = zigwin32.ui.windows_and_messaging;
const Window = @import("window.zig").Window;
const Win32Driver = @import("driver.zig").Win32Driver;
const GLConfig = @import("../../gl.zig").GLConfig;

const WGLCError = error{
    PFDNoMatch,
    GLCNoHandle,
};

const WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
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

fn hasExtension(target: [*:0]const u8, ext_list: [:0]const u8) bool {
    var haystack = ext_list;
    while (true) {
        const start = mem.indexOf(u8, haystack, target);
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

fn createTempContext(window: win32.HWND, cfg: *const GLConfig) WGLCError!opengl.HGLRC {
    var pfd: opengl.PIXELFORMATDESCRIPTOR = undefined;
    pfd.nSize = @sizeOf(opengl.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = gdi.PFD_DRAW_TO_WINDOW | gdi.PFD_SUPPORT_OPENGL;
    if (cfg.flags.double_buffer) {
        pfd.dwFlags |= gdi.PFD_DOUBLEBUFFER;
    }
    pfd.iPixelType = gdi.PFD_TYPE_RGBA;
    // TODO: the docs says this field is ignored remove and test.
    pfd.iLayerType = gdi.PFD_MAIN_PLANE;
    pfd.cColorBits = cfg.color.red_bits + cfg.color.green_bits +
        cfg.color.blue_bits;
    pfd.cRedBits = cfg.color.red_bits;
    pfd.cRedShift = 0;
    pfd.cGreenBits = cfg.color.green_bits;
    pfd.cGreenShift = 0;
    pfd.cBlueBits = cfg.color.blue_bits;
    pfd.cBlueShift = 0;
    pfd.cAlphaBits = cfg.color.alpha_bits;
    pfd.cAlphaShift = 0;
    pfd.cAccumBits = cfg.accum.red_bits + cfg.accum.green_bits +
        cfg.accum.blue_bits + cfg.accum.alpha_bits;
    pfd.cAccumRedBits = cfg.accum.red_bits;
    pfd.cAccumGreenBits = cfg.accum.green_bits;
    pfd.cAccumBlueBits = cfg.accum.blue_bits;
    pfd.cAccumAlphaBits = cfg.accum.alpha_bits;
    pfd.cDepthBits = cfg.depth_bits;
    pfd.cStencilBits = cfg.stencil_bits;
    pfd.cAuxBuffers = 0;
    pfd.bReserved = 0;
    pfd.dwLayerMask = 0;
    pfd.dwVisibleMask = 0;
    pfd.dwDamageMask = 0;

    const wdc = gdi.GetDC(window);

    const pfi = opengl.ChoosePixelFormat(wdc, &pfd);
    if (pfi == 0) {
        return WGLCError.PFDNoMatch;
    }

    if (opengl.SetPixelFormat(wdc, pfi, &pfd) == win32.FALSE) {
        return WGLCError.PFDNoMatch;
    }

    const glc = opengl.wglCreateContext(wdc);
    if (glc == null) {
        return WGLCError.GLCNoHandle;
    }

    _ = gdi.ReleaseDC(window, wdc);

    return glc;
}

fn loadGLExtensions(cfg: *const GLConfig) bool {
    const drvr = Win32Driver.singleton();

    // Create a temp window
    const tmp_wndw = window_msg.CreateWindowExW(
        0,
        utils.MAKEINTATOM(drvr.handles.wnd_class),
        "",
        @bitCast(window_msg.WINDOW_STYLE{ .POPUP = 1, .DISABLED = 1 }),
        0,
        0,
        16,
        16,
        null,
        null,
        drvr.handles.hinstance,
        null,
    );

    if (tmp_wndw == null) {
        return false;
    }

    defer window_msg.DestroyWindow(tmp_wndw);

    const tmp_glc = try createTempContext(tmp_wndw.?, cfg);

    const prev_dc = opengl.wglGetCurrentDC();
    const prev_glc = opengl.wglGetCurrentContext();

    const wdc = gdi.GetDC(tmp_wndw);
    _ = opengl.wglMakeCurrent(wdc, tmp_glc); //TODO: fails ?

    wgl_proc.GetExtensionsStringARB = @ptrCast(opengl.wglGetProcAddress(
        "wglGetExtensionsStringARB",
    ));

    wgl_proc.CreateContextAttribsARB = opengl.wglGetProcAddress(
        "wglCreateContextAttribsARB",
    );

    const extensions = wgl_proc.GetExtensionsStringARB().?;
    if (extensions) |exts| {
        wgl_ext.exts = mem.span(exts);

        if (hasExtension("WGL_ARB_pixel_format", wgl_ext.exts)) {
            wgl_ext.wgl_arb_pixel_format = true;
            wgl_proc.ChoosePixelFormatARB = opengl.wglGetProcAddress(
                "wglChoosePixelFormatARB",
            );
        }

        if (hasExtension("wgl_ext_swap_control", wgl_ext.exts)) {
            wgl_ext.wgl_ext_swap_control = true;
            wgl_proc.SwapIntervalEXT = opengl.wglGetProcAddress(
                "wglSwapIntervalEXT",
            );
        }
    }

    _ = opengl.wglMakeCurrent(prev_dc, prev_glc);
    opengl.wglDeleteContext(tmp_glc);
    _ = gdi.ReleaseDC(tmp_wndw, wdc);
}

pub var wgl_proc = struct {
    var ChoosePixelFormatARB: ?*const fn (
        hdc: win32.HDC,
        piAttribIList: [*]c_int,
        pfAttribFList: [*]f32,
        nMaxFormats: win32.UINT,
        piFormats: [*]c_int,
        nNumFormats: win32.UINT,
    ) callconv(win32.WINAPI) win32.BOOL = null;

    var CreateContextAttribsARB: ?*const fn (
        hdc: win32.HDC,
        hShareContext: opengl.HGLRC,
        attribList: [*]c_int,
    ) callconv(win32.WINAPI) ?opengl.HGLRC = null;

    var SwapIntervalEXT: ?*const fn (
        interval: c_int,
    ) callconv(win32.WINAPI) win32.BOOL = null;

    var GetExtensionsStringARB: ?*const fn (
        hdc: win32.HDC,
    ) callconv(win32.WINAPI) ?[*:0]const u8 = null;

    var loaded: bool = false;
};

pub var wgl_ext = packed struct {
    var exts: ?[:0]const u8 = null;
    var wgl_arb_pixel_format: bool = false;
    var wgl_ext_swap_control: bool = false;
};

pub const GLDriver = struct {
    cfg: GLConfig,
    glrc: opengl.HGLRC,
    owner: win32.HWND,

    const Self = @This();

    pub fn init(hwnd: win32.HWND, cfg: *const GLConfig) !Self {
        if (!Self.wgl_proc.loaded) {
            _ = loadGLExtensions(cfg);
        }

        var pfd_attrib_list: [48]c_int = undefined;
        var gl_attrib_list: [5]c_int = undefined;
        var pixel_format: [1]c_int = undefined;
        var format_count: u32 = 0;
        var index = 0;

        var pfd: opengl.PIXELFORMATDESCRIPTOR = undefined;

        // Support for OpenGL rendering.
        pfd_attrib_list[index] = WGL_SUPPORT_OPENGL_ARB;
        pfd_attrib_list[index + 1] = 1;
        index += 2;

        // Support for rendering to a window.
        pfd_attrib_list[index] = WGL_DRAW_TO_WINDOW_ARB;
        pfd_attrib_list[index + 1] = 1;
        index += 2;

        // Specifiy color bits count.
        pfd_attrib_list[index] = WGL_RED_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.color.red_bits;
        index += 2;
        pfd_attrib_list[index] = WGL_GREEN_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.color.green_bits;
        index += 2;
        pfd_attrib_list[index] = WGL_BLUE_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.color.blue_bits;
        index += 2;
        pfd_attrib_list[index] = WGL_ALPHA_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.color.alpha_bits;
        index += 2;

        if (cfg.flags.accelerated) {
            // Support for hardware acceleration.
            pfd_attrib_list[index] = WGL_ACCELERATION_ARB;
            pfd_attrib_list[index + 1] = WGL_FULL_ACCELERATION_ARB;
            index += 2;
        }

        if (cfg.flags.double_buffered) {
            // Support for double buffer.
            pfd_attrib_list[index] = WGL_DOUBLE_BUFFER_ARB;
            pfd_attrib_list[index + 1] = 1;
            index += 2;
        }

        // Specifiy accum bits count.
        pfd_attrib_list[index] = WGL_ACCUM_RED_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.accum.red_bits;
        index += 2;
        pfd_attrib_list[index] = WGL_ACCUM_GREEN_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.accum.green_bits;
        index += 2;
        pfd_attrib_list[index] = WGL_ACCUM_BLUE_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.accum.blue_bits;
        index += 2;
        pfd_attrib_list[index] = WGL_ACCUM_ALPHA_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.accum.alpha_bits;
        index += 2;

        // Stencil bits
        pfd_attrib_list[index] = WGL_STENCIL_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.stencil_bits;
        index += 2;

        // Support for var bit depth buffer.
        pfd_attrib_list[index] = WGL_DEPTH_BITS_ARB;
        pfd_attrib_list[index + 1] = cfg.depth_bits;
        index += 2;

        // Support for swapping front and back buffer.
        pfd_attrib_list[index] = WGL_SWAP_METHOD_ARB;
        pfd_attrib_list[index + 1] = WGL_SWAP_EXCHANGE_ARB;
        index += 2;

        // Support for the RGBA pixel type.
        pfd_attrib_list[index] = WGL_PIXEL_TYPE_ARB;
        pfd_attrib_list[index + 1] = WGL_TYPE_RGBA_ARB;
        index += 2;

        // Null terminate the attribute list.
        pfd_attrib_list[index] = 0;

        const dc = gdi.GetDC(hwnd);
        if (wgl_proc.ChoosePixelFormatARB(
            dc,
            &pfd_attrib_list,
            null,
            1,
            &pixel_format,
            &format_count,
        ) != 1) {
            //ERROR
        }

        if (opengl.SetPixelFormat(dc, pixel_format[0], &pfd) != 1) {
            //ERROR
        }

        // Set the 4.0 version of OpenGL in the attribute list.
        gl_attrib_list[0] = WGL_CONTEXT_MAJOR_VERSION_ARB;
        gl_attrib_list[1] = cfg.ver.major;
        gl_attrib_list[2] = WGL_CONTEXT_MINOR_VERSION_ARB;
        gl_attrib_list[3] = cfg.ver.minor;

        gl_attrib_list[5] = 0;

        const rc = wgl_proc.CreateContextAttribsARB(dc, 0, &gl_attrib_list);

        if (rc == null) {
            //ERROR
        }

        return .{
            .cfg = cfg.*,
            .glc_handle = rc.?,
            .owner = hwnd,
        };
    }

    pub fn deinit(self: *const Self) void {
        _ = opengl.wglMakeCurrent(null, null);
        _ = opengl.wglDeleteContext(self.glc_handle);
    }

    pub fn makeCurrent(self: *const Self) bool {
        const wdc = gdi.GetDC(self.owner);
        const success = opengl.wglMakeCurrent(wdc, self.glc_handle) == win32.TRUE;
        _ = gdi.ReleaseDC(self.owner, wdc);
        return success;
    }

    pub fn swapBuffers(self: *const Self) bool {
        const wdc = gdi.GetDC(self.owner);
        const success = opengl.SwapBuffers(wdc) == win32.TRUE;
        _ = gdi.ReleaseDC(self.owner, wdc);
        return success;
    }

    // pub fn setSwapIntervals(self:*const Self,intrvl:i32) void{
    //     //TODO:
    // }
};
