const win32 = @import("std").os.windows;

//=================
// Constants
//=================
pub const GL_VENDOR = @as(u32, 7936);
pub const GL_RENDERER = @as(u32, 7937);
pub const GL_VERSION = @as(u32, 7938);
pub const GL_EXTENSIONS = @as(u32, 7939);
//=================
// Types
//=================

pub const PFD_PIXEL_TYPE = enum(i8) {
    RGBA = 0,
    COLORINDEX = 1,
};
pub const PFD_TYPE_RGBA = PFD_PIXEL_TYPE.RGBA;
pub const PFD_TYPE_COLORINDEX = PFD_PIXEL_TYPE.COLORINDEX;

pub const PFD_LAYER_TYPE = enum(i8) {
    UNDERLAY_PLANE = -1,
    MAIN_PLANE = 0,
    OVERLAY_PLANE = 1,
};
pub const PFD_UNDERLAY_PLANE = PFD_LAYER_TYPE.UNDERLAY_PLANE;
pub const PFD_MAIN_PLANE = PFD_LAYER_TYPE.MAIN_PLANE;
pub const PFD_OVERLAY_PLANE = PFD_LAYER_TYPE.OVERLAY_PLANE;

pub const PFD_FLAGS = packed struct(u32) {
    DOUBLEBUFFER: u1 = 0,
    STEREO: u1 = 0,
    DRAW_TO_WINDOW: u1 = 0,
    DRAW_TO_BITMAP: u1 = 0,
    SUPPORT_GDI: u1 = 0,
    SUPPORT_OPENGL: u1 = 0,
    GENERIC_FORMAT: u1 = 0,
    NEED_PALETTE: u1 = 0,
    NEED_SYSTEM_PALETTE: u1 = 0,
    SWAP_EXCHANGE: u1 = 0,
    SWAP_COPY: u1 = 0,
    SWAP_LAYER_BUFFERS: u1 = 0,
    GENERIC_ACCELERATED: u1 = 0,
    SUPPORT_DIRECTDRAW: u1 = 0,
    DIRECT3D_ACCELERATED: u1 = 0,
    SUPPORT_COMPOSITION: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    DEPTH_DONTCARE: u1 = 0,
    DOUBLEBUFFER_DONTCARE: u1 = 0,
    STEREO_DONTCARE: u1 = 0,
};

pub const PFD_DOUBLEBUFFER = PFD_FLAGS{ .DOUBLEBUFFER = 1 };
pub const PFD_STEREO = PFD_FLAGS{ .STEREO = 1 };
pub const PFD_DRAW_TO_WINDOW = PFD_FLAGS{ .DRAW_TO_WINDOW = 1 };
pub const PFD_DRAW_TO_BITMAP = PFD_FLAGS{ .DRAW_TO_BITMAP = 1 };
pub const PFD_SUPPORT_GDI = PFD_FLAGS{ .SUPPORT_GDI = 1 };
pub const PFD_SUPPORT_OPENGL = PFD_FLAGS{ .SUPPORT_OPENGL = 1 };
pub const PFD_GENERIC_FORMAT = PFD_FLAGS{ .GENERIC_FORMAT = 1 };
pub const PFD_NEED_PALETTE = PFD_FLAGS{ .NEED_PALETTE = 1 };
pub const PFD_NEED_SYSTEM_PALETTE = PFD_FLAGS{ .NEED_SYSTEM_PALETTE = 1 };
pub const PFD_SWAP_EXCHANGE = PFD_FLAGS{ .SWAP_EXCHANGE = 1 };
pub const PFD_SWAP_COPY = PFD_FLAGS{ .SWAP_COPY = 1 };
pub const PFD_SWAP_LAYER_BUFFERS = PFD_FLAGS{ .SWAP_LAYER_BUFFERS = 1 };
pub const PFD_GENERIC_ACCELERATED = PFD_FLAGS{ .GENERIC_ACCELERATED = 1 };
pub const PFD_SUPPORT_DIRECTDRAW = PFD_FLAGS{ .SUPPORT_DIRECTDRAW = 1 };
pub const PFD_DIRECT3D_ACCELERATED = PFD_FLAGS{ .DIRECT3D_ACCELERATED = 1 };
pub const PFD_SUPPORT_COMPOSITION = PFD_FLAGS{ .SUPPORT_COMPOSITION = 1 };
pub const PFD_DEPTH_DONTCARE = PFD_FLAGS{ .DEPTH_DONTCARE = 1 };
pub const PFD_DOUBLEBUFFER_DONTCARE = PFD_FLAGS{ .DOUBLEBUFFER_DONTCARE = 1 };
pub const PFD_STEREO_DONTCARE = PFD_FLAGS{ .STEREO_DONTCARE = 1 };

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: u16,
    nVersion: u16,
    dwFlags: PFD_FLAGS,
    iPixelType: PFD_PIXEL_TYPE,
    cColorBits: u8,
    cRedBits: u8,
    cRedShift: u8,
    cGreenBits: u8,
    cGreenShift: u8,
    cBlueBits: u8,
    cBlueShift: u8,
    cAlphaBits: u8,
    cAlphaShift: u8,
    cAccumBits: u8,
    cAccumRedBits: u8,
    cAccumGreenBits: u8,
    cAccumBlueBits: u8,
    cAccumAlphaBits: u8,
    cDepthBits: u8,
    cStencilBits: u8,
    cAuxBuffers: u8,
    iLayerType: PFD_LAYER_TYPE,
    bReserved: u8,
    dwLayerMask: u32,
    dwVisibleMask: u32,
    dwDamageMask: u32,
};

//======================
// Functions
//======================
pub extern "gdi32" fn ChoosePixelFormat(
    hdc: ?win32.HDC,
    ppfd: ?*const PIXELFORMATDESCRIPTOR,
) callconv(win32.WINAPI) i32;

pub extern "gdi32" fn DescribePixelFormat(
    hdc: ?win32.HDC,
    iPixelFormat: PFD_PIXEL_TYPE,
    nBytes: u32,
    ppfd: ?*PIXELFORMATDESCRIPTOR,
) callconv(win32.WINAPI) i32;

pub extern "gdi32" fn GetPixelFormat(
    hdc: ?win32.HDC,
) callconv(win32.WINAPI) i32;

pub extern "gdi32" fn SetPixelFormat(
    hdc: ?win32.HDC,
    format: i32,
    ppfd: ?*const PIXELFORMATDESCRIPTOR,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "opengl32" fn wglCreateContext(
    param0: ?win32.HDC,
) callconv(win32.WINAPI) ?win32.HGLRC;

pub extern "opengl32" fn wglDeleteContext(
    param0: ?win32.HGLRC,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "opengl32" fn wglGetCurrentContext() callconv(win32.WINAPI) ?win32.HGLRC;

pub extern "opengl32" fn wglGetCurrentDC() callconv(win32.WINAPI) ?win32.HDC;

pub extern "opengl32" fn wglGetProcAddress(
    param0: ?[*:0]const u8,
) callconv(win32.WINAPI) ?win32.PROC;

pub extern "opengl32" fn wglMakeCurrent(
    param0: ?win32.HDC,
    param1: ?win32.HGLRC,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "gdi32" fn SwapBuffers(
    param0: ?win32.HDC,
) callconv(win32.WINAPI) win32.BOOL;
