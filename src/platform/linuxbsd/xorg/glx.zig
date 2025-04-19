const std = @import("std");
const builtin = @import("builtin");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const gl = @import("opengl");
const mem = std.mem;
const debug = std.debug;
const unix = common.unix;
const X11Driver = @import("driver.zig").X11Driver;

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
    ) callconv(.C) ?[*]GLXFBConfig;
    const glXChooseFBConfigProc = *const fn (
        display: ?*libx11.Display,
        screen: c_int,
        attrib_list: [*]const c_int,
        nelements: *c_int,
    ) callconv(.C) ?[*]GLXFBConfig;
    const glXGetFBConfigAttribProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
        attribute: c_int,
        value: *c_int,
    ) callconv(.C) c_int;
    const glXGetClientStringProc = *const fn (
        display: ?*libx11.Display,
        name: c_int,
    ) callconv(.C) [*:0]const u8;
    const glXQueryExtensionProc = *const fn (
        display: ?*libx11.Display,
        error_base: *c_int,
        event_base: *c_int,
    ) callconv(.C) libx11.Bool;
    const glXQueryExtensionsStringProc = *const fn (
        display: ?*libx11.Display,
        screen: c_int,
    ) callconv(.C) [*:0]const u8;
    const glXQueryVersionProc = *const fn (
        display: ?*libx11.Display,
        major: *c_int,
        minor: *c_int,
    ) callconv(.C) libx11.Bool;
    const glXDestroyContextProc = *const fn (
        display: ?*libx11.Display,
        ctx: GLXContext,
    ) callconv(.C) void;
    const glXDestroyWindowProc = *const fn (
        display: ?*libx11.Display,
        window: GLXWindow,
    ) callconv(.C) void;
    const glXCreateWindowProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
        window: libx11.Window,
        attrib_list: ?[*]const c_int,
    ) callconv(.C) GLXWindow;
    const glXCreateNewContextProc = *const fn (
        display: ?*libx11.Display,
        config: GLXFBConfig,
        render_type: c_int,
        share_list: ?GLXContext,
        direct: libx11.Bool,
    ) callconv(.C) ?GLXContext;
    const glXMakeCurrentProc = *const fn (
        display: ?*libx11.Display,
        drawable: GLXDrawable,
        ctx: GLXContext,
    ) callconv(.C) libx11.Bool;
    const glXSwapBuffersProc = *const fn (
        display: ?*libx11.Display,
        drawable: GLXDrawable,
    ) callconv(.C) void;
    const glXGetVisualFromFBConfigProc = *const fn (display: ?*libx11.Display, config: GLXFBConfig) callconv(.C) ?*libx11.XVisualInfo;
    const glXGetProcAddressProc = *const fn (proc_name: [*:0]const u8) callconv(.C) ?*anyopaque;
    const glXGetProcAddressARBProc = *const fn (proc_name: [*:0]const u8) callconv(.C) ?*anyopaque;

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

pub const glx_ext_api = struct {
    var supported_extensions: [:0]const u8 = "";
    var ARB_create_context: bool = false;
    var EXT_swap_control: bool = false;
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
    ) callconv(.C) void = null;
    var glXCreateContextAttribsARB: ?*const fn (
        dpy: ?*libx11.Display,
        config: GLXFBConfig,
        share_context: ?GLXContext,
        direct: libx11.Bool,
        attrib_list: [*]const c_int,
    ) callconv(.C) ?GLXContext = null;
};

