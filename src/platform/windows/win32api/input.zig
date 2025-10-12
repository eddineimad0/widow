//! This file holds bindings for working with input devices keyboard, mouse ...etc
const win32 = @import("std").os.windows;

//====================
// Constants
//===================
pub const VIRTUAL_KEY = u16;
pub const VK_0 = @as(VIRTUAL_KEY, 48);
pub const VK_1 = @as(VIRTUAL_KEY, 49);
pub const VK_2 = @as(VIRTUAL_KEY, 50);
pub const VK_3 = @as(VIRTUAL_KEY, 51);
pub const VK_4 = @as(VIRTUAL_KEY, 52);
pub const VK_5 = @as(VIRTUAL_KEY, 53);
pub const VK_6 = @as(VIRTUAL_KEY, 54);
pub const VK_7 = @as(VIRTUAL_KEY, 55);
pub const VK_8 = @as(VIRTUAL_KEY, 56);
pub const VK_9 = @as(VIRTUAL_KEY, 57);
pub const VK_A = @as(VIRTUAL_KEY, 65);
pub const VK_B = @as(VIRTUAL_KEY, 66);
pub const VK_C = @as(VIRTUAL_KEY, 67);
pub const VK_D = @as(VIRTUAL_KEY, 68);
pub const VK_E = @as(VIRTUAL_KEY, 69);
pub const VK_F = @as(VIRTUAL_KEY, 70);
pub const VK_G = @as(VIRTUAL_KEY, 71);
pub const VK_H = @as(VIRTUAL_KEY, 72);
pub const VK_I = @as(VIRTUAL_KEY, 73);
pub const VK_J = @as(VIRTUAL_KEY, 74);
pub const VK_K = @as(VIRTUAL_KEY, 75);
pub const VK_L = @as(VIRTUAL_KEY, 76);
pub const VK_M = @as(VIRTUAL_KEY, 77);
pub const VK_N = @as(VIRTUAL_KEY, 78);
pub const VK_O = @as(VIRTUAL_KEY, 79);
pub const VK_P = @as(VIRTUAL_KEY, 80);
pub const VK_Q = @as(VIRTUAL_KEY, 81);
pub const VK_R = @as(VIRTUAL_KEY, 82);
pub const VK_S = @as(VIRTUAL_KEY, 83);
pub const VK_T = @as(VIRTUAL_KEY, 84);
pub const VK_U = @as(VIRTUAL_KEY, 85);
pub const VK_V = @as(VIRTUAL_KEY, 86);
pub const VK_W = @as(VIRTUAL_KEY, 87);
pub const VK_X = @as(VIRTUAL_KEY, 88);
pub const VK_Y = @as(VIRTUAL_KEY, 89);
pub const VK_Z = @as(VIRTUAL_KEY, 90);
pub const VK_LBUTTON = @as(VIRTUAL_KEY, 1);
pub const VK_RBUTTON = @as(VIRTUAL_KEY, 2);
pub const VK_CANCEL = @as(VIRTUAL_KEY, 3);
pub const VK_MBUTTON = @as(VIRTUAL_KEY, 4);
pub const VK_XBUTTON1 = @as(VIRTUAL_KEY, 5);
pub const VK_XBUTTON2 = @as(VIRTUAL_KEY, 6);
pub const VK_BACK = @as(VIRTUAL_KEY, 8);
pub const VK_TAB = @as(VIRTUAL_KEY, 9);
pub const VK_CLEAR = @as(VIRTUAL_KEY, 12);
pub const VK_RETURN = @as(VIRTUAL_KEY, 13);
pub const VK_SHIFT = @as(VIRTUAL_KEY, 16);
pub const VK_CONTROL = @as(VIRTUAL_KEY, 17);
pub const VK_MENU = @as(VIRTUAL_KEY, 18);
pub const VK_PAUSE = @as(VIRTUAL_KEY, 19);
pub const VK_CAPITAL = @as(VIRTUAL_KEY, 20);
pub const VK_KANA = @as(VIRTUAL_KEY, 21);
pub const VK_IME_ON = @as(VIRTUAL_KEY, 22);
pub const VK_JUNJA = @as(VIRTUAL_KEY, 23);
pub const VK_FINAL = @as(VIRTUAL_KEY, 24);
pub const VK_HANJA = @as(VIRTUAL_KEY, 25);
pub const VK_IME_OFF = @as(VIRTUAL_KEY, 26);
pub const VK_ESCAPE = @as(VIRTUAL_KEY, 27);
pub const VK_CONVERT = @as(VIRTUAL_KEY, 28);
pub const VK_NONCONVERT = @as(VIRTUAL_KEY, 29);
pub const VK_ACCEPT = @as(VIRTUAL_KEY, 30);
pub const VK_MODECHANGE = @as(VIRTUAL_KEY, 31);
pub const VK_SPACE = @as(VIRTUAL_KEY, 32);
pub const VK_PRIOR = @as(VIRTUAL_KEY, 33);
pub const VK_NEXT = @as(VIRTUAL_KEY, 34);
pub const VK_END = @as(VIRTUAL_KEY, 35);
pub const VK_HOME = @as(VIRTUAL_KEY, 36);
pub const VK_LEFT = @as(VIRTUAL_KEY, 37);
pub const VK_UP = @as(VIRTUAL_KEY, 38);
pub const VK_RIGHT = @as(VIRTUAL_KEY, 39);
pub const VK_DOWN = @as(VIRTUAL_KEY, 40);
pub const VK_SELECT = @as(VIRTUAL_KEY, 41);
pub const VK_PRINT = @as(VIRTUAL_KEY, 42);
pub const VK_EXECUTE = @as(VIRTUAL_KEY, 43);
pub const VK_SNAPSHOT = @as(VIRTUAL_KEY, 44);
pub const VK_INSERT = @as(VIRTUAL_KEY, 45);
pub const VK_DELETE = @as(VIRTUAL_KEY, 46);
pub const VK_HELP = @as(VIRTUAL_KEY, 47);
pub const VK_LWIN = @as(VIRTUAL_KEY, 91);
pub const VK_RWIN = @as(VIRTUAL_KEY, 92);
pub const VK_APPS = @as(VIRTUAL_KEY, 93);
pub const VK_SLEEP = @as(VIRTUAL_KEY, 95);
pub const VK_NUMPAD0 = @as(VIRTUAL_KEY, 96);
pub const VK_NUMPAD1 = @as(VIRTUAL_KEY, 97);
pub const VK_NUMPAD2 = @as(VIRTUAL_KEY, 98);
pub const VK_NUMPAD3 = @as(VIRTUAL_KEY, 99);
pub const VK_NUMPAD4 = @as(VIRTUAL_KEY, 100);
pub const VK_NUMPAD5 = @as(VIRTUAL_KEY, 101);
pub const VK_NUMPAD6 = @as(VIRTUAL_KEY, 102);
pub const VK_NUMPAD7 = @as(VIRTUAL_KEY, 103);
pub const VK_NUMPAD8 = @as(VIRTUAL_KEY, 104);
pub const VK_NUMPAD9 = @as(VIRTUAL_KEY, 105);
pub const VK_MULTIPLY = @as(VIRTUAL_KEY, 106);
pub const VK_ADD = @as(VIRTUAL_KEY, 107);
pub const VK_SEPARATOR = @as(VIRTUAL_KEY, 108);
pub const VK_SUBTRACT = @as(VIRTUAL_KEY, 109);
pub const VK_DECIMAL = @as(VIRTUAL_KEY, 110);
pub const VK_DIVIDE = @as(VIRTUAL_KEY, 111);
pub const VK_F1 = @as(VIRTUAL_KEY, 112);
pub const VK_F2 = @as(VIRTUAL_KEY, 113);
pub const VK_F3 = @as(VIRTUAL_KEY, 114);
pub const VK_F4 = @as(VIRTUAL_KEY, 115);
pub const VK_F5 = @as(VIRTUAL_KEY, 116);
pub const VK_F6 = @as(VIRTUAL_KEY, 117);
pub const VK_F7 = @as(VIRTUAL_KEY, 118);
pub const VK_F8 = @as(VIRTUAL_KEY, 119);
pub const VK_F9 = @as(VIRTUAL_KEY, 120);
pub const VK_F10 = @as(VIRTUAL_KEY, 121);
pub const VK_F11 = @as(VIRTUAL_KEY, 122);
pub const VK_F12 = @as(VIRTUAL_KEY, 123);
pub const VK_F13 = @as(VIRTUAL_KEY, 124);
pub const VK_F14 = @as(VIRTUAL_KEY, 125);
pub const VK_F15 = @as(VIRTUAL_KEY, 126);
pub const VK_F16 = @as(VIRTUAL_KEY, 127);
pub const VK_F17 = @as(VIRTUAL_KEY, 128);
pub const VK_F18 = @as(VIRTUAL_KEY, 129);
pub const VK_F19 = @as(VIRTUAL_KEY, 130);
pub const VK_F20 = @as(VIRTUAL_KEY, 131);
pub const VK_F21 = @as(VIRTUAL_KEY, 132);
pub const VK_F22 = @as(VIRTUAL_KEY, 133);
pub const VK_F23 = @as(VIRTUAL_KEY, 134);
pub const VK_F24 = @as(VIRTUAL_KEY, 135);
pub const VK_NAVIGATION_VIEW = @as(VIRTUAL_KEY, 136);
pub const VK_NAVIGATION_MENU = @as(VIRTUAL_KEY, 137);
pub const VK_NAVIGATION_UP = @as(VIRTUAL_KEY, 138);
pub const VK_NAVIGATION_DOWN = @as(VIRTUAL_KEY, 139);
pub const VK_NAVIGATION_LEFT = @as(VIRTUAL_KEY, 140);
pub const VK_NAVIGATION_RIGHT = @as(VIRTUAL_KEY, 141);
pub const VK_NAVIGATION_ACCEPT = @as(VIRTUAL_KEY, 142);
pub const VK_NAVIGATION_CANCEL = @as(VIRTUAL_KEY, 143);
pub const VK_NUMLOCK = @as(VIRTUAL_KEY, 144);
pub const VK_SCROLL = @as(VIRTUAL_KEY, 145);
pub const VK_OEM_NEC_EQUAL = @as(VIRTUAL_KEY, 146);
pub const VK_OEM_FJ_MASSHOU = @as(VIRTUAL_KEY, 147);
pub const VK_OEM_FJ_TOUROKU = @as(VIRTUAL_KEY, 148);
pub const VK_OEM_FJ_LOYA = @as(VIRTUAL_KEY, 149);
pub const VK_OEM_FJ_ROYA = @as(VIRTUAL_KEY, 150);
pub const VK_LSHIFT = @as(VIRTUAL_KEY, 160);
pub const VK_RSHIFT = @as(VIRTUAL_KEY, 161);
pub const VK_LCONTROL = @as(VIRTUAL_KEY, 162);
pub const VK_RCONTROL = @as(VIRTUAL_KEY, 163);
pub const VK_LMENU = @as(VIRTUAL_KEY, 164);
pub const VK_RMENU = @as(VIRTUAL_KEY, 165);
pub const VK_BROWSER_BACK = @as(VIRTUAL_KEY, 166);
pub const VK_BROWSER_FORWARD = @as(VIRTUAL_KEY, 167);
pub const VK_BROWSER_REFRESH = @as(VIRTUAL_KEY, 168);
pub const VK_BROWSER_STOP = @as(VIRTUAL_KEY, 169);
pub const VK_BROWSER_SEARCH = @as(VIRTUAL_KEY, 170);
pub const VK_BROWSER_FAVORITES = @as(VIRTUAL_KEY, 171);
pub const VK_BROWSER_HOME = @as(VIRTUAL_KEY, 172);
pub const VK_VOLUME_MUTE = @as(VIRTUAL_KEY, 173);
pub const VK_VOLUME_DOWN = @as(VIRTUAL_KEY, 174);
pub const VK_VOLUME_UP = @as(VIRTUAL_KEY, 175);
pub const VK_MEDIA_NEXT_TRACK = @as(VIRTUAL_KEY, 176);
pub const VK_MEDIA_PREV_TRACK = @as(VIRTUAL_KEY, 177);
pub const VK_MEDIA_STOP = @as(VIRTUAL_KEY, 178);
pub const VK_MEDIA_PLAY_PAUSE = @as(VIRTUAL_KEY, 179);
pub const VK_LAUNCH_MAIL = @as(VIRTUAL_KEY, 180);
pub const VK_LAUNCH_MEDIA_SELECT = @as(VIRTUAL_KEY, 181);
pub const VK_LAUNCH_APP1 = @as(VIRTUAL_KEY, 182);
pub const VK_LAUNCH_APP2 = @as(VIRTUAL_KEY, 183);
pub const VK_OEM_1 = @as(VIRTUAL_KEY, 186);
pub const VK_OEM_PLUS = @as(VIRTUAL_KEY, 187);
pub const VK_OEM_COMMA = @as(VIRTUAL_KEY, 188);
pub const VK_OEM_MINUS = @as(VIRTUAL_KEY, 189);
pub const VK_OEM_PERIOD = @as(VIRTUAL_KEY, 190);
pub const VK_OEM_2 = @as(VIRTUAL_KEY, 191);
pub const VK_OEM_3 = @as(VIRTUAL_KEY, 192);
pub const VK_GAMEPAD_A = @as(VIRTUAL_KEY, 195);
pub const VK_GAMEPAD_B = @as(VIRTUAL_KEY, 196);
pub const VK_GAMEPAD_X = @as(VIRTUAL_KEY, 197);
pub const VK_GAMEPAD_Y = @as(VIRTUAL_KEY, 198);
pub const VK_GAMEPAD_RIGHT_SHOULDER = @as(VIRTUAL_KEY, 199);
pub const VK_GAMEPAD_LEFT_SHOULDER = @as(VIRTUAL_KEY, 200);
pub const VK_GAMEPAD_LEFT_TRIGGER = @as(VIRTUAL_KEY, 201);
pub const VK_GAMEPAD_RIGHT_TRIGGER = @as(VIRTUAL_KEY, 202);
pub const VK_GAMEPAD_DPAD_UP = @as(VIRTUAL_KEY, 203);
pub const VK_GAMEPAD_DPAD_DOWN = @as(VIRTUAL_KEY, 204);
pub const VK_GAMEPAD_DPAD_LEFT = @as(VIRTUAL_KEY, 205);
pub const VK_GAMEPAD_DPAD_RIGHT = @as(VIRTUAL_KEY, 206);
pub const VK_GAMEPAD_MENU = @as(VIRTUAL_KEY, 207);
pub const VK_GAMEPAD_VIEW = @as(VIRTUAL_KEY, 208);
pub const VK_GAMEPAD_LEFT_THUMBSTICK_BUTTON = @as(VIRTUAL_KEY, 209);
pub const VK_GAMEPAD_RIGHT_THUMBSTICK_BUTTON = @as(VIRTUAL_KEY, 210);
pub const VK_GAMEPAD_LEFT_THUMBSTICK_UP = @as(VIRTUAL_KEY, 211);
pub const VK_GAMEPAD_LEFT_THUMBSTICK_DOWN = @as(VIRTUAL_KEY, 212);
pub const VK_GAMEPAD_LEFT_THUMBSTICK_RIGHT = @as(VIRTUAL_KEY, 213);
pub const VK_GAMEPAD_LEFT_THUMBSTICK_LEFT = @as(VIRTUAL_KEY, 214);
pub const VK_GAMEPAD_RIGHT_THUMBSTICK_UP = @as(VIRTUAL_KEY, 215);
pub const VK_GAMEPAD_RIGHT_THUMBSTICK_DOWN = @as(VIRTUAL_KEY, 216);
pub const VK_GAMEPAD_RIGHT_THUMBSTICK_RIGHT = @as(VIRTUAL_KEY, 217);
pub const VK_GAMEPAD_RIGHT_THUMBSTICK_LEFT = @as(VIRTUAL_KEY, 218);
pub const VK_OEM_4 = @as(VIRTUAL_KEY, 219);
pub const VK_OEM_5 = @as(VIRTUAL_KEY, 220);
pub const VK_OEM_6 = @as(VIRTUAL_KEY, 221);
pub const VK_OEM_7 = @as(VIRTUAL_KEY, 222);
pub const VK_OEM_8 = @as(VIRTUAL_KEY, 223);
pub const VK_OEM_AX = @as(VIRTUAL_KEY, 225);
pub const VK_OEM_102 = @as(VIRTUAL_KEY, 226);
pub const VK_ICO_HELP = @as(VIRTUAL_KEY, 227);
pub const VK_ICO_00 = @as(VIRTUAL_KEY, 228);
pub const VK_PROCESSKEY = @as(VIRTUAL_KEY, 229);
pub const VK_ICO_CLEAR = @as(VIRTUAL_KEY, 230);
pub const VK_PACKET = @as(VIRTUAL_KEY, 231);
pub const VK_OEM_RESET = @as(VIRTUAL_KEY, 233);
pub const VK_OEM_JUMP = @as(VIRTUAL_KEY, 234);
pub const VK_OEM_PA1 = @as(VIRTUAL_KEY, 235);
pub const VK_OEM_PA2 = @as(VIRTUAL_KEY, 236);
pub const VK_OEM_PA3 = @as(VIRTUAL_KEY, 237);
pub const VK_OEM_WSCTRL = @as(VIRTUAL_KEY, 238);
pub const VK_OEM_CUSEL = @as(VIRTUAL_KEY, 239);
pub const VK_OEM_ATTN = @as(VIRTUAL_KEY, 240);
pub const VK_OEM_FINISH = @as(VIRTUAL_KEY, 241);
pub const VK_OEM_COPY = @as(VIRTUAL_KEY, 242);
pub const VK_OEM_AUTO = @as(VIRTUAL_KEY, 243);
pub const VK_OEM_ENLW = @as(VIRTUAL_KEY, 244);
pub const VK_OEM_BACKTAB = @as(VIRTUAL_KEY, 245);
pub const VK_ATTN = @as(VIRTUAL_KEY, 246);
pub const VK_CRSEL = @as(VIRTUAL_KEY, 247);
pub const VK_EXSEL = @as(VIRTUAL_KEY, 248);
pub const VK_EREOF = @as(VIRTUAL_KEY, 249);
pub const VK_PLAY = @as(VIRTUAL_KEY, 250);
pub const VK_ZOOM = @as(VIRTUAL_KEY, 251);
pub const VK_NONAME = @as(VIRTUAL_KEY, 252);
pub const VK_PA1 = @as(VIRTUAL_KEY, 253);
pub const VK_OEM_CLEAR = @as(VIRTUAL_KEY, 254);
pub const KF_UP = @as(u32, 32768);

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

