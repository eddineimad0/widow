const win32 = @import("std").os.windows;

//================================
// Constants
//===============================
pub const DISPLAY_DEVICE_ACTIVE = @as(u32, 1);
pub const DM_BITSPERPEL = @as(i32, 262144);
pub const DM_PELSWIDTH = @as(i32, 524288);
pub const DM_PELSHEIGHT = @as(i32, 1048576);
pub const DM_DISPLAYFREQUENCY = @as(i32, 4194304);

//==========================
// Types
//==========================
pub const HMONITOR = *opaque {};
pub const HDC = *opaque {};

pub const MONITORINFO = extern struct {
    cbSize: u32,
    rcMonitor: win32.RECT,
    rcWork: win32.RECT,
    dwFlags: u32,
};

pub const MONITORINFOEXW = extern struct {
    monitorInfo: MONITORINFO,
    szDevice: [32]u16,
};

pub const DEVMODEW = extern struct {
    dmDeviceName: [32]u16,
    dmSpecVersion: u16,
    dmDriverVersion: u16,
    dmSize: u16,
    dmDriverExtra: u16,
    dmFields: u32,
    Anonymous1: extern union {
        Anonymous1: extern struct {
            dmOrientation: i16,
            dmPaperSize: i16,
            dmPaperLength: i16,
            dmPaperWidth: i16,
            dmScale: i16,
            dmCopies: i16,
            dmDefaultSource: i16,
            dmPrintQuality: i16,
        },
        Anonymous2: extern struct {
            dmPosition: win32.POINT,
            dmDisplayOrientation: u32,
            dmDisplayFixedOutput: u32,
        },
    },
    dmColor: i16,
    dmDuplex: i16,
    dmYResolution: i16,
    dmTTOption: i16,
    dmCollate: i16,
    dmFormName: [32]u16,
    dmLogPixels: u16,
    dmBitsPerPel: u32,
    dmPelsWidth: u32,
    dmPelsHeight: u32,
    Anonymous2: extern union {
        dmDisplayFlags: u32,
        dmNup: u32,
    },
    dmDisplayFrequency: u32,
    dmICMMethod: u32,
    dmICMIntent: u32,
    dmMediaType: u32,
    dmDitherType: u32,
    dmReserved1: u32,
    dmReserved2: u32,
    dmPanningWidth: u32,
    dmPanningHeight: u32,
};

pub const DISP_CHANGE = enum(i32) {
    SUCCESSFUL = 0,
    RESTART = 1,
    FAILED = -1,
    BADMODE = -2,
    NOTUPDATED = -3,
    BADFLAGS = -4,
    BADPARAM = -5,
    BADDUALVIEW = -6,
};

pub const MONITOR_FROM_FLAGS = enum(u32) {
    NEAREST = 2,
    NULL = 0,
    PRIMARY = 1,
};

pub const CDS_TYPE = packed struct(u32) {
    UPDATEREGISTRY: u1 = 0,
    TEST: u1 = 0,
    FULLSCREEN: u1 = 0,
    GLOBAL: u1 = 0,
    SET_PRIMARY: u1 = 0,
    VIDEOPARAMETERS: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    ENABLE_UNSAFE_MODES: u1 = 0,
    DISABLE_UNSAFE_MODES: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
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
    NORESET: u1 = 0,
    RESET_EX: u1 = 0,
    RESET: u1 = 0,
    _31: u1 = 0,
};

pub const GET_DEVICE_CAPS_INDEX = enum(u32) {
    DRIVERVERSION = 0,
    TECHNOLOGY = 2,
    HORZSIZE = 4,
    VERTSIZE = 6,
    HORZRES = 8,
    VERTRES = 10,
    BITSPIXEL = 12,
    PLANES = 14,
    NUMBRUSHES = 16,
    NUMPENS = 18,
    NUMMARKERS = 20,
    NUMFONTS = 22,
    NUMCOLORS = 24,
    PDEVICESIZE = 26,
    CURVECAPS = 28,
    LINECAPS = 30,
    POLYGONALCAPS = 32,
    TEXTCAPS = 34,
    CLIPCAPS = 36,
    RASTERCAPS = 38,
    ASPECTX = 40,
    ASPECTY = 42,
    ASPECTXY = 44,
    LOGPIXELSX = 88,
    LOGPIXELSY = 90,
    SIZEPALETTE = 104,
    NUMRESERVED = 106,
    COLORRES = 108,
    PHYSICALWIDTH = 110,
    PHYSICALHEIGHT = 111,
    PHYSICALOFFSETX = 112,
    PHYSICALOFFSETY = 113,
    SCALINGFACTORX = 114,
    SCALINGFACTORY = 115,
    VREFRESH = 116,
    DESKTOPVERTRES = 117,
    DESKTOPHORZRES = 118,
    BLTALIGNMENT = 119,
    SHADEBLENDCAPS = 120,
    COLORMGMTCAPS = 121,
};

