const windows = @import("std").os.windows;
const macros = @import("macros.zig");

// Constants.
pub const DPI_AWARENESS = enum(i32) {
    INVALID = -1,
    UNAWARE = 0,
    SYSTEM_AWARE = 1,
    PER_MONITOR_AWARE = 2,
};
pub const DPI_AWARENESS_INVALID = DPI_AWARENESS.INVALID;
pub const DPI_AWARENESS_UNAWARE = DPI_AWARENESS.UNAWARE;
pub const DPI_AWARENESS_SYSTEM_AWARE = DPI_AWARENESS.SYSTEM_AWARE;
pub const DPI_AWARENESS_PER_MONITOR_AWARE = DPI_AWARENESS.PER_MONITOR_AWARE;

pub const PROCESS_DPI_AWARENESS = enum(i32) {
    DPI_UNAWARE = 0,
    SYSTEM_DPI_AWARE = 1,
    PER_MONITOR_DPI_AWARE = 2,
};
pub const PROCESS_DPI_UNAWARE = PROCESS_DPI_AWARENESS.DPI_UNAWARE;
pub const PROCESS_SYSTEM_DPI_AWARE = PROCESS_DPI_AWARENESS.SYSTEM_DPI_AWARE;
pub const PROCESS_PER_MONITOR_DPI_AWARE = PROCESS_DPI_AWARENESS.PER_MONITOR_DPI_AWARE;

pub const DPI_AWARENESS_CONTEXT = isize;
pub const DPI_AWARENESS_CONTEXT_UNAWARE = @as(DPI_AWARENESS_CONTEXT, -1);
pub const DPI_AWARENESS_CONTEXT_SYSTEM_AWARE = @as(DPI_AWARENESS_CONTEXT, -2);
pub const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE = @as(DPI_AWARENESS_CONTEXT, -3);
pub const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = @as(DPI_AWARENESS_CONTEXT, -4);
pub const DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED = @as(DPI_AWARENESS_CONTEXT, -5);

pub const MONITOR_DPI_TYPE = enum(i32) {
    EFFECTIVE_DPI = 0,
    ANGULAR_DPI = 1,
    RAW_DPI = 2,
    // DEFAULT = 0, this enum value conflicts with EFFECTIVE_DPI
};
pub const MDT_EFFECTIVE_DPI = MONITOR_DPI_TYPE.EFFECTIVE_DPI;
pub const MDT_ANGULAR_DPI = MONITOR_DPI_TYPE.ANGULAR_DPI;
pub const MDT_RAW_DPI = MONITOR_DPI_TYPE.RAW_DPI;
pub const MDT_DEFAULT = MONITOR_DPI_TYPE.EFFECTIVE_DPI;

pub const DEVICE_NOTIFY_WINDOW_HANDLE = @as(u32, 0);

pub const USER_DEFAULT_SCREEN_DPI = @as(u32, 96);
pub const USER_DEFAULT_SCREEN_DPI_F = @as(f64, 96.0);
pub const WHEEL_DELTA = 120;
pub const CF_UNICODETEXT = @as(u32, 0x0D);
pub const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = @as(u32, 0x02);
pub const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = @as(u32, 0x04);

pub const VER_GREATER_EQUAL = @as(u32, 0x03);
pub const CW_USEDEFAULT = @as(i32, -2147483648);

pub const SC_SCREENSAVE = @as(u32, 0x0F140);
pub const SC_MONITORPOWER = @as(u32, 0x0F170);
pub const SC_KEYMENU = @as(u32, 0x0F100);
pub const WM_COPYGLOBALDATA = @as(u32, 0x0049);
pub const XINPUT_GAMEPAD_GUIDE = @as(u32, 0x0400);
pub const WAIT_TIMEOUT = @as(u32, 0x102);

pub const WM_MOUSELEAVE = @as(u32, 0x02A3);
pub const WM_UNICHAR = @as(u32, 0x0109);
pub const DIDFT_OPTIONAL = @as(u32, 0x80000000);
pub const ENUM_CURRENT_SETTINGS = @as(u32, 0xFFFFFFFF);
pub const ENUM_REGISTRY_SETTINGS = @as(u32, 0xFFFFFFFE);

pub const IDI_APPLICATION = macros.MAKEINTATOM(32512);

// IDC_Standard Cursors.
pub const IDC_ARROW = macros.MAKEINTRESOURCESW(32512); // Normal select.
pub const IDC_IBEAM = macros.MAKEINTRESOURCESW(32513); // Text select.
pub const IDC_WAIT = macros.MAKEINTRESOURCESW(32514); // Busy.
pub const IDC_CROSS = macros.MAKEINTRESOURCESW(32515); // Precision select.
pub const IDC_SIZEALL = macros.MAKEINTRESOURCESW(32646); // Move.
pub const IDC_NO = macros.MAKEINTRESOURCESW(32648); // Unavailable.
pub const IDC_HAND = macros.MAKEINTRESOURCESW(32649); // Link select.
pub const IDC_APPSTARTING = macros.MAKEINTRESOURCESW(32650); // Working in background.
pub const IDC_HELP = macros.MAKEINTRESOURCESW(32651); // Help select.

// OCR_Standard Cursors.
pub const OCR_NORMAL = @as(u16, 32512);
pub const OCR_IBEAM = @as(u16, 32513);
pub const OCR_WAIT = @as(u16, 32514);
pub const OCR_CROSS = @as(u16, 32515);
pub const OCR_UP = @as(u16, 32516);
pub const OCR_SIZENWSE = @as(u16, 32642);
pub const OCR_SIZENESW = @as(u16, 32643);
pub const OCR_SIZEWE = @as(u16, 32644);
pub const OCR_SIZENS = @as(u16, 32645);
pub const OCR_SIZEALL = @as(u16, 32646);
pub const OCR_NO = @as(u16, 32648);