pub const RAWINPUTDEVICE = extern struct {
    usUsagePage: u16,
    usUsage: u16,
    dwFlags: RAWINPUTDEVICE_FLAGS,
    hwndTarget: ?win32.HWND,
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
) callconv(.winapi) u32;

pub extern "comctl32" fn TrackMouseEvent(
    lpEventTrack: ?*TRACKMOUSEEVENT,
) callconv(.winapi) win32.BOOL;

pub extern "user32" fn SetCapture(
    hWnd: ?win32.HWND,
) callconv(.winapi) ?win32.HWND;

pub extern "user32" fn ReleaseCapture() callconv(.winapi) win32.BOOL;

pub extern "user32" fn RegisterRawInputDevices(
    pRawInputDevices: [*]RAWINPUTDEVICE,
    uiNumDevices: u32,
    cbSize: u32,
) callconv(.winapi) win32.BOOL;

pub extern "user32" fn SetFocus(
    hWnd: ?win32.HWND,
) callconv(.winapi) ?win32.HWND;

pub extern "user32" fn MapVirtualKeyW(
    uCode: win32.UINT,
    uMapType: win32.UINT,
) callconv(.winapi) win32.UINT;

pub extern "user32" fn GetKeyState(
    nVirtKey: win32.INT,
) callconv(.winapi) win32.SHORT;
