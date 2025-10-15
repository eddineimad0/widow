const std = @import("std");
const builtin = @import("builtin");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");

const mem = std.mem;
const debug = std.debug;
const io = std.io;
const so = common.unix.so;

const X11Driver = @import("driver.zig").X11Driver;
const X11Canvas = @import("window.zig").X11Canvas;

pub const GLX_SO_NAMES = switch (builtin.target.os.tag) {
    .linux => [_][*:0]const u8{ "libGLX.so.0", "libGL.so.1", "libGL.so" },
    .freebsd, .netbsd, .openbsd => [_][*:0]const u8{"libGL.so"},
    else => @compileError("Unsupported Unix Platform"),
};

const __GLXFBConfigRec = opaque {};
const __GLXContextRec = opaque {};
const GLXFBConfig = *__GLXFBConfigRec;
const GLXContext = *__GLXContextRec;
const GLXWindow = libx11.Window;
const GLXDrawable = libx11.XID;

const GLX_USE_GL = 1;
const GLX_BUFFER_SIZE = 2;
const GLX_LEVEL = 3;
const GLX_RGBA = 4;
const GLX_DOUBLEBUFFER = 5;
const GLX_STEREO = 6;
const GLX_AUX_BUFFERS = 7;
const GLX_RED_SIZE = 8;
const GLX_GREEN_SIZE = 9;
const GLX_BLUE_SIZE = 10;
const GLX_ALPHA_SIZE = 11;
const GLX_DEPTH_SIZE = 12;
const GLX_STENCIL_SIZE = 13;
const GLX_ACCUM_RED_SIZE = 14;
const GLX_ACCUM_GREEN_SIZE = 15;
const GLX_ACCUM_BLUE_SIZE = 16;
const GLX_ACCUM_ALPHA_SIZE = 17;

const GLX_BAD_SCREEN = 1;
const GLX_BAD_ATTRIBUTE = 2;
const GLX_NO_EXTENSION = 3;
const GLX_BAD_VISUAL = 4;
const GLX_BAD_CONTEXT = 5;
const GLX_BAD_VALUE = 6;
const GLX_BAD_ENUM = 7;

const GLX_VENDOR = 1;
const GLX_VERSION = 2;
const GLX_EXTENSIONS = 3;

const GLX_CONFIG_CAVEAT = 0x20;
const GLX_DONT_CARE = 0xFFFFFFFF;
const GLX_X_VISUAL_TYPE = 0x22;
const GLX_TRANSPARENT_TYPE = 0x23;
const GLX_TRANSPARENT_INDEX_VALUE = 0x24;
const GLX_TRANSPARENT_RED_VALUE = 0x25;
const GLX_TRANSPARENT_GREEN_VALUE = 0x26;
const GLX_TRANSPARENT_BLUE_VALUE = 0x27;
const GLX_TRANSPARENT_ALPHA_VALUE = 0x28;
const GLX_WINDOW_BIT = 0x00000001;
const GLX_PIXMAP_BIT = 0x00000002;
const GLX_PBUFFER_BIT = 0x00000004;
const GLX_AUX_BUFFERS_BIT = 0x00000010;
const GLX_FRONT_LEFT_BUFFER_BIT = 0x00000001;
const GLX_FRONT_RIGHT_BUFFER_BIT = 0x00000002;
const GLX_BACK_LEFT_BUFFER_BIT = 0x00000004;
const GLX_BACK_RIGHT_BUFFER_BIT = 0x00000008;
const GLX_DEPTH_BUFFER_BIT = 0x00000020;
const GLX_STENCIL_BUFFER_BIT = 0x00000040;
const GLX_ACCUM_BUFFER_BIT = 0x00000080;
const GLX_NONE = 0x8000;
const GLX_SLOW_CONFIG = 0x8001;
const GLX_TRUE_COLOR = 0x8002;
const GLX_DIRECT_COLOR = 0x8003;
const GLX_PSEUDO_COLOR = 0x8004;
const GLX_STATIC_COLOR = 0x8005;
const GLX_GRAY_SCALE = 0x8006;
const GLX_STATIC_GRAY = 0x8007;
const GLX_TRANSPARENT_RGB = 0x8008;
const GLX_TRANSPARENT_INDEX = 0x8009;
const GLX_VISUAL_ID = 0x800B;
const GLX_SCREEN = 0x800C;
const GLX_NON_CONFORMANT_CONFIG = 0x800D;
const GLX_DRAWABLE_TYPE = 0x8010;
const GLX_RENDER_TYPE = 0x8011;
const GLX_X_RENDERABLE = 0x8012;
const GLX_FBCONFIG_ID = 0x8013;
const GLX_RGBA_TYPE = 0x8014;
const GLX_COLOR_INDEX_TYPE = 0x8015;
const GLX_MAX_PBUFFER_WIDTH = 0x8016;
const GLX_MAX_PBUFFER_HEIGHT = 0x8017;
const GLX_MAX_PBUFFER_PIXELS = 0x8018;
const GLX_PRESERVED_CONTENTS = 0x801B;
const GLX_LARGEST_PBUFFER = 0x801C;
const GLX_WIDTH = 0x801D;
const GLX_HEIGHT = 0x801E;
const GLX_EVENT_MASK = 0x801F;
const GLX_DAMAGED = 0x8020;
const GLX_SAVED = 0x8021;
const GLX_WINDOW = 0x8022;
const GLX_PBUFFER = 0x8023;
const GLX_PBUFFER_HEIGHT = 0x8040;
const GLX_PBUFFER_WIDTH = 0x8041;
const GLX_RGBA_BIT = 0x00000001;
const GLX_COLOR_INDEX_BIT = 0x00000002;
const GLX_PBUFFER_CLOBBER_MASK = 0x08000000;
const GLX_FRAMEBUFFER_SRGB_CAPABLE_ARB = 0x20B2;