pub const DISPLAY_DEVICEW = extern struct {
    cb: u32,
    DeviceName: [32]u16,
    DeviceString: [128]u16,
    StateFlags: u32,
    DeviceID: [128]u16,
    DeviceKey: [128]u16,
};

pub const MONITORENUMPROC = *const fn (
    param0: ?HMONITOR,
    param1: ?HDC,
    param2: ?*win32.RECT,
    param3: win32.LPARAM,
) callconv(win32.WINAPI) win32.BOOL;

pub const GDI_IMAGE_TYPE = enum(u32) {
    BITMAP = 0,
    CURSOR = 2,
    ICON = 1,
};
pub const IMAGE_BITMAP = GDI_IMAGE_TYPE.BITMAP;
pub const IMAGE_CURSOR = GDI_IMAGE_TYPE.CURSOR;
pub const IMAGE_ICON = GDI_IMAGE_TYPE.ICON;

pub const IMAGE_FLAGS = packed struct(u32) {
    MONOCHROME: u1 = 0,
    _1: u1 = 0,
    COPYRETURNORG: u1 = 0,
    COPYDELETEORG: u1 = 0,
    LOADFROMFILE: u1 = 0,
    LOADTRANSPARENT: u1 = 0,
    DEFAULTSIZE: u1 = 0,
    VGACOLOR: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    LOADMAP3DCOLORS: u1 = 0,
    CREATEDIBSECTION: u1 = 0,
    COPYFROMRESOURCE: u1 = 0,
    SHARED: u1 = 0,
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
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};

//---------------------------
// Functions
//---------------------------

pub extern "user32" fn EnumDisplaySettingsExW(
    lpszDeviceName: ?[*:0]const u16,
    iModeNum: u32,
    lpDevMode: ?*DEVMODEW,
    dwFlags: u32,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn GetMonitorInfoW(
    hMonitor: ?HMONITOR,
    lpmi: ?*MONITORINFO,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn EnumDisplayMonitors(
    hdc: ?HDC,
    lprcClip: ?*win32.RECT,
    lpfnEnum: ?MONITORENUMPROC,
    dwData: win32.LPARAM,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn EnumDisplayDevicesW(
    lpDevice: ?[*:0]const u16,
    iDevNum: u32,
    lpDisplayDevice: ?*DISPLAY_DEVICEW,
    dwFlags: u32,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn EnumDisplaySettingsW(
    lpszDeviceName: ?[*:0]const u16,
    iModeNum: win32.DWORD,
    lpDevMode: ?*DEVMODEW,
) callconv(win32.WINAPI) win32.BOOL;

pub extern "user32" fn ChangeDisplaySettingsExW(
    lpszDeviceName: ?[*:0]const u16,
    lpDevMode: ?*DEVMODEW,
    hwnd: ?win32.HWND,
    dwflags: CDS_TYPE,
    lParam: ?*anyopaque,
) callconv(win32.WINAPI) DISP_CHANGE;

pub extern "user32" fn GetDC(
    hWnd: ?win32.HWND,
) callconv(win32.WINAPI) ?HDC;

pub extern "gdi32" fn GetDeviceCaps(
    hdc: ?HDC,
    index: GET_DEVICE_CAPS_INDEX,
) callconv(@import("std").os.windows.WINAPI) i32;

pub extern "user32" fn ReleaseDC(
    hWnd: ?win32.HWND,
    hDC: ?HDC,
) callconv(@import("std").os.windows.WINAPI) i32;

pub extern "user32" fn MonitorFromWindow(
    hwnd: ?win32.HWND,
    dwFlags: MONITOR_FROM_FLAGS,
) callconv(win32.WINAPI) ?HMONITOR;

pub extern "user32" fn LoadImageW(
    hInst: ?win32.HINSTANCE,
    name: ?win32.LPCWSTR,
    type: u32,
    cx: i32,
    cy: i32,
    fuLoad: u32,
) callconv(win32.WINAPI) ?win32.HANDLE;
