const std = @import("std");
const zigwin32 = @import("zigwin32");
const common = @import("common");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const gl = @import("opengl");

const mem = std.mem;
const debug = std.debug;
const opengl = zigwin32.graphics.open_gl;
const gdi = zigwin32.graphics.gdi;
const window_msg = zigwin32.ui.windows_and_messaging;
const Window = @import("window.zig").Window;
const Win32Driver = @import("driver.zig").Win32Driver;
const FBConfig = common.fb.FBConfig;

const WGLError = error{
    PFDNoMatch,
    NoRC,
};

const WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
const WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
const WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
const WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002;
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
        hdc: ?gdi.HDC,
        piAttribIList: ?[*]c_int,
        pfAttribFList: ?[*]f32,
        nMaxFormats: win32.UINT,
        piFormats: ?[*]c_int,
        nNumFormats: *win32.UINT,
    ) callconv(win32.WINAPI) win32.BOOL = null;

    var GetPixelFormatAttribivARB: ?*const fn (
        hdc: ?gdi.HDC,
        iPixelFormat: c_int,
        iLayerPlane: c_int,
        nAttributes: win32.UINT,
        piAttributes: ?[*]c_int,
        piValues: ?[*]c_int,
    ) callconv(win32.WINAPI) win32.BOOL = null;

    var CreateContextAttribsARB: ?*const fn (
        hdc: ?gdi.HDC,
        hShareContext: ?opengl.HGLRC,
        attribList: ?[*]c_int,
    ) callconv(win32.WINAPI) ?opengl.HGLRC = null;

    var SwapIntervalEXT: ?*const fn (
        interval: c_int,
    ) callconv(win32.WINAPI) win32.BOOL = null;

    var GetExtensionsStringARB: ?*const fn (
        hdc: ?gdi.HDC,
    ) callconv(win32.WINAPI) ?[*:0]const u8 = null;

    var supported_extensions: ?[:0]const u8 = null;
    var ARB_pixel_format: bool = false;
    var ARB_create_context: bool = false;
    var EXT_swap_control: bool = false;

    var loaded: bool = false;
};