const GLX_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
const GLX_CONTEXT_MINOR_VERSION_ARB = 0x2092;
const GLX_CONTEXT_FLAGS_ARB = 0x2094;
const GLX_CONTEXT_PROFILE_MASK_ARB = 0x9126;
const GLX_CONTEXT_DEBUG_BIT_ARB = 0x0001;
const GLX_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 0x0002;
const GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
const GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002;

pub const glx_api = struct {
    const glXGetFBConfigsProc = *const fn (
        display: ?*libx11.Display,
        screen: c_int,
        nelements: *c_int,
    ) callconv(.c) ?[*]GLXFBConfig;
    const glXChooseFBConfigProc = *const fn (
        display: ?*libx11.Display,
        screen: c_int,
        attrib_list: [*]const c_int,
        nelements: *c_int,
    ) callconv(.c) ?[*]GLXFBConfig;
    const glXGetFBConfigAttribProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
        attribute: c_int,
        value: *c_int,
    ) callconv(.c) c_int;
    const glXGetClientStringProc = *const fn (
        display: ?*libx11.Display,
        name: c_int,
    ) callconv(.c) [*:0]const u8;
    const glXQueryExtensionProc = *const fn (
        display: ?*libx11.Display,
        error_base: *c_int,
        event_base: *c_int,
    ) callconv(.c) libx11.Bool;
    const glXQueryExtensionsStringProc = *const fn (
        display: ?*libx11.Display,
        screen: c_int,
    ) callconv(.c) [*:0]const u8;
    const glXQueryVersionProc = *const fn (
        display: ?*libx11.Display,
        major: *c_int,
        minor: *c_int,
    ) callconv(.c) libx11.Bool;
    const glXDestroyContextProc = *const fn (
        display: ?*libx11.Display,
        ctx: GLXContext,
    ) callconv(.c) void;
    const glXDestroyWindowProc = *const fn (
        display: ?*libx11.Display,
        window: GLXWindow,
    ) callconv(.c) void;
    const glXCreateWindowProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
        window: libx11.Window,
        attrib_list: ?[*]const c_int,
    ) callconv(.c) GLXWindow;
    const glXCreateNewContextProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
        render_type: c_int,
        share_list: ?GLXContext,
        direct: libx11.Bool,
    ) callconv(.c) ?GLXContext;
    const glXMakeCurrentProc = *const fn (
        display: ?*libx11.Display,
        drawable: GLXDrawable,
        ctx: GLXContext,
    ) callconv(.c) libx11.Bool;
    const glXSwapBuffersProc = *const fn (
        display: ?*libx11.Display,
        drawable: GLXDrawable,
    ) callconv(.c) void;
    const glXGetVisualFromFBConfigProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
    ) callconv(.c) ?*libx11.XVisualInfo;
    const glXGetProcAddressProc = *const fn (
        proc_name: [*:0]const u8,
    ) callconv(.c) ?*anyopaque;
    const glXGetProcAddressARBProc = *const fn (
        proc_name: [*:0]const u8,
    ) callconv(.c) ?*anyopaque;

    var glXGetFBConfigs: glXGetFBConfigsProc = undefined;
    var glXChooseFBConfig: glXChooseFBConfigProc = undefined;
    var glXGetFBConfigAttrib: glXGetFBConfigAttribProc = undefined;
    var glXGetClientString: glXGetClientStringProc = undefined;
    var glXQueryExtension: glXQueryExtensionProc = undefined;
    var glXQueryExtensionsString: glXQueryExtensionsStringProc = undefined;
    var glXQueryVersion: glXQueryVersionProc = undefined;
    var glXDestroyContext: glXDestroyContextProc = undefined;
    var glXMakeCurrent: glXMakeCurrentProc = undefined;
    var glXSwapBuffers: glXSwapBuffersProc = undefined;
    var glXCreateNewContext: glXCreateNewContextProc = undefined;
    var glXCreateWindow: glXCreateWindowProc = undefined;
    var glXDestroyWindow: glXDestroyWindowProc = undefined;
    var glXGetVisualFromFBConfig: glXGetVisualFromFBConfigProc = undefined;
    var glXGetProcAddress: ?glXGetProcAddressProc = null;
    var glXGetProcAddressARB: ?glXGetProcAddressARBProc = null;

    var event_base: c_int = 0;
    var error_base: c_int = 0;
    var ver_maj: c_int = 0;
    var ver_min: c_int = 0;
};