pub fn initGLX(driver: *const X11Driver) (unix.ModuleError || GLXError)!void {
    if (__glx_module != null) {
        return;
    }

    for (GLX_SO_NAMES) |name| {
        __glx_module = unix.loadPosixModule(name);
        if (__glx_module) |_| {
            break;
        }
    }

    if (__glx_module) |m| {
        glx_api.glXGetFBConfigs = @ptrCast(unix.moduleSymbol(m, "glXGetFBConfigs") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXChooseFBConfig = @ptrCast(unix.moduleSymbol(m, "glXChooseFBConfig") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXGetFBConfigAttrib = @ptrCast(unix.moduleSymbol(m, "glXGetFBConfigAttrib") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXGetClientString = @ptrCast(unix.moduleSymbol(m, "glXGetClientString") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXQueryExtension = @ptrCast(unix.moduleSymbol(m, "glXQueryExtension") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXQueryExtensionsString = @ptrCast(unix.moduleSymbol(m, "glXQueryExtensionsString") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXQueryVersion = @ptrCast(unix.moduleSymbol(m, "glXQueryVersion") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXCreateNewContext = @ptrCast(unix.moduleSymbol(m, "glXCreateNewContext") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXDestroyContext = @ptrCast(unix.moduleSymbol(m, "glXDestroyContext") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXCreateWindow = @ptrCast(unix.moduleSymbol(m, "glXCreateWindow") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXDestroyWindow = @ptrCast(unix.moduleSymbol(m, "glXDestroyWindow") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXMakeCurrent = @ptrCast(unix.moduleSymbol(m, "glXMakeCurrent") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXSwapBuffers = @ptrCast(unix.moduleSymbol(m, "glXSwapBuffers") orelse
            return unix.ModuleError.UndefinedSymbol);
        glx_api.glXGetVisualFromFBConfig = @ptrCast(unix.moduleSymbol(m, "glXGetVisualFromFBConfig") orelse
            return unix.ModuleError.UndefinedSymbol);

        glx_api.glXGetProcAddress = @ptrCast(unix.moduleSymbol(m, "glXGetProcAddress"));
        glx_api.glXGetProcAddressARB = @ptrCast(unix.moduleSymbol(m, "glXGetProcAddressARB"));
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

    glx_ext_api.supported_extensions = mem.span(extensions);

    if (gl.glHasExtension("GLX_EXT_swap_control", glx_ext_api.supported_extensions)) {
        glx_ext_api.glXSwapIntervalEXT =
            @ptrCast(glLoaderFunc("glXSwapIntervalEXT"));

        if (glx_ext_api.glXSwapIntervalEXT) |_|
            glx_ext_api.EXT_swap_control = true;
    }

    if (gl.glHasExtension("GLX_ARB_multisample", glx_ext_api.supported_extensions))
        glx_ext_api.ARB_multisample = true;

    if (gl.glHasExtension("GLX_ARB_framebuffer_sRGB", glx_ext_api.supported_extensions))
        glx_ext_api.ARB_framebuffer_sRGB = true;

    if (gl.glHasExtension("GLX_EXT_framebuffer_sRGB", glx_ext_api.supported_extensions))
        glx_ext_api.EXT_framebuffer_sRGB = true;

    if (gl.glHasExtension("GLX_ARB_create_context", glx_ext_api.supported_extensions)) {
        glx_ext_api.glXCreateContextAttribsARB =
            @ptrCast(glLoaderFunc("glXCreateContextAttribsARB"));

        if (glx_ext_api.glXCreateContextAttribsARB) |_|
            glx_ext_api.ARB_create_context = true;
    }

    if (gl.glHasExtension("GLX_ARB_create_context_robustness", glx_ext_api.supported_extensions)) {
        glx_ext_api.ARB_create_context_robustness = true;
    }

    if (gl.glHasExtension("GLX_ARB_create_context_profile", glx_ext_api.supported_extensions)) {
        glx_ext_api.ARB_create_context_profile = true;
    }

    if (gl.glHasExtension("GLX_EXT_create_context_es2_profile", glx_ext_api.supported_extensions)) {
        glx_ext_api.EXT_create_context_es2_profile = true;
    }

    if (gl.glHasExtension("GLX_ARB_create_context_no_error", glx_ext_api.supported_extensions)) {
        glx_ext_api.ARB_create_context_no_error = true;
    }

    if (gl.glHasExtension("GLX_ARB_context_flush_control", glx_ext_api.supported_extensions)) {
        glx_ext_api.ARB_context_flush_control = true;
    }
}

pub fn chooseVisualGLX(driver: *const X11Driver, fb_cfg: *const common.fb.FBConfig, vis: *?*libx11.Visual, depth: *c_int) bool {
    const glx_fb_cfg = chooseFBConfig(driver, fb_cfg);
    if (glx_fb_cfg) |cfg| {
        const result = glx_api.glXGetVisualFromFBConfig(driver.handles.xdisplay, cfg);
        if (result) |r| {
            defer _ = libx11.XFree(@ptrCast(r));
            vis.* = r.visual orelse return false;
            depth.* = r.depth;
            return true;
        }
    }
    return false;
}

fn chooseFBConfig(driver: *const X11Driver, cfg: *const common.fb.FBConfig) ?GLXFBConfig {
    var attribs: [64]c_int = mem.zeroes([64]c_int);
    const helper = struct {
        pub inline fn setAttribute(list: []c_int, idx: *usize, attrib: c_int, val: c_int) void {
            debug.assert(idx.* < list.len);
            list[idx.*] = attrib;
            list[idx.* + 1] = val;
            idx.* += 2;
        }
    };
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
        defer _ = libx11.XFree(@ptrCast(fb_configs.?));
        for (0..@as(usize, @intCast(configs_count))) |i| {
            const visual = glx_api.glXGetVisualFromFBConfig(
                driver.handles.xdisplay,
                fb_configs.?[i],
            );
            if (visual) |vi| {
                _ = libx11.XFree(vi);
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
) (GLXError || unix.ModuleError)!?GLXContext {
    var gl_attrib_list: [16]c_int = undefined;
    var glx_rc: ?GLXContext = null;

    const fb_cfg = chooseFBConfig(driver, cfg) orelse {
        return GLXError.UnsupportedFBConfig;
    };

    if (glx_ext_api.ARB_create_context) {
        if (cfg.accel.opengl.ver.major > 1 or cfg.accel.opengl.ver.minor > 0) {
            gl_attrib_list[0] = GLX_CONTEXT_MAJOR_VERSION_ARB;
            gl_attrib_list[1] = cfg.accel.opengl.ver.major;
            gl_attrib_list[2] = GLX_CONTEXT_MINOR_VERSION_ARB;
            gl_attrib_list[3] = cfg.accel.opengl.ver.minor;
        }
        gl_attrib_list[4] = GLX_CONTEXT_PROFILE_MASK_ARB;
        gl_attrib_list[5] = if (cfg.accel.opengl.profile == .Core)
            GLX_CONTEXT_CORE_PROFILE_BIT_ARB
        else
            GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;

        gl_attrib_list[6] = 0;
        gl_attrib_list[7] = 0;

        glx_rc = glx_ext_api.glXCreateContextAttribsARB.?(
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
    glrc: GLXContext,
    glwndw: GLXWindow,
    owner: libx11.Window,
    driver: struct {
        name: [*:0]const u8,
        vendor: [*:0]const u8,
        version: [*:0]const u8,
    },
    x_display: *libx11.Display,
    const Self = @This();

    pub fn init(driver: *const X11Driver, window: libx11.Window, cfg: *const common.fb.FBConfig) GLXError!Self {
        var glx_wndw: GLXWindow = 0;
        const rc = createGLContext(driver, window, cfg, &glx_wndw) catch |err| {
            switch (err) {
                unix.ModuleError.NotFound, unix.ModuleError.UndefinedSymbol => return GLXError.MissingLibGLX,
                else => return @as(GLXError, @errorCast(err)),
            }
        };

        if (rc == null) {
            return GLXError.NullContext;
        }

        _ = glx_api.glXMakeCurrent(driver.handles.xdisplay, glx_wndw, rc.?);

        var glGetString: ?*const fn (pname: u32) callconv(.C) ?[*:0]const u8 = null;
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
                .name = rend,
                .vendor = vend,
                .version = ver,
            },
            .x_display = driver.handles.xdisplay,
        };
    }

    pub fn deinit(self: *Self) void {
        glx_api.glXDestroyWindow(self.x_display, self.glwndw);
        self.glwndw = undefined;
        glx_api.glXDestroyContext(self.x_display, self.glrc);
        self.glrc = undefined;
    }

    pub fn makeCurrent(self: *const Self) bool {
        const ret = glx_api.glXMakeCurrent(self.x_display, self.glwndw, self.glrc);
        return ret == libx11.True;
    }

    pub fn swapBuffers(self: *const Self) bool {
        glx_api.glXSwapBuffers(self.x_display, self.glwndw);
        return true;
    }

    pub fn setSwapIntervals(self: *const Self, intrvl: i32) bool {
        if (glx_ext_api.EXT_swap_control and glx_ext_api.glXSwapIntervalEXT != null) {
            glx_ext_api.glXSwapIntervalEXT.?(
                self.x_display,
                self.glwndw,
                @intCast(intrvl),
            );
            return true;
        }
        return false;
    }
};

pub fn glLoaderFunc(symbol_name: [*:0]const u8) ?*const anyopaque {
    if (glx_api.glXGetProcAddress) |proc| {
        return proc(symbol_name);
    } else if (glx_api.glXGetProcAddressARB) |proc| {
        return proc(symbol_name);
    } else if (__glx_module) |m| {
        return unix.moduleSymbol(m, symbol_name);
    } else {
        return null;
    }
}