fn fillPFDstruct(pfd: *opengl.PIXELFORMATDESCRIPTOR, cfg: *const FBConfig) void {
    pfd.nSize = @sizeOf(opengl.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = opengl.PFD_FLAGS{
        .DRAW_TO_WINDOW = 1,
        .SUPPORT_OPENGL = 1,
    };

    if (cfg.flags.double_buffered) {
        pfd.dwFlags.DOUBLEBUFFER = 1;
    }
    pfd.iPixelType = opengl.PFD_TYPE_RGBA;
    pfd.iLayerType = opengl.PFD_MAIN_PLANE;
    pfd.cColorBits = @as(u8, cfg.color.red_bits) + cfg.color.green_bits +
        cfg.color.blue_bits;
    pfd.cRedBits = cfg.color.red_bits;
    pfd.cRedShift = 0;
    pfd.cGreenBits = cfg.color.green_bits;
    pfd.cGreenShift = 0;
    pfd.cBlueBits = cfg.color.blue_bits;
    pfd.cBlueShift = 0;
    pfd.cAlphaBits = cfg.color.alpha_bits;
    pfd.cAlphaShift = 0;
    pfd.cAccumBits = @as(u8, cfg.accum.red_bits) + cfg.accum.green_bits +
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
}

fn createTempContext(
    window: win32.HWND,
) WGLError!opengl.HGLRC {
    var pfd = mem.zeroes(opengl.PIXELFORMATDESCRIPTOR);
    pfd.nSize = @sizeOf(opengl.PIXELFORMATDESCRIPTOR);
    pfd.nVersion = 1;
    pfd.dwFlags = opengl.PFD_FLAGS{
        .DRAW_TO_WINDOW = 1,
        .SUPPORT_OPENGL = 1,
        .DOUBLEBUFFER = 1,
    };

    const wdc = gdi.GetDC(window);

    const pfi = opengl.ChoosePixelFormat(wdc, &pfd);
    if (pfi == 0) {
        return WGLError.PFDNoMatch;
    }

    if (opengl.SetPixelFormat(wdc, pfi, &pfd) == win32.FALSE) {
        return WGLError.PFDNoMatch;
    }

    const glc = opengl.wglCreateContext(wdc);
    if (glc == null) {
        return WGLError.NoRC;
    }

    _ = gdi.ReleaseDC(window, wdc);

    return glc.?;
}

fn loadGLExtensions() bool {
    const drvr = Win32Driver.singleton();

    // Create a temp window
    const tmp_wndw = window_msg.CreateWindowExW(
        window_msg.WINDOW_EX_STYLE{},
        utils.MAKEINTATOM(drvr.handles.wnd_class),
        &[_:0]u16{ 0x00, 0x00 },
        window_msg.WINDOW_STYLE{ .POPUP = 1, .DISABLED = 1 },
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

    _ = window_msg.ShowWindow(tmp_wndw, window_msg.SW_HIDE);

    defer _ = window_msg.DestroyWindow(tmp_wndw);

    const tmp_glc = createTempContext(tmp_wndw.?) catch {
        return false;
    };

    defer _ = opengl.wglDeleteContext(tmp_glc);

    const wdc = gdi.GetDC(tmp_wndw);
    defer _ = gdi.ReleaseDC(tmp_wndw, wdc);

    if (opengl.wglMakeCurrent(wdc, tmp_glc) != win32.TRUE) {
        return false;
    }

    wgl_ext.GetExtensionsStringARB = @ptrCast(opengl.wglGetProcAddress(
        "wglGetExtensionsStringARB",
    ));

    if (wgl_ext.GetExtensionsStringARB == null) {
        // we can't query extensions available on the hardware.
        return true;
    }

    const extensions = wgl_ext.GetExtensionsStringARB.?(wdc);
    if (extensions) |exts| {
        wgl_ext.supported_extensions = mem.span(exts);

        if (gl.glHasExtension("WGL_ARB_pixel_format", wgl_ext.supported_extensions.?)) {
            wgl_ext.ARB_pixel_format = true;
            wgl_ext.ChoosePixelFormatARB = @ptrCast(opengl.wglGetProcAddress(
                "wglChoosePixelFormatARB",
            ));
            wgl_ext.GetPixelFormatAttribivARB = @ptrCast(opengl.wglGetProcAddress(
                "wglGetPixelFormatAttribivARB",
            ));
        }

        if (gl.glHasExtension("wgl_ext_swap_control", wgl_ext.supported_extensions.?)) {
            wgl_ext.EXT_swap_control = true;
            wgl_ext.SwapIntervalEXT = @ptrCast(opengl.wglGetProcAddress(
                "wglSwapIntervalEXT",
            ));
        }

        if (gl.glHasExtension("WGL_ARB_create_context", wgl_ext.supported_extensions.?)) {
            wgl_ext.ARB_create_context = true;
            wgl_ext.CreateContextAttribsARB = @ptrCast(opengl.wglGetProcAddress(
                "wglCreateContextAttribsARB",
            ));
        }
    }

    return true;
}

fn createGLContext(window: win32.HWND, cfg: *const FBConfig) ?opengl.HGLRC {
    var pfd_attrib_list: [48]c_int = undefined;
    var gl_attrib_list: [16]c_int = undefined;
    var pfd_fattrib_list = [1]f32{0};
    var pixel_format = [1]c_int{0};
    var format_count: u32 = 0;
    var index: usize = 0;
    var pfd: opengl.PIXELFORMATDESCRIPTOR = undefined;

    const dc = gdi.GetDC(window);

    if (wgl_ext.ARB_pixel_format) {
        const helper = struct {
            pub inline fn setAttribute(list: []c_int, idx: *usize, attrib: c_int, val: c_int) void {
                debug.assert(idx.* < list.len);
                list[idx.*] = attrib;
                list[idx.* + 1] = val;
                idx.* += 2;
            }
        };

        // Support for OpenGL rendering.
        helper.setAttribute(&pfd_attrib_list, &index, WGL_SUPPORT_OPENGL_ARB, 1);

        // Support for rendering to a window.
        helper.setAttribute(&pfd_attrib_list, &index, WGL_DRAW_TO_WINDOW_ARB, 1);

        // Specifiy color bits count.
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_COLOR_BITS_ARB,
            @as(c_int, cfg.color.red_bits) + cfg.color.blue_bits +
                cfg.color.green_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_RED_BITS_ARB,
            cfg.color.red_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_GREEN_BITS_ARB,
            cfg.color.green_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_BLUE_BITS_ARB,
            cfg.color.blue_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_ALPHA_BITS_ARB,
            cfg.color.alpha_bits,
        );

        // Specifiy accum bits count.
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_ACCUM_BITS_ARB,
            @as(c_int, cfg.accum.red_bits) + cfg.accum.blue_bits +
                cfg.accum.green_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_ACCUM_RED_BITS_ARB,
            cfg.accum.red_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_ACCUM_GREEN_BITS_ARB,
            cfg.accum.green_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_ACCUM_BLUE_BITS_ARB,
            cfg.accum.blue_bits,
        );
        helper.setAttribute(
            &pfd_attrib_list,
            &index,
            WGL_ACCUM_ALPHA_BITS_ARB,
            cfg.accum.alpha_bits,
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
            pixel_format[0] = opengl.ChoosePixelFormat(dc, &pfd);
        }
    } else {
        fillPFDstruct(&pfd, cfg);
        pixel_format[0] = opengl.ChoosePixelFormat(dc, &pfd);
    }

    if (opengl.SetPixelFormat(dc, pixel_format[0], &pfd) != win32.TRUE) {
        return null;
    }

    if (cfg.accel.opengl.ver.major < 3 or !wgl_ext.ARB_create_context) {
        return opengl.wglCreateContext(dc);
    }

    // Set the version of OpenGL in the attribute list.
    gl_attrib_list[0] = WGL_CONTEXT_MAJOR_VERSION_ARB;
    gl_attrib_list[1] = cfg.accel.opengl.ver.major;
    gl_attrib_list[2] = WGL_CONTEXT_MINOR_VERSION_ARB;
    gl_attrib_list[3] = cfg.accel.opengl.ver.minor;
    gl_attrib_list[4] = WGL_CONTEXT_PROFILE_MASK_ARB;

    // Set the OpenGL profile.
    gl_attrib_list[5] = if (cfg.accel.opengl.profile == .Core)
        WGL_CONTEXT_CORE_PROFILE_BIT_ARB
    else
        WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;

    gl_attrib_list[6] = 0;

    return wgl_ext.CreateContextAttribsARB.?(dc, null, &gl_attrib_list);
}