var __glx_module: ?*anyopaque = null;

pub const glx_ext = struct {
    var supported_extensions: [:0]const u8 = "";
    var ARB_create_context: bool = false;
    var EXT_swap_control_tear: bool = false;
    var ARB_multisample: bool = false;
    var ARB_framebuffer_sRGB: bool = false;
    var EXT_framebuffer_sRGB: bool = false;
    var ARB_create_context_robustness: bool = false;
    var ARB_create_context_profile: bool = false;
    var EXT_create_context_es2_profile: bool = false;
    var ARB_create_context_no_error: bool = false;
    var ARB_context_flush_control: bool = false;

    var glXSwapIntervalEXT: ?*const fn (
        dpy: ?*libx11.Display,
        drawable: GLXDrawable,
        interval: c_int,
    ) callconv(.c) void = null;
    var glXCreateContextAttribsARB: ?*const fn (
        dpy: ?*libx11.Display,
        config: GLXFBConfig,
        share_context: ?GLXContext,
        direct: libx11.Bool,
        attrib_list: [*]const c_int,
    ) callconv(.c) ?GLXContext = null;
};

pub fn initGLX(driver: *const X11Driver) (so.ModuleError || GLXError)!void {
    if (__glx_module != null) {
        return;
    }

    for (GLX_SO_NAMES) |name| {
        __glx_module = so.loadPosixModule(name);
        if (__glx_module) |_| {
            break;
        }
    }

    if (__glx_module) |m| {
        glx_api.glXGetFBConfigs = @ptrCast(so.moduleSymbol(m, "glXGetFBConfigs") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXChooseFBConfig = @ptrCast(so.moduleSymbol(m, "glXChooseFBConfig") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXGetFBConfigAttrib = @ptrCast(so.moduleSymbol(m, "glXGetFBConfigAttrib") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXGetClientString = @ptrCast(so.moduleSymbol(m, "glXGetClientString") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXQueryExtension = @ptrCast(so.moduleSymbol(m, "glXQueryExtension") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXQueryExtensionsString = @ptrCast(so.moduleSymbol(m, "glXQueryExtensionsString") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXQueryVersion = @ptrCast(so.moduleSymbol(m, "glXQueryVersion") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXCreateNewContext = @ptrCast(so.moduleSymbol(m, "glXCreateNewContext") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXDestroyContext = @ptrCast(so.moduleSymbol(m, "glXDestroyContext") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXCreateWindow = @ptrCast(so.moduleSymbol(m, "glXCreateWindow") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXDestroyWindow = @ptrCast(so.moduleSymbol(m, "glXDestroyWindow") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXMakeCurrent = @ptrCast(so.moduleSymbol(m, "glXMakeCurrent") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXSwapBuffers = @ptrCast(so.moduleSymbol(m, "glXSwapBuffers") orelse
            return so.ModuleError.UndefinedSymbol);
        glx_api.glXGetVisualFromFBConfig = @ptrCast(so.moduleSymbol(m, "glXGetVisualFromFBConfig") orelse
            return so.ModuleError.UndefinedSymbol);

        glx_api.glXGetProcAddress = @ptrCast(so.moduleSymbol(m, "glXGetProcAddress"));
        glx_api.glXGetProcAddressARB = @ptrCast(so.moduleSymbol(m, "glXGetProcAddressARB"));
    } else {
        return GLXError.ModuleNotFound;
    }

    if (glx_api.glXQueryExtension(driver.handles.xdisplay, &glx_api.error_base, &glx_api.event_base) != libx11.True) {
        return GLXError.ServerNoSupport;
    }

    if (glx_api.glXQueryVersion(driver.handles.xdisplay, &glx_api.ver_maj, &glx_api.ver_min) != libx11.True) {
        return GLXError.UnsupportedVersion;
    }

    if (glx_api.ver_maj < 1 or glx_api.ver_min < 3) {
        return GLXError.UnsupportedVersion;
    }

    const extensions = glx_api.glXQueryExtensionsString(driver.handles.xdisplay, driver.handles.default_screen);

    glx_ext.supported_extensions = mem.span(extensions);

    if (common.fb.glHasExtension("GLX_EXT_swap_control", glx_ext.supported_extensions)) {
        glx_ext.glXSwapIntervalEXT =
            @ptrCast(glLoaderFunc("glXSwapIntervalEXT"));

        if (common.fb.glHasExtension("GLX_EXT_swap_control_tear", glx_ext.supported_extensions)) {
            glx_ext.EXT_swap_control_tear = true;
        }
    }

    if (common.fb.glHasExtension("GLX_ARB_multisample", glx_ext.supported_extensions))
        glx_ext.ARB_multisample = true;

    if (common.fb.glHasExtension("GLX_ARB_framebuffer_sRGB", glx_ext.supported_extensions))
        glx_ext.ARB_framebuffer_sRGB = true;

    if (common.fb.glHasExtension("GLX_EXT_framebuffer_sRGB", glx_ext.supported_extensions))
        glx_ext.EXT_framebuffer_sRGB = true;

    if (common.fb.glHasExtension("GLX_ARB_create_context", glx_ext.supported_extensions)) {
        glx_ext.glXCreateContextAttribsARB =
            @ptrCast(glLoaderFunc("glXCreateContextAttribsARB"));

        if (glx_ext.glXCreateContextAttribsARB) |_|
            glx_ext.ARB_create_context = true;
    }

    if (common.fb.glHasExtension("GLX_ARB_create_context_robustness", glx_ext.supported_extensions)) {
        glx_ext.ARB_create_context_robustness = true;
    }

    if (common.fb.glHasExtension("GLX_ARB_create_context_profile", glx_ext.supported_extensions)) {
        glx_ext.ARB_create_context_profile = true;
    }

    if (common.fb.glHasExtension("GLX_EXT_create_context_es2_profile", glx_ext.supported_extensions)) {
        glx_ext.EXT_create_context_es2_profile = true;
    }

    if (common.fb.glHasExtension("GLX_ARB_create_context_no_error", glx_ext.supported_extensions)) {
        glx_ext.ARB_create_context_no_error = true;
    }

    if (common.fb.glHasExtension("GLX_ARB_context_flush_control", glx_ext.supported_extensions)) {
        glx_ext.ARB_context_flush_control = true;
    }
}

pub fn chooseVisualGLX(driver: *const X11Driver, fb_cfg: *const common.fb.FBConfig, vis: *?*libx11.Visual, depth: *c_int) bool {
    const glx_fb_cfg = chooseFBConfig(driver, fb_cfg);
    if (glx_fb_cfg) |cfg| {
        const result = glx_api.glXGetVisualFromFBConfig(driver.handles.xdisplay, cfg);
        if (result) |r| {
            defer _ = libx11.dyn_api.XFree(@ptrCast(r));
            vis.* = r.visual orelse return false;
            depth.* = r.depth;
            return true;
        }
    }
    return false;
}

const helper = struct {
    pub inline fn setAttribute(list: []c_int, idx: *usize, attrib: c_int, val: c_int) void {
        debug.assert(idx.* < list.len);
        list[idx.*] = attrib;
        list[idx.* + 1] = val;
        idx.* += 2;
    }
};

fn chooseFBConfig(driver: *const X11Driver, cfg: *const common.fb.FBConfig) ?GLXFBConfig {
    var attribs: [64]c_int = mem.zeroes([64]c_int);
    var idx: usize = 0;
    helper.setAttribute(&attribs, &idx, GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR);
    helper.setAttribute(&attribs, &idx, GLX_RENDER_TYPE, GLX_RGBA_BIT);
    helper.setAttribute(&attribs, &idx, GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT);
    helper.setAttribute(&attribs, &idx, GLX_X_RENDERABLE, 1);
    helper.setAttribute(&attribs, &idx, GLX_RED_SIZE, cfg.color.red_bits);
    helper.setAttribute(&attribs, &idx, GLX_GREEN_SIZE, cfg.color.green_bits);
    helper.setAttribute(&attribs, &idx, GLX_BLUE_SIZE, cfg.color.blue_bits);
    helper.setAttribute(&attribs, &idx, GLX_ALPHA_SIZE, cfg.color.alpha_bits);
    helper.setAttribute(&attribs, &idx, GLX_ACCUM_RED_SIZE, cfg.accum.red_bits);
    helper.setAttribute(&attribs, &idx, GLX_ACCUM_GREEN_SIZE, cfg.accum.green_bits);
    helper.setAttribute(&attribs, &idx, GLX_ACCUM_BLUE_SIZE, cfg.accum.blue_bits);
    helper.setAttribute(&attribs, &idx, GLX_ACCUM_ALPHA_SIZE, cfg.accum.alpha_bits);
    helper.setAttribute(&attribs, &idx, GLX_DEPTH_SIZE, cfg.depth_bits);
    helper.setAttribute(&attribs, &idx, GLX_STENCIL_SIZE, cfg.stencil_bits);
    if (cfg.flags.double_buffered) {
        helper.setAttribute(&attribs, &idx, GLX_DOUBLEBUFFER, 1);
    }
    if (cfg.flags.stereo) {
        helper.setAttribute(&attribs, &idx, GLX_STEREO, 1);
    }
    if (cfg.flags.sRGB) {
        helper.setAttribute(&attribs, &idx, GLX_FRAMEBUFFER_SRGB_CAPABLE_ARB, 1);
    }

    var configs_count: c_int = 0;
    const fb_configs = glx_api.glXChooseFBConfig(
        driver.handles.xdisplay,
        driver.handles.default_screen,
        &attribs,
        &configs_count,
    );

    if (fb_configs != null and configs_count > 0) {
        defer _ = libx11.dyn_api.XFree(@ptrCast(fb_configs.?));
        for (0..@as(usize, @intCast(configs_count))) |i| {
            const visual = glx_api.glXGetVisualFromFBConfig(
                driver.handles.xdisplay,
                fb_configs.?[i],
            );
            if (visual) |vi| {
                _ = libx11.dyn_api.XFree(vi);
                return fb_configs.?[i];
            } else {
                continue;
            }
        }
    }
    return null;
}

fn createGLContext(
    driver: *const X11Driver,
    w: libx11.Window,
    cfg: *const common.fb.FBConfig,
    glx_wndw: *GLXWindow,
    pxfmt_info: *common.pixel.PixelFormatInfo,
) (GLXError || so.ModuleError)!?GLXContext {
    var gl_attrib_list: [16]c_int = undefined;
    var glx_rc: ?GLXContext = null;
    var index: usize = 0;

    const fb_cfg = chooseFBConfig(driver, cfg) orelse {
        return GLXError.UnsupportedFBConfig;
    };

    if (glx_ext.ARB_create_context) {
        if (cfg.accel.opengl.ver.major > 1 or cfg.accel.opengl.ver.minor > 0) {
            helper.setAttribute(&gl_attrib_list, &index, GLX_CONTEXT_MAJOR_VERSION_ARB, cfg.accel.opengl.ver.major);
            helper.setAttribute(&gl_attrib_list, &index, GLX_CONTEXT_MINOR_VERSION_ARB, cfg.accel.opengl.ver.minor);
        }
        helper.setAttribute(
            &gl_attrib_list,
            &index,
            GLX_CONTEXT_PROFILE_MASK_ARB,
            if (cfg.accel.opengl.profile == .Core)
                GLX_CONTEXT_CORE_PROFILE_BIT_ARB
            else
                GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
        );

        var flag: c_int = 0;
        if (cfg.accel.opengl.is_debug) {
            flag |= GLX_CONTEXT_DEBUG_BIT_ARB;
        }

        if (flag != 0) {
            helper.setAttribute(&gl_attrib_list, &index, GLX_CONTEXT_FLAGS_ARB, flag);
        }

        helper.setAttribute(&gl_attrib_list, &index, 0, 0);

        glx_rc = glx_ext.glXCreateContextAttribsARB.?(
            driver.handles.xdisplay,
            fb_cfg,
            null,
            libx11.True,
            &gl_attrib_list,
        );
    } else {
        glx_rc = glx_api.glXCreateNewContext(
            driver.handles.xdisplay,
            fb_cfg,
            GLX_RGBA_TYPE,
            null,
            libx11.True,
        );
    }

    const wndw = glx_api.glXCreateWindow(driver.handles.xdisplay, fb_cfg, w, null);

    if (wndw == 0) {
        return GLXError.NullWindow;
    }

    { // fill the pixel format info param
        var alpha_bits: c_int = 0;
        const ok = glx_api.glXGetFBConfigAttrib(driver.handles.xdisplay, fb_cfg, GLX_ALPHA_SIZE, &alpha_bits);
        debug.assert(ok == libx11.Success);
        const visual_info = glx_api.glXGetVisualFromFBConfig(driver.handles.xdisplay, fb_cfg);
        debug.assert(visual_info != null); // should not return null because the fb_cfg is valid
        if (visual_info) |vinfo| {
            defer _ = libx11.dyn_api.XFree(vinfo);
            const rmask: u32 = @intCast(vinfo.red_mask);
            const gmask: u32 = @intCast(vinfo.green_mask);
            const bmask: u32 = @intCast(vinfo.blue_mask);
            const bits_per_pixel: u16 = @intCast(vinfo.depth);
            const total_bits_mask: u32 = @intCast((@as(u64, 1) << @truncate(bits_per_pixel)) - 1);
            const rgb_mask = rmask | gmask | bmask;
            const amask = if (alpha_bits == 0) 0 else (~rgb_mask) & total_bits_mask;
            common.pixel.getPixelFormatInfo(
                rmask,
                gmask,
                bmask,
                amask,
                bits_per_pixel,
                pxfmt_info,
            );
        }
    }

    glx_wndw.* = wndw;
    return glx_rc;
}

const GLXError = error{
    ModuleNotFound,
    ServerNoSupport,
    UnsupportedVersion,
    UnsupportedFBConfig,
    NullContext,
    NullWindow,
    MissingLibGLX,
};

pub const GLContext = struct {
    const GL_UNKOWN_VENDOR = "Vendor_Unknown";
    const GL_UNKOWN_RENDER = "Renderer_Unknown";
    x_display: *libx11.Display,
    glrc: GLXContext,
    driver: struct {
        hardware: [*:0]const u8,
        vendor: [*:0]const u8,
        version: [*:0]const u8,
    },
    owner: libx11.Window,
    glwndw: GLXWindow,
    px_fmt_info: common.pixel.PixelFormatInfo,
    const Self = @This();

    pub fn init(driver: *const X11Driver, window: libx11.Window, cfg: *const common.fb.FBConfig) GLXError!Self {
        var glx_wndw: GLXWindow = 0;
        var px_fmt_info: common.pixel.PixelFormatInfo = undefined;
        const rc = createGLContext(driver, window, cfg, &glx_wndw, &px_fmt_info) catch |err| {
            switch (err) {
                so.ModuleError.NotFound, so.ModuleError.UndefinedSymbol => return GLXError.MissingLibGLX,
                else => return @as(GLXError, @errorCast(err)),
            }
        };

        if (rc == null) {
            return GLXError.NullContext;
        }

        _ = glx_api.glXMakeCurrent(driver.handles.xdisplay, glx_wndw, rc.?);

        var glGetString: ?*const fn (pname: u32) callconv(.c) ?[*:0]const u8 = null;
        glGetString = @ptrCast(glLoaderFunc("glGetString"));
        var vend: [*:0]const u8 = undefined;
        var rend: [*:0]const u8 = undefined;
        var ver: [*:0]const u8 = undefined;
        if (glGetString) |func| {
            const GL_VENDOR = 0x1F00;
            const GL_RENDERER = 0x1F01;
            const GL_VERSION = 0x1F02;
            vend = func(GL_VENDOR) orelse GL_UNKOWN_VENDOR;
            rend = func(GL_RENDERER) orelse GL_UNKOWN_RENDER;
            ver = func(GL_VERSION) orelse "";
        }

        return .{
            .glrc = rc.?,
            .glwndw = glx_wndw,
            .owner = window,
            .driver = .{
                .hardware = rend,
                .vendor = vend,
                .version = ver,
            },
            .x_display = driver.handles.xdisplay,
            .px_fmt_info = px_fmt_info,
        };
    }

    pub fn deinit(self: *Self) void {
        glx_api.glXDestroyWindow(self.x_display, self.glwndw);
        self.glwndw = undefined;
        glx_api.glXDestroyContext(self.x_display, self.glrc);
        self.glrc = undefined;
    }

    pub inline fn makeCurrent(self: *const Self) bool {
        const ret = glx_api.glXMakeCurrent(self.x_display, self.glwndw, self.glrc);
        return ret == libx11.True;
    }

    pub inline fn swapBuffers(self: *const Self) bool {
        glx_api.glXSwapBuffers(self.x_display, self.glwndw);
        return true;
    }

    pub inline fn setSwapInterval(self: *const Self, interval: common.fb.SwapInterval) bool {
        if (glx_ext.glXSwapIntervalEXT) |func| {
            if (interval == .Adaptive and glx_ext.EXT_swap_control_tear == false) {
                return false;
            }
            const interval_int = @intFromEnum(interval);
            func(
                self.x_display,
                self.glwndw,
                interval_int,
            );
            return true;
        }
        return false;
    }

    pub inline fn getVendorName(self: *const Self) [*:0]const u8 {
        return self.driver.vendor;
    }

    pub inline fn getHardwareName(self: *const Self) [*:0]const u8 {
        return self.driver.hardware;
    }

    pub inline fn getDriverVersion(self: *const Self) [*:0]const u8 {
        return self.driver.version;
    }
};

pub fn glLoaderFunc(symbol_name: [*:0]const u8) ?*const anyopaque {
    if (glx_api.glXGetProcAddress) |proc| {
        return proc(symbol_name);
    } else if (glx_api.glXGetProcAddressARB) |proc| {
        return proc(symbol_name);
    } else if (__glx_module) |m| {
        return so.moduleSymbol(m, symbol_name);
    } else {
        return null;
    }
}

//===========================
// opengl rendering hooks
//============================

pub fn glSwapBuffers(ctx: *anyopaque) bool {
    const c: *X11Canvas = @ptrCast(@alignCast(ctx));
    return c.gl_ctx.swapBuffers();
}

pub fn glSetSwapInterval(ctx: *anyopaque, interval: common.fb.SwapInterval) bool {
    const c: *X11Canvas = @ptrCast(@alignCast(ctx));
    return c.gl_ctx.setSwapInterval(interval);
}

pub fn glMakeCurrent(ctx: *anyopaque) bool {
    const c: *X11Canvas = @ptrCast(@alignCast(ctx));
    return c.gl_ctx.makeCurrent();
}

pub fn glGetDriverInfo(ctx: *anyopaque, wr: *io.Writer) bool {
    const c: *X11Canvas = @ptrCast(@alignCast(ctx));
    wr.print("Driver: {s}, for Hardware: {s}, Made by: {s}", .{
        c.gl_ctx.driver.version,
        c.gl_ctx.driver.hardware,
        c.gl_ctx.driver.vendor,
    }) catch return false;
    return true;
}

pub fn glDestroyCanvas(ctx: *anyopaque) void {
    const c: *X11Canvas = @ptrCast(@alignCast(ctx));
    c.gl_ctx.deinit();
    c.* = .{ .invalid = {} };
}
