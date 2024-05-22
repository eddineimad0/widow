const zigwin32 = @import("zigwin32");
const Window = @import("window.zig").Window;
const win32 = @import("win32_defs.zig");
const opengl = zigwin32.graphics.open_gl;
const gdi = zigwin32.graphics.gdi;

const WGLCError = error{
    PFDNoMatch,
    GLCNoHandle,
};

pub const WinGLContext = struct {
    glc_handle: opengl.HGLRC,
    owner: win32.HWND,

    const Self = @This();

    pub fn init(hwnd: win32.HWND) !Self {
        var pfd = opengl.PIXELFORMATDESCRIPTOR{
            .nSize = @sizeOf(opengl.PIXELFORMATDESCRIPTOR),
            .nVersion = 1,
            .dwFlags = gdi.PFD_DRAW_TO_WINDOW |
                gdi.PFD_SUPPORT_OPENGL |
                gdi.PFD_DOUBLEBUFFER,
            .iPixelType = gdi.PFD_TYPE_RGBA,
            .cColorBits = 24, // 8 red + 8 blue + 8 green
            .cRedBits = 0,
            .cRedShift = 0,
            .cGreenBits = 0,
            .cGreenShift = 0,
            .cBlueBits = 0,
            .cBlueShift = 0,
            .cAlphaBits = 8,
            .cAlphaShift = 0,
            .cAccumBits = 0,
            .cAccumRedBits = 0,
            .cAccumGreenBits = 0,
            .cAccumBlueBits = 0,
            .cAccumAlphaBits = 0,
            .cDepthBits = 24,
            .cStencilBits = 8,
            .cAuxBuffers = 0,
            .iLayerType = gdi.PFD_MAIN_PLANE, // TODO: the docs says this field is ignored remove and test.
            .bReserved = 0,
            .dwLayerMask = 0,
            .dwVisibleMask = 0,
            .dwDamageMask = 0,
        };

        const wdc = gdi.GetDC(hwnd);

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

        _ = gdi.ReleaseDC(hwnd, wdc);

        return Self{
            .glc_handle = glc.?,
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
};