pub const GLContext = struct {
    glrc: opengl.HGLRC,
    owner: win32.HWND,
    driver: struct {
        name: [*:0]const u8,
        vendor: [*:0]const u8,
        version: [*:0]const u8,
    },
    const Self = @This();

    pub fn init(window: win32.HWND, cfg: *const FBConfig) WGLError!Self {
        const prev_dc = opengl.wglGetCurrentDC();
        const prev_glc = opengl.wglGetCurrentContext();
        defer _ = opengl.wglMakeCurrent(prev_dc, prev_glc);

        if (!wgl_ext.loaded) {
            wgl_ext.loaded = loadGLExtensions();
        }

        const rc = createGLContext(window, cfg);
        if (rc == null) {
            return WGLError.NoRC;
        }

        const wdc = gdi.GetDC(window);
        _ = opengl.wglMakeCurrent(wdc, rc);

        var vend: [*:0]const u8 = undefined;
        var rend: [*:0]const u8 = undefined;
        var ver: [*:0]const u8 = undefined;

        var glGetString: ?*const fn (name: u32) callconv(@import("std").os.windows.WINAPI) ?[*:0]const u8 = null;
        glGetString = @ptrCast(glLoaderFunc("glGetString"));
        if (glGetString) |func| {
            const GL_UNKOWN_VENDOR = "Vendor_Unknown";
            const GL_UNKOWN_RENDER = "Renderer_Unknown";
            vend = func(opengl.GL_VENDOR) orelse GL_UNKOWN_VENDOR;
            rend = func(opengl.GL_RENDERER) orelse GL_UNKOWN_RENDER;
            ver = func(opengl.GL_VERSION) orelse "";
        }

        _ = gdi.ReleaseDC(window, wdc);

        return .{
            .glrc = rc.?,
            .owner = window,
            .driver = .{
                .name = rend,
                .vendor = vend,
                .version = ver,
            },
        };
    }

    pub fn deinit(self: *const Self) void {
        _ = opengl.wglMakeCurrent(null, null);
        _ = opengl.wglDeleteContext(self.glrc);
    }

    pub fn makeCurrent(self: *const Self) bool {
        const wdc = gdi.GetDC(self.owner);
        const success = opengl.wglMakeCurrent(wdc, self.glrc) == win32.TRUE;
        _ = gdi.ReleaseDC(self.owner, wdc);
        return success;
    }

    pub fn swapBuffers(self: *const Self) bool {
        const wdc = gdi.GetDC(self.owner);
        const success = opengl.SwapBuffers(wdc) == win32.TRUE;
        _ = gdi.ReleaseDC(self.owner, wdc);
        return success;
    }

    pub fn setSwapIntervals(intrvl: i32) bool {
        if (wgl_ext.EXT_swap_control and intrvl > 0) {
            return wgl_ext.SwapIntervalEXT(intrvl) == win32.TRUE;
        }
        return false;
    }
};

pub fn glLoaderFunc(symbol_name: [*:0]const u8) ?*const anyopaque {
    const lib_loader = zigwin32.system.library_loader;

    var symbol_ptr = opengl.wglGetProcAddress(symbol_name);
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
        const module = lib_loader.LoadLibraryA("opengl32.dll");
        if (module) |m| {
            symbol_ptr = lib_loader.GetProcAddress(m, symbol_name);
        } else {
            return null;
        }
    }
    return symbol_ptr;
}
