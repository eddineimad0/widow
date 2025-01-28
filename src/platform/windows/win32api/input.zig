const win32 = @import("std").os.windows;

//====================
// Types
//====================
pub const TRACKMOUSEEVENT = extern struct {
    cbSize: u32,
    dwFlags: TRACKMOUSEEVENT_FLAGS,
    hwndTrack: ?win32.HWND,
    dwHoverTime: u32,
};

pub const TRACKMOUSEEVENT_FLAGS = packed struct(u32) {
    HOVER: u1 = 0,
    LEAVE: u1 = 0,
    _2: u1 = 0,
    _3: u1 = 0,
    NONCLIENT: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
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
    _28: u1 = 0,
    _29: u1 = 0,
    QUERY: u1 = 0,
    CANCEL: u1 = 0,
};
pub const TME_CANCEL = TRACKMOUSEEVENT_FLAGS{ .CANCEL = 1 };
pub const TME_HOVER = TRACKMOUSEEVENT_FLAGS{ .HOVER = 1 };
pub const TME_LEAVE = TRACKMOUSEEVENT_FLAGS{ .LEAVE = 1 };
pub const TME_NONCLIENT = TRACKMOUSEEVENT_FLAGS{ .NONCLIENT = 1 };
pub const TME_QUERY = TRACKMOUSEEVENT_FLAGS{ .QUERY = 1 };
pub const HRAWINPUT = *opaque {};

pub const RAW_INPUT_DATA_COMMAND_FLAGS = enum(u32) {
    HEADER = 268435461,
    INPUT = 268435459,
};
pub const RID_HEADER = RAW_INPUT_DATA_COMMAND_FLAGS.HEADER;
pub const RID_INPUT = RAW_INPUT_DATA_COMMAND_FLAGS.INPUT;

pub const RAW_INPUT_DEVICE_INFO_COMMAND = enum(u32) {
    PREPARSEDDATA = 536870917,
    DEVICENAME = 536870919,
    DEVICEINFO = 536870923,
};
pub const RIDI_PREPARSEDDATA = RAW_INPUT_DEVICE_INFO_COMMAND.PREPARSEDDATA;
pub const RIDI_DEVICENAME = RAW_INPUT_DEVICE_INFO_COMMAND.DEVICENAME;
pub const RIDI_DEVICEINFO = RAW_INPUT_DEVICE_INFO_COMMAND.DEVICEINFO;

pub const RID_DEVICE_INFO_TYPE = enum(u32) {
    MOUSE = 0,
    KEYBOARD = 1,
    HID = 2,
};
pub const RIM_TYPEMOUSE = RID_DEVICE_INFO_TYPE.MOUSE;
pub const RIM_TYPEKEYBOARD = RID_DEVICE_INFO_TYPE.KEYBOARD;
pub const RIM_TYPEHID = RID_DEVICE_INFO_TYPE.HID;

pub const RAWINPUTDEVICE_FLAGS = packed struct(u32) {
    REMOVE: u1 = 0,
    _1: u1 = 0,
    _2: u1 = 0,
    _3: u1 = 0,
    EXCLUDE: u1 = 0,
    PAGEONLY: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    INPUTSINK: u1 = 0,
    CAPTUREMOUSE: u1 = 0,
    APPKEYS: u1 = 0,
    _11: u1 = 0,
    EXINPUTSINK: u1 = 0,
    DEVNOTIFY: u1 = 0,
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
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
    // NOHOTKEYS (bit index 9) conflicts with CAPTUREMOUSE
};
pub const RIDEV_REMOVE = RAWINPUTDEVICE_FLAGS{ .REMOVE = 1 };
pub const RIDEV_EXCLUDE = RAWINPUTDEVICE_FLAGS{ .EXCLUDE = 1 };
pub const RIDEV_PAGEONLY = RAWINPUTDEVICE_FLAGS{ .PAGEONLY = 1 };
pub const RIDEV_NOLEGACY = RAWINPUTDEVICE_FLAGS{
    .EXCLUDE = 1,
    .PAGEONLY = 1,
};
pub const RIDEV_INPUTSINK = RAWINPUTDEVICE_FLAGS{ .INPUTSINK = 1 };
pub const RIDEV_CAPTUREMOUSE = RAWINPUTDEVICE_FLAGS{ .CAPTUREMOUSE = 1 };
pub const RIDEV_NOHOTKEYS = RAWINPUTDEVICE_FLAGS{ .CAPTUREMOUSE = 1 };
pub const RIDEV_APPKEYS = RAWINPUTDEVICE_FLAGS{ .APPKEYS = 1 };
pub const RIDEV_EXINPUTSINK = RAWINPUTDEVICE_FLAGS{ .EXINPUTSINK = 1 };
pub const RIDEV_DEVNOTIFY = RAWINPUTDEVICE_FLAGS{ .DEVNOTIFY = 1 };

pub const RAWINPUTHEADER = extern struct {
    dwType: u32,
    dwSize: u32,
    hDevice: ?win32.HANDLE,
    wParam: win32.WPARAM,
};

pub const RAWMOUSE = extern struct {
    usFlags: u16,
    Anonymous: extern union {
        ulButtons: u32,
        Anonymous: extern struct {
            usButtonFlags: u16,
            usButtonData: u16,
        },
    },
    ulRawButtons: u32,
    lLastX: i32,
    lLastY: i32,
    ulExtraInformation: u32,
};

pub const RAWKEYBOARD = extern struct {
    MakeCode: u16,
    Flags: u16,
    Reserved: u16,
    VKey: u16,
    Message: u32,
    ExtraInformation: u32,
};

pub const RAWHID = extern struct {
    dwSizeHid: u32,
    dwCount: u32,
    bRawData: [1]u8,
};

pub const RAWINPUT = extern struct {
    header: RAWINPUTHEADER,
    data: extern union {
        mouse: RAWMOUSE,
        keyboard: RAWKEYBOARD,
        hid: RAWHID,
    },
};

//====================
// Functions
//====================
pub extern "user32" fn GetRawInputData(
    hRawInput: ?HRAWINPUT,
    uiCommand: RAW_INPUT_DATA_COMMAND_FLAGS,
    pData: ?*anyopaque,
    pcbSize: ?*u32,
    cbSizeHeader: u32,
) callconv(win32.WINAPI) u32;

pub extern "comctl32" fn _TrackMouseEvent(
    lpEventTrack: ?*TRACKMOUSEEVENT,
) callconv(win32.WINAPI) win32.BOOL;
