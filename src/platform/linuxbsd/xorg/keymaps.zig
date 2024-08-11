const std = @import("std");
const common = @import("common");
const utils = @import("utils.zig");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const X11Driver = @import("driver.zig").X11Driver;
const ScanCode = common.keyboard_mouse.ScanCode;
const KeyCode = common.keyboard_mouse.KeyCode;

const SymHashMap = std.AutoArrayHashMap(u32, u32);
const KEYCODE_MAP_SIZE = 256;
const UNICODE_MAP_SIZE = 0x400;

const NameCodePair = std.meta.Tuple(&.{ KeyCode, [*:0]const u8 });

const KEYNAME_TO_KEYCODE_MAP = [_]NameCodePair{
    .{ KeyCode.Grave, "TLDE" },
    .{ KeyCode.Num1, "AE01" },
    .{ KeyCode.Num2, "AE02" },
    .{ KeyCode.Num3, "AE03" },
    .{ KeyCode.Num4, "AE04" },
    .{ KeyCode.Num5, "AE05" },
    .{ KeyCode.Num6, "AE06" },
    .{ KeyCode.Num7, "AE07" },
    .{ KeyCode.Num8, "AE08" },
    .{ KeyCode.Num9, "AE09" },
    .{ KeyCode.Num0, "AE10" },
    .{ KeyCode.Hyphen, "AE11" },
    .{ KeyCode.Equal, "AE12" },
    .{ KeyCode.Q, "AD01" },
    .{ KeyCode.W, "AD02" },
    .{ KeyCode.E, "AD03" },
    .{ KeyCode.R, "AD04" },
    .{ KeyCode.T, "AD05" },
    .{ KeyCode.Y, "AD06" },
    .{ KeyCode.U, "AD07" },
    .{ KeyCode.I, "AD08" },
    .{ KeyCode.O, "AD09" },
    .{ KeyCode.P, "AD10" },
    .{ KeyCode.LBracket, "AD11" },
    .{ KeyCode.RBracket, "AD12" },
    .{ KeyCode.A, "AC01" },
    .{ KeyCode.S, "AC02" },
    .{ KeyCode.D, "AC03" },
    .{ KeyCode.F, "AC04" },
    .{ KeyCode.G, "AC05" },
    .{ KeyCode.H, "AC06" },
    .{ KeyCode.J, "AC07" },
    .{ KeyCode.K, "AC08" },
    .{ KeyCode.L, "AC09" },
    .{ KeyCode.Semicolon, "AC10" },
    .{ KeyCode.Quote, "AC11" },
    .{ KeyCode.Z, "AB01" },
    .{ KeyCode.X, "AB02" },
    .{ KeyCode.C, "AB03" },
    .{ KeyCode.V, "AB04" },
    .{ KeyCode.B, "AB05" },
    .{ KeyCode.N, "AB06" },
    .{ KeyCode.M, "AB07" },
    .{ KeyCode.Comma, "AB08" },
    .{ KeyCode.Period, "AB09" },
    .{ KeyCode.Slash, "AB10" },
    .{ KeyCode.Backslash, "BKSL" },
    .{ KeyCode.Space, "SPCE" },
    .{ KeyCode.Escape, "ESC" },
    .{ KeyCode.Return, "RTRN" },
    .{ KeyCode.Tab, "TAB" },
    .{ KeyCode.Backspace, "BKSP" },
    .{ KeyCode.Insert, "INS" },
    .{ KeyCode.Delete, "DELE" },
    .{ KeyCode.Right, "RGHT" },
    .{ KeyCode.Left, "LEFT" },
    .{ KeyCode.Down, "DOWN" },
    .{ KeyCode.Up, @as([*:0]const u8, @ptrCast(&[4]u8{ 'U', 'P', 0x00, 0x00 })) },
    .{ KeyCode.PageUp, "PGUP" },
    .{ KeyCode.PageDown, "PGDN" },
    .{ KeyCode.Home, "HOME" },
    .{ KeyCode.End, "END" },
    .{ KeyCode.CapsLock, "CAPS" },
    .{ KeyCode.ScrollLock, "SCLK" },
    .{ KeyCode.NumLock, "NMLK" },
    .{ KeyCode.PrintScreen, "PRSC" },
    .{ KeyCode.Pause, "PAUS" },
    .{ KeyCode.F1, "FK01" },
    .{ KeyCode.F2, "FK02" },
    .{ KeyCode.F3, "FK03" },
    .{ KeyCode.F4, "FK04" },
    .{ KeyCode.F5, "FK05" },
    .{ KeyCode.F6, "FK06" },
    .{ KeyCode.F7, "FK07" },
    .{ KeyCode.F8, "FK08" },
    .{ KeyCode.F9, "FK09" },
    .{ KeyCode.F10, "FK10" },
    .{ KeyCode.F11, "FK11" },
    .{ KeyCode.F12, "FK12" },
    .{ KeyCode.Numpad0, "KP0" },
    .{ KeyCode.Numpad1, "KP1" },
    .{ KeyCode.Numpad2, "KP2" },
    .{ KeyCode.Numpad3, "KP3" },
    .{ KeyCode.Numpad4, "KP4" },
    .{ KeyCode.Numpad5, "KP5" },
    .{ KeyCode.Numpad6, "KP6" },
    .{ KeyCode.Numpad7, "KP7" },
    .{ KeyCode.Numpad8, "KP8" },
    .{ KeyCode.Numpad9, "KP9" },
    .{ KeyCode.Period, "KPDL" },
    .{ KeyCode.Divide, "KPDV" },
    .{ KeyCode.Multiply, "KPMU" },
    .{ KeyCode.Subtract, "KPSU" },
    .{ KeyCode.Add, "KPAD" },
    .{ KeyCode.Return, "KPEN" },
    .{ KeyCode.Equal, "KPEQ" },
    .{ KeyCode.Shift, "LFSH" },
    .{ KeyCode.Control, "LCTL" },
    .{ KeyCode.Meta, "LWIN" },
    .{ KeyCode.Shift, "RTSH" },
    .{ KeyCode.Control, "RCTL" },
    .{ KeyCode.Alt, "LVL3" },
    .{ KeyCode.Alt, "RALT" },
    .{ KeyCode.Alt, "MDSW" },
    .{ KeyCode.Alt, "LALT" },
    .{ KeyCode.Alt, "ALT" },
    .{ KeyCode.Meta, "RWIN" },
    .{ KeyCode.Menu, "MENU" },
    .{ KeyCode.VolumeUp, "VOL+" },
    .{ KeyCode.VolumeDown, "VOL-" },
    .{ KeyCode.VolumeMute, "MUTE" },
    // .{ KeyCode.NextTrack, "" },
    // .{ KeyCode.PrevTrack, "" },
    // .{ KeyCode.PlayPause, "" },
};

const SCANCODE_LOOKUP_TABLE = [256]ScanCode{
    // the first 8 are never produced by the xserver.
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Escape,
    ScanCode.Num1,
    ScanCode.Num2,
    ScanCode.Num3,
    ScanCode.Num4,
    ScanCode.Num5,
    ScanCode.Num6,
    ScanCode.Num7,
    ScanCode.Num8,
    ScanCode.Num9,
    ScanCode.Num0,
    ScanCode.Hyphen,
    ScanCode.Equal,
    ScanCode.Backspace,
    ScanCode.Tab,
    ScanCode.Q,
    ScanCode.W,
    ScanCode.E,
    ScanCode.R,
    ScanCode.T,
    ScanCode.Y,
    ScanCode.U,
    ScanCode.I,
    ScanCode.O,
    ScanCode.P,
    ScanCode.LBracket,
    ScanCode.RBracket,
    ScanCode.Return,
    ScanCode.LControl,
    ScanCode.A,
    ScanCode.S,
    ScanCode.D,
    ScanCode.F,
    ScanCode.G,
    ScanCode.H,
    ScanCode.J,
    ScanCode.K,
    ScanCode.L,
    ScanCode.Semicolon,
    ScanCode.Quote,
    ScanCode.Grave,
    ScanCode.LShift,
    ScanCode.Backslash,
    ScanCode.Z,
    ScanCode.X,
    ScanCode.C,
    ScanCode.V,
    ScanCode.B,
    ScanCode.N,
    ScanCode.M,
    ScanCode.Comma,
    ScanCode.Period,
    ScanCode.Slash,
    ScanCode.RShift,
    ScanCode.NumpadMultiply,
    ScanCode.LAlt,
    ScanCode.Space,
    ScanCode.CapsLock,
    ScanCode.F1,
    ScanCode.F2,
    ScanCode.F3,
    ScanCode.F4,
    ScanCode.F5,
    ScanCode.F6,
    ScanCode.F7,
    ScanCode.F8,
    ScanCode.F9,
    ScanCode.F10,
    ScanCode.NumLock,
    ScanCode.ScrollLock,
    ScanCode.Numpad7,
    ScanCode.Numpad8,
    ScanCode.Numpad9,
    ScanCode.NumpadSubtract,
    ScanCode.Numpad4,
    ScanCode.Numpad5,
    ScanCode.Numpad6,
    ScanCode.NumpadAdd,
    ScanCode.Numpad1,
    ScanCode.Numpad2,
    ScanCode.Numpad3,
    ScanCode.Numpad0,
    ScanCode.NumpadDecimal,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Key102nd,
    ScanCode.F11,
    ScanCode.F12,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.NumpadReturn,
    ScanCode.RControl,
    ScanCode.NumpadDivide,
    ScanCode.PrintScreen,
    ScanCode.RAlt,
    ScanCode.Return, // LineFeed
    ScanCode.Home,
    ScanCode.Up,
    ScanCode.PageUp,
    ScanCode.Left,
    ScanCode.Right,
    ScanCode.End,
    ScanCode.Down,
    ScanCode.PageDown,
    ScanCode.Insert,
    ScanCode.Delete,
    ScanCode.Unknown, // Macro
    ScanCode.VolumeMute,
    ScanCode.VolumeDown,
    ScanCode.VolumeUp,
    ScanCode.Unknown, // Power
    ScanCode.NumpadEqual,
    ScanCode.Unknown,
    ScanCode.Pause,
    ScanCode.Unknown,
    ScanCode.NumpadDecimal,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Menu,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.NextTrack,
    ScanCode.PlayPause,
    ScanCode.PrevTrack,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown, // start F13 to F24
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown, // end of F13 to f24
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
    ScanCode.Unknown,
};

fn mapXKeySymToWidowKeyCode(keysym: libx11.KeySym) KeyCode {
    return switch (keysym) {
        libx11.XK_Escape => KeyCode.Escape,
        libx11.XK_Tab => KeyCode.Tab,
        libx11.XK_BackSpace => KeyCode.Backspace,
        libx11.XK_Return => KeyCode.Return,
        libx11.XK_Insert => KeyCode.Insert,
        libx11.XK_Delete => KeyCode.Delete,
        libx11.XK_Clear => KeyCode.Delete,
        libx11.XK_Pause => KeyCode.Pause,
        libx11.XK_Home => KeyCode.Home,
        libx11.XK_End => KeyCode.End,
        libx11.XK_Left => KeyCode.Left,
        libx11.XK_Up => KeyCode.Up,
        libx11.XK_Right => KeyCode.Right,
        libx11.XK_Down => KeyCode.Down,
        libx11.XK_Prior => KeyCode.PageUp,
        libx11.XK_Next => KeyCode.PageDown,
        libx11.XK_Shift_L => KeyCode.Shift,
        libx11.XK_Shift_R => KeyCode.Shift,
        libx11.XK_Shift_Lock => KeyCode.Shift,
        libx11.XK_Control_L => KeyCode.Control,
        libx11.XK_Control_R => KeyCode.Control,
        libx11.XK_Meta_L => KeyCode.Meta,
        libx11.XK_Meta_R => KeyCode.Meta,
        libx11.XK_Alt_L => KeyCode.Alt,
        libx11.XK_Alt_R => KeyCode.Alt,
        libx11.XK_Caps_Lock => KeyCode.CapsLock,
        libx11.XK_Num_Lock => KeyCode.NumLock,
        libx11.XK_Scroll_Lock => KeyCode.ScrollLock,
        libx11.XK_Super_L => KeyCode.Meta,
        libx11.XK_Super_R => KeyCode.Meta,
        libx11.XK_Menu => KeyCode.Menu,
        // libx11.XK_Help => KeyCode.HELP,
        libx11.XK_KP_Space => KeyCode.Space,
        libx11.XK_KP_Tab => KeyCode.Tab,
        libx11.XK_KP_Enter => KeyCode.Return,
        libx11.XK_KP_Equal => KeyCode.Equal,
        libx11.XK_KP_Separator => KeyCode.Comma,
        libx11.XK_KP_Decimal => KeyCode.Period,
        libx11.XK_KP_Multiply => KeyCode.Multiply,
        libx11.XK_KP_Divide => KeyCode.Divide,
        libx11.XK_KP_Subtract => KeyCode.Subtract,
        libx11.XK_KP_Add => KeyCode.Add,
        libx11.XK_KP_0 => KeyCode.Numpad0,
        libx11.XK_KP_1 => KeyCode.Numpad1,
        libx11.XK_KP_2 => KeyCode.Numpad2,
        libx11.XK_KP_3 => KeyCode.Numpad3,
        libx11.XK_KP_4 => KeyCode.Numpad4,
        libx11.XK_KP_5 => KeyCode.Numpad5,
        libx11.XK_KP_6 => KeyCode.Numpad6,
        libx11.XK_KP_7 => KeyCode.Numpad7,
        libx11.XK_KP_8 => KeyCode.Numpad8,
        libx11.XK_KP_9 => KeyCode.Numpad9,
        // Same keys but with numlock off.
        libx11.XK_KP_Insert => KeyCode.Insert,
        libx11.XK_KP_Delete => KeyCode.Delete,
        libx11.XK_KP_End => KeyCode.End,
        libx11.XK_KP_Down => KeyCode.Down,
        libx11.XK_KP_Page_Down => KeyCode.PageDown,
        libx11.XK_KP_Left => KeyCode.Left,
        libx11.XK_KP_Right => KeyCode.Right,
        libx11.XK_KP_Home => KeyCode.Home,
        libx11.XK_KP_Up => KeyCode.Up,
        libx11.XK_KP_Page_Up => KeyCode.PageUp,
        libx11.XK_F1 => KeyCode.F1,
        libx11.XK_F2 => KeyCode.F2,
        libx11.XK_F3 => KeyCode.F3,
        libx11.XK_F4 => KeyCode.F4,
        libx11.XK_F5 => KeyCode.F5,
        libx11.XK_F6 => KeyCode.F6,
        libx11.XK_F7 => KeyCode.F7,
        libx11.XK_F8 => KeyCode.F8,
        libx11.XK_F9 => KeyCode.F9,
        libx11.XK_F10 => KeyCode.F10,
        libx11.XK_F11 => KeyCode.F11,
        libx11.XK_F12 => KeyCode.F12,
        libx11.XF86XK_AudioLowerVolume => KeyCode.VolumeDown,
        libx11.XF86XK_AudioMute => KeyCode.VolumeMute,
        libx11.XF86XK_AudioRaiseVolume => KeyCode.VolumeUp,
        libx11.XF86XK_AudioPlay => KeyCode.PlayPause,
        libx11.XF86XK_AudioStop => KeyCode.PlayPause,
        libx11.XF86XK_AudioPrev => KeyCode.PrevTrack,
        libx11.XF86XK_AudioNext => KeyCode.NextTrack,
        libx11.XK_A => KeyCode.A,
        libx11.XK_B => KeyCode.B,
        libx11.XK_C => KeyCode.C,
        libx11.XK_D => KeyCode.D,
        libx11.XK_E => KeyCode.E,
        libx11.XK_F => KeyCode.F,
        libx11.XK_G => KeyCode.G,
        libx11.XK_H => KeyCode.H,
        libx11.XK_I => KeyCode.I,
        libx11.XK_J => KeyCode.J,
        libx11.XK_K => KeyCode.K,
        libx11.XK_L => KeyCode.L,
        libx11.XK_M => KeyCode.M,
        libx11.XK_N => KeyCode.N,
        libx11.XK_O => KeyCode.O,
        libx11.XK_P => KeyCode.P,
        libx11.XK_Q => KeyCode.Q,
        libx11.XK_R => KeyCode.R,
        libx11.XK_S => KeyCode.S,
        libx11.XK_T => KeyCode.T,
        libx11.XK_U => KeyCode.U,
        libx11.XK_V => KeyCode.V,
        libx11.XK_W => KeyCode.W,
        libx11.XK_X => KeyCode.X,
        libx11.XK_Y => KeyCode.Y,
        libx11.XK_Z => KeyCode.Z,
        libx11.XK_0 => KeyCode.Num0,
        libx11.XK_1 => KeyCode.Num1,
        libx11.XK_2 => KeyCode.Num2,
        libx11.XK_3 => KeyCode.Num3,
        libx11.XK_4 => KeyCode.Num4,
        libx11.XK_5 => KeyCode.Num5,
        libx11.XK_6 => KeyCode.Num6,
        libx11.XK_7 => KeyCode.Num7,
        libx11.XK_8 => KeyCode.Num8,
        libx11.XK_9 => KeyCode.Num9,
        libx11.XK_space => KeyCode.Space,
        libx11.XK_Print => KeyCode.PrintScreen,
        libx11.XK_minus => KeyCode.Hyphen,
        libx11.XK_equal => KeyCode.Equal,
        libx11.XK_braceleft => KeyCode.LBracket,
        libx11.XK_braceright => KeyCode.RBracket,
        libx11.XK_slash => KeyCode.Slash,
        libx11.XK_backslash => KeyCode.Backslash,
        libx11.XK_semicolon => KeyCode.Semicolon,
        libx11.XK_apostrophe => KeyCode.Quote,
        libx11.XK_comma => KeyCode.Comma,
        libx11.XK_period => KeyCode.Period,
        libx11.XK_grave => KeyCode.Grave,
        else => KeyCode.Unknown,
    };
}

fn mapXKeyNameToKeyCode(name: []const u8) KeyCode {
    for (KEYNAME_TO_KEYCODE_MAP) |pair| {
        if (utils.bytesNCmp(name.ptr, pair[1], 4)) {
            return pair[0];
        }
    }
    return KeyCode.Unknown;
}

pub fn initUnicodeKeysymMapping(xkeysym_unicode_mapping: *SymHashMap) void {
    xkeysym_unicode_mapping.ensureTotalCapacity(UNICODE_MAP_SIZE) catch unreachable;
    // "Taken from godot game enginge, thanks."
    // # Keysym to Unicode map, tables taken from FOX toolkit.
    // no need to worry about allocation errors, capacity has already been reserved.
    xkeysym_unicode_mapping.put(0x01A1, 0x0104) catch unreachable;
    xkeysym_unicode_mapping.put(0x01A2, 0x02D8) catch unreachable;
    xkeysym_unicode_mapping.put(0x01A3, 0x0141) catch unreachable;
    xkeysym_unicode_mapping.put(0x01A5, 0x013D) catch unreachable;
    xkeysym_unicode_mapping.put(0x01A6, 0x015A) catch unreachable;
    xkeysym_unicode_mapping.put(0x01A9, 0x0160) catch unreachable;
    xkeysym_unicode_mapping.put(0x01AA, 0x015E) catch unreachable;
    xkeysym_unicode_mapping.put(0x01AB, 0x0164) catch unreachable;
    xkeysym_unicode_mapping.put(0x01AC, 0x0179) catch unreachable;
    xkeysym_unicode_mapping.put(0x01AE, 0x017D) catch unreachable;
    xkeysym_unicode_mapping.put(0x01AF, 0x017B) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B1, 0x0105) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B2, 0x02DB) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B3, 0x0142) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B5, 0x013E) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B6, 0x015B) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B7, 0x02C7) catch unreachable;
    xkeysym_unicode_mapping.put(0x01B9, 0x0161) catch unreachable;
    xkeysym_unicode_mapping.put(0x01BA, 0x015F) catch unreachable;
    xkeysym_unicode_mapping.put(0x01BB, 0x0165) catch unreachable;
    xkeysym_unicode_mapping.put(0x01BC, 0x017A) catch unreachable;
    xkeysym_unicode_mapping.put(0x01BD, 0x02DD) catch unreachable;
    xkeysym_unicode_mapping.put(0x01BE, 0x017E) catch unreachable;
    xkeysym_unicode_mapping.put(0x01BF, 0x017C) catch unreachable;
    xkeysym_unicode_mapping.put(0x01C0, 0x0154) catch unreachable;
    xkeysym_unicode_mapping.put(0x01C3, 0x0102) catch unreachable;
    xkeysym_unicode_mapping.put(0x01C5, 0x0139) catch unreachable;
    xkeysym_unicode_mapping.put(0x01C6, 0x0106) catch unreachable;
    xkeysym_unicode_mapping.put(0x01C8, 0x010C) catch unreachable;
    xkeysym_unicode_mapping.put(0x01CA, 0x0118) catch unreachable;
    xkeysym_unicode_mapping.put(0x01CC, 0x011A) catch unreachable;
    xkeysym_unicode_mapping.put(0x01CF, 0x010E) catch unreachable;
    xkeysym_unicode_mapping.put(0x01D0, 0x0110) catch unreachable;
    xkeysym_unicode_mapping.put(0x01D1, 0x0143) catch unreachable;
    xkeysym_unicode_mapping.put(0x01D2, 0x0147) catch unreachable;
    xkeysym_unicode_mapping.put(0x01D5, 0x0150) catch unreachable;
    xkeysym_unicode_mapping.put(0x01D8, 0x0158) catch unreachable;
    xkeysym_unicode_mapping.put(0x01D9, 0x016E) catch unreachable;
    xkeysym_unicode_mapping.put(0x01DB, 0x0170) catch unreachable;
    xkeysym_unicode_mapping.put(0x01DE, 0x0162) catch unreachable;
    xkeysym_unicode_mapping.put(0x01E0, 0x0155) catch unreachable;
    xkeysym_unicode_mapping.put(0x01E3, 0x0103) catch unreachable;
    xkeysym_unicode_mapping.put(0x01E5, 0x013A) catch unreachable;
    xkeysym_unicode_mapping.put(0x01E6, 0x0107) catch unreachable;
    xkeysym_unicode_mapping.put(0x01E8, 0x010D) catch unreachable;
    xkeysym_unicode_mapping.put(0x01EA, 0x0119) catch unreachable;
    xkeysym_unicode_mapping.put(0x01EC, 0x011B) catch unreachable;
    xkeysym_unicode_mapping.put(0x01EF, 0x010F) catch unreachable;
    xkeysym_unicode_mapping.put(0x01F0, 0x0111) catch unreachable;
    xkeysym_unicode_mapping.put(0x01F1, 0x0144) catch unreachable;
    xkeysym_unicode_mapping.put(0x01F2, 0x0148) catch unreachable;
    xkeysym_unicode_mapping.put(0x01F5, 0x0151) catch unreachable;
    xkeysym_unicode_mapping.put(0x01F8, 0x0159) catch unreachable;
    xkeysym_unicode_mapping.put(0x01F9, 0x016F) catch unreachable;
    xkeysym_unicode_mapping.put(0x01FB, 0x0171) catch unreachable;
    xkeysym_unicode_mapping.put(0x01FE, 0x0163) catch unreachable;
    xkeysym_unicode_mapping.put(0x01FF, 0x02D9) catch unreachable;
    xkeysym_unicode_mapping.put(0x02A1, 0x0126) catch unreachable;
    xkeysym_unicode_mapping.put(0x02A6, 0x0124) catch unreachable;
    xkeysym_unicode_mapping.put(0x02A9, 0x0130) catch unreachable;
    xkeysym_unicode_mapping.put(0x02AB, 0x011E) catch unreachable;
    xkeysym_unicode_mapping.put(0x02AC, 0x0134) catch unreachable;
    xkeysym_unicode_mapping.put(0x02B1, 0x0127) catch unreachable;
    xkeysym_unicode_mapping.put(0x02B6, 0x0125) catch unreachable;
    xkeysym_unicode_mapping.put(0x02B9, 0x0131) catch unreachable;
    xkeysym_unicode_mapping.put(0x02BB, 0x011F) catch unreachable;
    xkeysym_unicode_mapping.put(0x02BC, 0x0135) catch unreachable;
    xkeysym_unicode_mapping.put(0x02C5, 0x010A) catch unreachable;
    xkeysym_unicode_mapping.put(0x02C6, 0x0108) catch unreachable;
    xkeysym_unicode_mapping.put(0x02D5, 0x0120) catch unreachable;
    xkeysym_unicode_mapping.put(0x02D8, 0x011C) catch unreachable;
    xkeysym_unicode_mapping.put(0x02DD, 0x016C) catch unreachable;
    xkeysym_unicode_mapping.put(0x02DE, 0x015C) catch unreachable;
    xkeysym_unicode_mapping.put(0x02E5, 0x010B) catch unreachable;
    xkeysym_unicode_mapping.put(0x02E6, 0x0109) catch unreachable;
    xkeysym_unicode_mapping.put(0x02F5, 0x0121) catch unreachable;
    xkeysym_unicode_mapping.put(0x02F8, 0x011D) catch unreachable;
    xkeysym_unicode_mapping.put(0x02FD, 0x016D) catch unreachable;
    xkeysym_unicode_mapping.put(0x02FE, 0x015D) catch unreachable;
    xkeysym_unicode_mapping.put(0x03A2, 0x0138) catch unreachable;
    xkeysym_unicode_mapping.put(0x03A3, 0x0156) catch unreachable;
    xkeysym_unicode_mapping.put(0x03A5, 0x0128) catch unreachable;
    xkeysym_unicode_mapping.put(0x03A6, 0x013B) catch unreachable;
    xkeysym_unicode_mapping.put(0x03AA, 0x0112) catch unreachable;
    xkeysym_unicode_mapping.put(0x03AB, 0x0122) catch unreachable;
    xkeysym_unicode_mapping.put(0x03AC, 0x0166) catch unreachable;
    xkeysym_unicode_mapping.put(0x03B3, 0x0157) catch unreachable;
    xkeysym_unicode_mapping.put(0x03B5, 0x0129) catch unreachable;
    xkeysym_unicode_mapping.put(0x03B6, 0x013C) catch unreachable;
    xkeysym_unicode_mapping.put(0x03BA, 0x0113) catch unreachable;
    xkeysym_unicode_mapping.put(0x03BB, 0x0123) catch unreachable;
    xkeysym_unicode_mapping.put(0x03BC, 0x0167) catch unreachable;
    xkeysym_unicode_mapping.put(0x03BD, 0x014A) catch unreachable;
    xkeysym_unicode_mapping.put(0x03BF, 0x014B) catch unreachable;
    xkeysym_unicode_mapping.put(0x03C0, 0x0100) catch unreachable;
    xkeysym_unicode_mapping.put(0x03C7, 0x012E) catch unreachable;
    xkeysym_unicode_mapping.put(0x03CC, 0x0116) catch unreachable;
    xkeysym_unicode_mapping.put(0x03CF, 0x012A) catch unreachable;
    xkeysym_unicode_mapping.put(0x03D1, 0x0145) catch unreachable;
    xkeysym_unicode_mapping.put(0x03D2, 0x014C) catch unreachable;
    xkeysym_unicode_mapping.put(0x03D3, 0x0136) catch unreachable;
    xkeysym_unicode_mapping.put(0x03D9, 0x0172) catch unreachable;
    xkeysym_unicode_mapping.put(0x03DD, 0x0168) catch unreachable;
    xkeysym_unicode_mapping.put(0x03DE, 0x016A) catch unreachable;
    xkeysym_unicode_mapping.put(0x03E0, 0x0101) catch unreachable;
    xkeysym_unicode_mapping.put(0x03E7, 0x012F) catch unreachable;
    xkeysym_unicode_mapping.put(0x03EC, 0x0117) catch unreachable;
    xkeysym_unicode_mapping.put(0x03EF, 0x012B) catch unreachable;
    xkeysym_unicode_mapping.put(0x03F1, 0x0146) catch unreachable;
    xkeysym_unicode_mapping.put(0x03F2, 0x014D) catch unreachable;
    xkeysym_unicode_mapping.put(0x03F3, 0x0137) catch unreachable;
    xkeysym_unicode_mapping.put(0x03F9, 0x0173) catch unreachable;
    xkeysym_unicode_mapping.put(0x03FD, 0x0169) catch unreachable;
    xkeysym_unicode_mapping.put(0x03FE, 0x016B) catch unreachable;
    xkeysym_unicode_mapping.put(0x047E, 0x203E) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A1, 0x3002) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A2, 0x300C) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A3, 0x300D) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A4, 0x3001) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A5, 0x30FB) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A6, 0x30F2) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A7, 0x30A1) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A8, 0x30A3) catch unreachable;
    xkeysym_unicode_mapping.put(0x04A9, 0x30A5) catch unreachable;
    xkeysym_unicode_mapping.put(0x04AA, 0x30A7) catch unreachable;
    xkeysym_unicode_mapping.put(0x04AB, 0x30A9) catch unreachable;
    xkeysym_unicode_mapping.put(0x04AC, 0x30E3) catch unreachable;
    xkeysym_unicode_mapping.put(0x04AD, 0x30E5) catch unreachable;
    xkeysym_unicode_mapping.put(0x04AE, 0x30E7) catch unreachable;
    xkeysym_unicode_mapping.put(0x04AF, 0x30C3) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B0, 0x30FC) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B1, 0x30A2) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B2, 0x30A4) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B3, 0x30A6) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B4, 0x30A8) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B5, 0x30AA) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B6, 0x30AB) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B7, 0x30AD) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B8, 0x30AF) catch unreachable;
    xkeysym_unicode_mapping.put(0x04B9, 0x30B1) catch unreachable;
    xkeysym_unicode_mapping.put(0x04BA, 0x30B3) catch unreachable;
    xkeysym_unicode_mapping.put(0x04BB, 0x30B5) catch unreachable;
    xkeysym_unicode_mapping.put(0x04BC, 0x30B7) catch unreachable;
    xkeysym_unicode_mapping.put(0x04BD, 0x30B9) catch unreachable;
    xkeysym_unicode_mapping.put(0x04BE, 0x30BB) catch unreachable;
    xkeysym_unicode_mapping.put(0x04BF, 0x30BD) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C0, 0x30BF) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C1, 0x30C1) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C2, 0x30C4) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C3, 0x30C6) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C4, 0x30C8) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C5, 0x30CA) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C6, 0x30CB) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C7, 0x30CC) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C8, 0x30CD) catch unreachable;
    xkeysym_unicode_mapping.put(0x04C9, 0x30CE) catch unreachable;
    xkeysym_unicode_mapping.put(0x04CA, 0x30CF) catch unreachable;
    xkeysym_unicode_mapping.put(0x04CB, 0x30D2) catch unreachable;
    xkeysym_unicode_mapping.put(0x04CC, 0x30D5) catch unreachable;
    xkeysym_unicode_mapping.put(0x04CD, 0x30D8) catch unreachable;
    xkeysym_unicode_mapping.put(0x04CE, 0x30DB) catch unreachable;
    xkeysym_unicode_mapping.put(0x04CF, 0x30DE) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D0, 0x30DF) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D1, 0x30E0) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D2, 0x30E1) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D3, 0x30E2) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D4, 0x30E4) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D5, 0x30E6) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D6, 0x30E8) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D7, 0x30E9) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D8, 0x30EA) catch unreachable;
    xkeysym_unicode_mapping.put(0x04D9, 0x30EB) catch unreachable;
    xkeysym_unicode_mapping.put(0x04DA, 0x30EC) catch unreachable;
    xkeysym_unicode_mapping.put(0x04DB, 0x30ED) catch unreachable;
    xkeysym_unicode_mapping.put(0x04DC, 0x30EF) catch unreachable;
    xkeysym_unicode_mapping.put(0x04DD, 0x30F3) catch unreachable;
    xkeysym_unicode_mapping.put(0x04DE, 0x309B) catch unreachable;
    xkeysym_unicode_mapping.put(0x04DF, 0x309C) catch unreachable;
    xkeysym_unicode_mapping.put(0x05AC, 0x060C) catch unreachable;
    xkeysym_unicode_mapping.put(0x05BB, 0x061B) catch unreachable;
    xkeysym_unicode_mapping.put(0x05BF, 0x061F) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C1, 0x0621) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C2, 0x0622) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C3, 0x0623) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C4, 0x0624) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C5, 0x0625) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C6, 0x0626) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C7, 0x0627) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C8, 0x0628) catch unreachable;
    xkeysym_unicode_mapping.put(0x05C9, 0x0629) catch unreachable;
    xkeysym_unicode_mapping.put(0x05CA, 0x062A) catch unreachable;
    xkeysym_unicode_mapping.put(0x05CB, 0x062B) catch unreachable;
    xkeysym_unicode_mapping.put(0x05CC, 0x062C) catch unreachable;
    xkeysym_unicode_mapping.put(0x05CD, 0x062D) catch unreachable;
    xkeysym_unicode_mapping.put(0x05CE, 0x062E) catch unreachable;
    xkeysym_unicode_mapping.put(0x05CF, 0x062F) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D0, 0x0630) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D1, 0x0631) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D2, 0x0632) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D3, 0x0633) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D4, 0x0634) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D5, 0x0635) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D6, 0x0636) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D7, 0x0637) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D8, 0x0638) catch unreachable;
    xkeysym_unicode_mapping.put(0x05D9, 0x0639) catch unreachable;
    xkeysym_unicode_mapping.put(0x05DA, 0x063A) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E0, 0x0640) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E1, 0x0641) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E2, 0x0642) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E3, 0x0643) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E4, 0x0644) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E5, 0x0645) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E6, 0x0646) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E7, 0x0647) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E8, 0x0648) catch unreachable;
    xkeysym_unicode_mapping.put(0x05E9, 0x0649) catch unreachable;
    xkeysym_unicode_mapping.put(0x05EA, 0x064A) catch unreachable;
    xkeysym_unicode_mapping.put(0x05EB, 0x064B) catch unreachable;
    xkeysym_unicode_mapping.put(0x05EC, 0x064C) catch unreachable;
    xkeysym_unicode_mapping.put(0x05ED, 0x064D) catch unreachable;
    xkeysym_unicode_mapping.put(0x05EE, 0x064E) catch unreachable;
    xkeysym_unicode_mapping.put(0x05EF, 0x064F) catch unreachable;
    xkeysym_unicode_mapping.put(0x05F0, 0x0650) catch unreachable;
    xkeysym_unicode_mapping.put(0x05F1, 0x0651) catch unreachable;
    xkeysym_unicode_mapping.put(0x05F2, 0x0652) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A1, 0x0452) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A2, 0x0453) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A3, 0x0451) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A4, 0x0454) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A5, 0x0455) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A6, 0x0456) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A7, 0x0457) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A8, 0x0458) catch unreachable;
    xkeysym_unicode_mapping.put(0x06A9, 0x0459) catch unreachable;
    xkeysym_unicode_mapping.put(0x06AA, 0x045A) catch unreachable;
    xkeysym_unicode_mapping.put(0x06AB, 0x045B) catch unreachable;
    xkeysym_unicode_mapping.put(0x06AC, 0x045C) catch unreachable;
    xkeysym_unicode_mapping.put(0x06AE, 0x045E) catch unreachable;
    xkeysym_unicode_mapping.put(0x06AF, 0x045F) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B0, 0x2116) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B1, 0x0402) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B2, 0x0403) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B3, 0x0401) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B4, 0x0404) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B5, 0x0405) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B6, 0x0406) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B7, 0x0407) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B8, 0x0408) catch unreachable;
    xkeysym_unicode_mapping.put(0x06B9, 0x0409) catch unreachable;
    xkeysym_unicode_mapping.put(0x06BA, 0x040A) catch unreachable;
    xkeysym_unicode_mapping.put(0x06BB, 0x040B) catch unreachable;
    xkeysym_unicode_mapping.put(0x06BC, 0x040C) catch unreachable;
    xkeysym_unicode_mapping.put(0x06BE, 0x040E) catch unreachable;
    xkeysym_unicode_mapping.put(0x06BF, 0x040F) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C0, 0x044E) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C1, 0x0430) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C2, 0x0431) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C3, 0x0446) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C4, 0x0434) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C5, 0x0435) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C6, 0x0444) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C7, 0x0433) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C8, 0x0445) catch unreachable;
    xkeysym_unicode_mapping.put(0x06C9, 0x0438) catch unreachable;
    xkeysym_unicode_mapping.put(0x06CA, 0x0439) catch unreachable;
    xkeysym_unicode_mapping.put(0x06CB, 0x043A) catch unreachable;
    xkeysym_unicode_mapping.put(0x06CC, 0x043B) catch unreachable;
    xkeysym_unicode_mapping.put(0x06CD, 0x043C) catch unreachable;
    xkeysym_unicode_mapping.put(0x06CE, 0x043D) catch unreachable;
    xkeysym_unicode_mapping.put(0x06CF, 0x043E) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D0, 0x043F) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D1, 0x044F) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D2, 0x0440) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D3, 0x0441) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D4, 0x0442) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D5, 0x0443) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D6, 0x0436) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D7, 0x0432) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D8, 0x044C) catch unreachable;
    xkeysym_unicode_mapping.put(0x06D9, 0x044B) catch unreachable;
    xkeysym_unicode_mapping.put(0x06DA, 0x0437) catch unreachable;
    xkeysym_unicode_mapping.put(0x06DB, 0x0448) catch unreachable;
    xkeysym_unicode_mapping.put(0x06DC, 0x044D) catch unreachable;
    xkeysym_unicode_mapping.put(0x06DD, 0x0449) catch unreachable;
    xkeysym_unicode_mapping.put(0x06DE, 0x0447) catch unreachable;
    xkeysym_unicode_mapping.put(0x06DF, 0x044A) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E0, 0x042E) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E1, 0x0410) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E2, 0x0411) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E3, 0x0426) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E4, 0x0414) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E5, 0x0415) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E6, 0x0424) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E7, 0x0413) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E8, 0x0425) catch unreachable;
    xkeysym_unicode_mapping.put(0x06E9, 0x0418) catch unreachable;
    xkeysym_unicode_mapping.put(0x06EA, 0x0419) catch unreachable;
    xkeysym_unicode_mapping.put(0x06EB, 0x041A) catch unreachable;
    xkeysym_unicode_mapping.put(0x06EC, 0x041B) catch unreachable;
    xkeysym_unicode_mapping.put(0x06ED, 0x041C) catch unreachable;
    xkeysym_unicode_mapping.put(0x06EE, 0x041D) catch unreachable;
    xkeysym_unicode_mapping.put(0x06EF, 0x041E) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F0, 0x041F) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F1, 0x042F) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F2, 0x0420) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F3, 0x0421) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F4, 0x0422) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F5, 0x0423) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F6, 0x0416) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F7, 0x0412) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F8, 0x042C) catch unreachable;
    xkeysym_unicode_mapping.put(0x06F9, 0x042B) catch unreachable;
    xkeysym_unicode_mapping.put(0x06FA, 0x0417) catch unreachable;
    xkeysym_unicode_mapping.put(0x06FB, 0x0428) catch unreachable;
    xkeysym_unicode_mapping.put(0x06FC, 0x042D) catch unreachable;
    xkeysym_unicode_mapping.put(0x06FD, 0x0429) catch unreachable;
    xkeysym_unicode_mapping.put(0x06FE, 0x0427) catch unreachable;
    xkeysym_unicode_mapping.put(0x06FF, 0x042A) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A1, 0x0386) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A2, 0x0388) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A3, 0x0389) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A4, 0x038A) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A5, 0x03AA) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A7, 0x038C) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A8, 0x038E) catch unreachable;
    xkeysym_unicode_mapping.put(0x07A9, 0x03AB) catch unreachable;
    xkeysym_unicode_mapping.put(0x07AB, 0x038F) catch unreachable;
    xkeysym_unicode_mapping.put(0x07AE, 0x0385) catch unreachable;
    xkeysym_unicode_mapping.put(0x07AF, 0x2015) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B1, 0x03AC) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B2, 0x03AD) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B3, 0x03AE) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B4, 0x03AF) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B5, 0x03CA) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B6, 0x0390) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B7, 0x03CC) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B8, 0x03CD) catch unreachable;
    xkeysym_unicode_mapping.put(0x07B9, 0x03CB) catch unreachable;
    xkeysym_unicode_mapping.put(0x07BA, 0x03B0) catch unreachable;
    xkeysym_unicode_mapping.put(0x07BB, 0x03CE) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C1, 0x0391) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C2, 0x0392) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C3, 0x0393) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C4, 0x0394) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C5, 0x0395) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C6, 0x0396) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C7, 0x0397) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C8, 0x0398) catch unreachable;
    xkeysym_unicode_mapping.put(0x07C9, 0x0399) catch unreachable;
    xkeysym_unicode_mapping.put(0x07CA, 0x039A) catch unreachable;
    xkeysym_unicode_mapping.put(0x07CB, 0x039B) catch unreachable;
    xkeysym_unicode_mapping.put(0x07CC, 0x039C) catch unreachable;
    xkeysym_unicode_mapping.put(0x07CD, 0x039D) catch unreachable;
    xkeysym_unicode_mapping.put(0x07CE, 0x039E) catch unreachable;
    xkeysym_unicode_mapping.put(0x07CF, 0x039F) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D0, 0x03A0) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D1, 0x03A1) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D2, 0x03A3) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D4, 0x03A4) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D5, 0x03A5) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D6, 0x03A6) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D7, 0x03A7) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D8, 0x03A8) catch unreachable;
    xkeysym_unicode_mapping.put(0x07D9, 0x03A9) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E1, 0x03B1) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E2, 0x03B2) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E3, 0x03B3) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E4, 0x03B4) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E5, 0x03B5) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E6, 0x03B6) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E7, 0x03B7) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E8, 0x03B8) catch unreachable;
    xkeysym_unicode_mapping.put(0x07E9, 0x03B9) catch unreachable;
    xkeysym_unicode_mapping.put(0x07EA, 0x03BA) catch unreachable;
    xkeysym_unicode_mapping.put(0x07EB, 0x03BB) catch unreachable;
    xkeysym_unicode_mapping.put(0x07EC, 0x03BC) catch unreachable;
    xkeysym_unicode_mapping.put(0x07ED, 0x03BD) catch unreachable;
    xkeysym_unicode_mapping.put(0x07EE, 0x03BE) catch unreachable;
    xkeysym_unicode_mapping.put(0x07EF, 0x03BF) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F0, 0x03C0) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F1, 0x03C1) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F2, 0x03C3) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F3, 0x03C2) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F4, 0x03C4) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F5, 0x03C5) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F6, 0x03C6) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F7, 0x03C7) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F8, 0x03C8) catch unreachable;
    xkeysym_unicode_mapping.put(0x07F9, 0x03C9) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A1, 0x23B7) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A2, 0x250C) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A3, 0x2500) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A4, 0x2320) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A5, 0x2321) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A6, 0x2502) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A7, 0x23A1) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A8, 0x23A3) catch unreachable;
    xkeysym_unicode_mapping.put(0x08A9, 0x23A4) catch unreachable;
    xkeysym_unicode_mapping.put(0x08AA, 0x23A6) catch unreachable;
    xkeysym_unicode_mapping.put(0x08AB, 0x239B) catch unreachable;
    xkeysym_unicode_mapping.put(0x08AC, 0x239D) catch unreachable;
    xkeysym_unicode_mapping.put(0x08AD, 0x239E) catch unreachable;
    xkeysym_unicode_mapping.put(0x08AE, 0x23A0) catch unreachable;
    xkeysym_unicode_mapping.put(0x08AF, 0x23A8) catch unreachable;
    xkeysym_unicode_mapping.put(0x08B0, 0x23AC) catch unreachable;
    xkeysym_unicode_mapping.put(0x08BC, 0x2264) catch unreachable;
    xkeysym_unicode_mapping.put(0x08BD, 0x2260) catch unreachable;
    xkeysym_unicode_mapping.put(0x08BE, 0x2265) catch unreachable;
    xkeysym_unicode_mapping.put(0x08BF, 0x222B) catch unreachable;
    xkeysym_unicode_mapping.put(0x08C0, 0x2234) catch unreachable;
    xkeysym_unicode_mapping.put(0x08C1, 0x221D) catch unreachable;
    xkeysym_unicode_mapping.put(0x08C2, 0x221E) catch unreachable;
    xkeysym_unicode_mapping.put(0x08C5, 0x2207) catch unreachable;
    xkeysym_unicode_mapping.put(0x08C8, 0x223C) catch unreachable;
    xkeysym_unicode_mapping.put(0x08C9, 0x2243) catch unreachable;
    xkeysym_unicode_mapping.put(0x08CD, 0x21D4) catch unreachable;
    xkeysym_unicode_mapping.put(0x08CE, 0x21D2) catch unreachable;
    xkeysym_unicode_mapping.put(0x08CF, 0x2261) catch unreachable;
    xkeysym_unicode_mapping.put(0x08D6, 0x221A) catch unreachable;
    xkeysym_unicode_mapping.put(0x08DA, 0x2282) catch unreachable;
    xkeysym_unicode_mapping.put(0x08DB, 0x2283) catch unreachable;
    xkeysym_unicode_mapping.put(0x08DC, 0x2229) catch unreachable;
    xkeysym_unicode_mapping.put(0x08DD, 0x222A) catch unreachable;
    xkeysym_unicode_mapping.put(0x08DE, 0x2227) catch unreachable;
    xkeysym_unicode_mapping.put(0x08DF, 0x2228) catch unreachable;
    xkeysym_unicode_mapping.put(0x08EF, 0x2202) catch unreachable;
    xkeysym_unicode_mapping.put(0x08F6, 0x0192) catch unreachable;
    xkeysym_unicode_mapping.put(0x08FB, 0x2190) catch unreachable;
    xkeysym_unicode_mapping.put(0x08FC, 0x2191) catch unreachable;
    xkeysym_unicode_mapping.put(0x08FD, 0x2192) catch unreachable;
    xkeysym_unicode_mapping.put(0x08FE, 0x2193) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E0, 0x25C6) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E1, 0x2592) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E2, 0x2409) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E3, 0x240C) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E4, 0x240D) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E5, 0x240A) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E8, 0x2424) catch unreachable;
    xkeysym_unicode_mapping.put(0x09E9, 0x240B) catch unreachable;
    xkeysym_unicode_mapping.put(0x09EA, 0x2518) catch unreachable;
    xkeysym_unicode_mapping.put(0x09EB, 0x2510) catch unreachable;
    xkeysym_unicode_mapping.put(0x09EC, 0x250C) catch unreachable;
    xkeysym_unicode_mapping.put(0x09ED, 0x2514) catch unreachable;
    xkeysym_unicode_mapping.put(0x09EE, 0x253C) catch unreachable;
    xkeysym_unicode_mapping.put(0x09EF, 0x23BA) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F0, 0x23BB) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F1, 0x2500) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F2, 0x23BC) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F3, 0x23BD) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F4, 0x251C) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F5, 0x2524) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F6, 0x2534) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F7, 0x252C) catch unreachable;
    xkeysym_unicode_mapping.put(0x09F8, 0x2502) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA1, 0x2003) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA2, 0x2002) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA3, 0x2004) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA4, 0x2005) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA5, 0x2007) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA6, 0x2008) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA7, 0x2009) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA8, 0x200A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AA9, 0x2014) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AAA, 0x2013) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AAE, 0x2026) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AAF, 0x2025) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB0, 0x2153) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB1, 0x2154) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB2, 0x2155) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB3, 0x2156) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB4, 0x2157) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB5, 0x2158) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB6, 0x2159) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB7, 0x215A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AB8, 0x2105) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ABB, 0x2012) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ABC, 0x2329) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ABE, 0x232A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AC3, 0x215B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AC4, 0x215C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AC5, 0x215D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AC6, 0x215E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AC9, 0x2122) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ACA, 0x2613) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ACC, 0x25C1) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ACD, 0x25B7) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ACE, 0x25CB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ACF, 0x25AF) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD0, 0x2018) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD1, 0x2019) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD2, 0x201C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD3, 0x201D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD4, 0x211E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD6, 0x2032) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD7, 0x2033) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AD9, 0x271D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ADB, 0x25AC) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ADC, 0x25C0) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ADD, 0x25B6) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ADE, 0x25CF) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ADF, 0x25AE) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE0, 0x25E6) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE1, 0x25AB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE2, 0x25AD) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE3, 0x25B3) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE4, 0x25BD) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE5, 0x2606) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE6, 0x2022) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE7, 0x25AA) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE8, 0x25B2) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AE9, 0x25BC) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AEA, 0x261C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AEB, 0x261E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AEC, 0x2663) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AED, 0x2666) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AEE, 0x2665) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF0, 0x2720) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF1, 0x2020) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF2, 0x2021) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF3, 0x2713) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF4, 0x2717) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF5, 0x266F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF6, 0x266D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF7, 0x2642) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF8, 0x2640) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AF9, 0x260E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AFA, 0x2315) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AFB, 0x2117) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AFC, 0x2038) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AFD, 0x201A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0AFE, 0x201E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BA3, 0x003C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BA6, 0x003E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BA8, 0x2228) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BA9, 0x2227) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BC0, 0x00AF) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BC2, 0x22A5) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BC3, 0x2229) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BC4, 0x230A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BC6, 0x005F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BCA, 0x2218) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BCC, 0x2395) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BCE, 0x22A4) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BCF, 0x25CB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BD3, 0x2308) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BD6, 0x222A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BD8, 0x2283) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BDA, 0x2282) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BDC, 0x22A2) catch unreachable;
    xkeysym_unicode_mapping.put(0x0BFC, 0x22A3) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CDF, 0x2017) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE0, 0x05D0) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE1, 0x05D1) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE2, 0x05D2) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE3, 0x05D3) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE4, 0x05D4) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE5, 0x05D5) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE6, 0x05D6) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE7, 0x05D7) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE8, 0x05D8) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CE9, 0x05D9) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CEA, 0x05DA) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CEB, 0x05DB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CEC, 0x05DC) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CED, 0x05DD) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CEE, 0x05DE) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CEF, 0x05DF) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF0, 0x05E0) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF1, 0x05E1) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF2, 0x05E2) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF3, 0x05E3) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF4, 0x05E4) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF5, 0x05E5) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF6, 0x05E6) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF7, 0x05E7) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF8, 0x05E8) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CF9, 0x05E9) catch unreachable;
    xkeysym_unicode_mapping.put(0x0CFA, 0x05EA) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA1, 0x0E01) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA2, 0x0E02) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA3, 0x0E03) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA4, 0x0E04) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA5, 0x0E05) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA6, 0x0E06) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA7, 0x0E07) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA8, 0x0E08) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DA9, 0x0E09) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DAA, 0x0E0A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DAB, 0x0E0B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DAC, 0x0E0C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DAD, 0x0E0D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DAE, 0x0E0E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DAF, 0x0E0F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB0, 0x0E10) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB1, 0x0E11) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB2, 0x0E12) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB3, 0x0E13) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB4, 0x0E14) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB5, 0x0E15) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB6, 0x0E16) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB7, 0x0E17) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB8, 0x0E18) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DB9, 0x0E19) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DBA, 0x0E1A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DBB, 0x0E1B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DBC, 0x0E1C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DBD, 0x0E1D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DBE, 0x0E1E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DBF, 0x0E1F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC0, 0x0E20) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC1, 0x0E21) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC2, 0x0E22) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC3, 0x0E23) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC4, 0x0E24) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC5, 0x0E25) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC6, 0x0E26) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC7, 0x0E27) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC8, 0x0E28) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DC9, 0x0E29) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DCA, 0x0E2A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DCB, 0x0E2B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DCC, 0x0E2C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DCD, 0x0E2D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DCE, 0x0E2E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DCF, 0x0E2F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD0, 0x0E30) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD1, 0x0E31) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD2, 0x0E32) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD3, 0x0E33) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD4, 0x0E34) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD5, 0x0E35) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD6, 0x0E36) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD7, 0x0E37) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD8, 0x0E38) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DD9, 0x0E39) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DDA, 0x0E3A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DDF, 0x0E3F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE0, 0x0E40) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE1, 0x0E41) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE2, 0x0E42) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE3, 0x0E43) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE4, 0x0E44) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE5, 0x0E45) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE6, 0x0E46) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE7, 0x0E47) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE8, 0x0E48) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DE9, 0x0E49) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DEA, 0x0E4A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DEB, 0x0E4B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DEC, 0x0E4C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DED, 0x0E4D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF0, 0x0E50) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF1, 0x0E51) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF2, 0x0E52) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF3, 0x0E53) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF4, 0x0E54) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF5, 0x0E55) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF6, 0x0E56) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF7, 0x0E57) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF8, 0x0E58) catch unreachable;
    xkeysym_unicode_mapping.put(0x0DF9, 0x0E59) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA1, 0x3131) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA2, 0x3132) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA3, 0x3133) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA4, 0x3134) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA5, 0x3135) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA6, 0x3136) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA7, 0x3137) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA8, 0x3138) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EA9, 0x3139) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EAA, 0x313A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EAB, 0x313B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EAC, 0x313C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EAD, 0x313D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EAE, 0x313E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EAF, 0x313F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB0, 0x3140) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB1, 0x3141) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB2, 0x3142) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB3, 0x3143) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB4, 0x3144) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB5, 0x3145) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB6, 0x3146) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB7, 0x3147) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB8, 0x3148) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EB9, 0x3149) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EBA, 0x314A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EBB, 0x314B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EBC, 0x314C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EBD, 0x314D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EBE, 0x314E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EBF, 0x314F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC0, 0x3150) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC1, 0x3151) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC2, 0x3152) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC3, 0x3153) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC4, 0x3154) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC5, 0x3155) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC6, 0x3156) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC7, 0x3157) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC8, 0x3158) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EC9, 0x3159) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ECA, 0x315A) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ECB, 0x315B) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ECC, 0x315C) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ECD, 0x315D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ECE, 0x315E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ECF, 0x315F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED0, 0x3160) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED1, 0x3161) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED2, 0x3162) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED3, 0x3163) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED4, 0x11A8) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED5, 0x11A9) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED6, 0x11AA) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED7, 0x11AB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED8, 0x11AC) catch unreachable;
    xkeysym_unicode_mapping.put(0x0ED9, 0x11AD) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EDA, 0x11AE) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EDB, 0x11AF) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EDC, 0x11B0) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EDD, 0x11B1) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EDE, 0x11B2) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EDF, 0x11B3) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE0, 0x11B4) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE1, 0x11B5) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE2, 0x11B6) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE3, 0x11B7) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE4, 0x11B8) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE5, 0x11B9) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE6, 0x11BA) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE7, 0x11BB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE8, 0x11BC) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EE9, 0x11BD) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EEA, 0x11BE) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EEB, 0x11BF) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EEC, 0x11C0) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EED, 0x11C1) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EEE, 0x11C2) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EEF, 0x316D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF0, 0x3171) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF1, 0x3178) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF2, 0x317F) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF3, 0x3181) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF4, 0x3184) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF5, 0x3186) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF6, 0x318D) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF7, 0x318E) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF8, 0x11EB) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EF9, 0x11F0) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EFA, 0x11F9) catch unreachable;
    xkeysym_unicode_mapping.put(0x0EFF, 0x20A9) catch unreachable;
    xkeysym_unicode_mapping.put(0x13A4, 0x20AC) catch unreachable;
    xkeysym_unicode_mapping.put(0x13BC, 0x0152) catch unreachable;
    xkeysym_unicode_mapping.put(0x13BD, 0x0153) catch unreachable;
    xkeysym_unicode_mapping.put(0x13BE, 0x0178) catch unreachable;
    xkeysym_unicode_mapping.put(0x20AC, 0x20AC) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE50, '`') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE51, 0x00B4) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE52, '^') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE53, '~') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE54, 0x00AF) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE55, 0x02D8) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE56, 0x02D9) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE57, 0x00A8) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE58, 0x02DA) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE59, 0x02DD) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE5A, 0x02C7) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE5B, 0x00B8) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE5C, 0x02DB) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE5D, 0x037A) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE5E, 0x309B) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE5F, 0x309C) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE63, '/') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE64, 0x02BC) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE65, 0x02BD) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE66, 0x02F5) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE67, 0x02F3) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE68, 0x02CD) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE69, 0xA788) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE6A, 0x02F7) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE6E, ',') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE6F, 0x00A4) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE80, 'a') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE81, 'A') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE82, 'e') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE83, 'E') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE84, 'i') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE85, 'I') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE86, 'o') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE87, 'O') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE88, 'u') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE89, 'U') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE8A, 0x0259) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE8B, 0x018F) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE8C, 0x00B5) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE90, '_') catch unreachable;
    xkeysym_unicode_mapping.put(0xFE91, 0x02C8) catch unreachable;
    xkeysym_unicode_mapping.put(0xFE92, 0x02CC) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF80, ' ') catch unreachable; // spac catch unreachablee
    xkeysym_unicode_mapping.put(0xFF95, 0x0037) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF96, 0x0034) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF97, 0x0038) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF98, 0x0036) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF99, 0x0032) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF9A, 0x0039) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF9B, 0x0033) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF9C, 0x0031) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF9D, 0x0035) catch unreachable;
    xkeysym_unicode_mapping.put(0xFF9E, 0x0030) catch unreachable;
    // xkeysym_unicode_mapping[0xFFAA] = '*' ;
    // xkeysym_unicode_mapping[0xFFAB] = '+' ;
    // xkeysym_unicode_mapping[0xFFAC] = ',' ;
    // xkeysym_unicode_mapping[0xFFAD] = '-' ;
    // xkeysym_unicode_mapping[0xFFAE] = '.' ;
    // xkeysym_unicode_mapping[0xFFAF] = '/' ;
    // xkeysym_unicode_mapping[0xFFB0] = 0x0030 ;
    // xkeysym_unicode_mapping[0xFFB1] = 0x0031 ;
    // xkeysym_unicode_mapping[0xFFB2] = 0x0032 ;
    // xkeysym_unicode_mapping[0xFFB3] = 0x0033 ;
    // xkeysym_unicode_mapping[0xFFB4] = 0x0034 ;
    // xkeysym_unicode_mapping[0xFFB5] = 0x0035 ;
    // xkeysym_unicode_mapping[0xFFB6] = 0x0036 ;
    // xkeysym_unicode_mapping[0xFFB7] = 0x0037 ;
    // xkeysym_unicode_mapping[0xFFB8] = 0x0038 ;
    // xkeysym_unicode_mapping[0xFFB9] = 0x0039 ;
    // xkeysym_unicode_mapping[0xFFBD] = '=';
}

/// Initialize the keysym to keycode map used when translating
/// key events to report keycodes.
fn initKeyCodeTable(keycode_lookup_table: []KeyCode) void {
    // insight taken from glfw.
    std.debug.assert(keycode_lookup_table.len >= KEYCODE_MAP_SIZE);

    @memset(keycode_lookup_table, KeyCode.Unknown);
    const x11driver = X11Driver.singleton();
    var min_scancode: c_int = 0;
    var max_scancode: c_int = 0;
    if (x11driver.extensions.xkb.is_available) {
        const kbd_desc = libx11.XkbGetMap(
            x11driver.handles.xdisplay,
            0,
            x11ext.XkbUseCoreKbd,
        );
        if (kbd_desc) |desc| {
            defer libx11.XkbFreeKeyboard(desc, 0, libx11.True);
            _ = libx11.XkbGetNames(
                x11driver.handles.xdisplay,
                x11ext.XkbKeyNamesMask | x11ext.XkbKeyAliasesMask,
                desc,
            );
            min_scancode = desc.min_key_code;
            max_scancode = desc.max_key_code;
            defer libx11.XkbFreeNames(
                desc,
                x11ext.XkbKeyNamesMask | x11ext.XkbKeyAliasesMask,
                libx11.True,
            );
            for (desc.min_key_code..(@as(u32, @intCast(desc.max_key_code)) + 1)) |i| {
                keycode_lookup_table[i] = mapXKeyNameToKeyCode(
                    &desc.names.?.keys.?[i].name,
                );
            }
        }
    } else {
        _ = libx11.XDisplayKeycodes(
            x11driver.handles.xdisplay,
            &min_scancode,
            &max_scancode,
        );
    }
    var keysym_size: c_int = 0;
    const keysym_array = libx11.XGetKeyboardMapping(
        x11driver.handles.xdisplay,
        @intCast(min_scancode),
        max_scancode - min_scancode + 1,
        &keysym_size,
    );
    const min: u32 = @intCast(min_scancode);
    const max: u32 = @intCast(max_scancode);
    const size: u32 = @intCast(keysym_size);
    if (keysym_array) |array| {
        defer _ = libx11.XFree(array);
        for (min..(max + 1)) |scancode| {
            if (keycode_lookup_table[scancode] != KeyCode.Unknown) {
                // don't modify what we already mapped.
                continue;
            }
            const offset = (scancode - min) * size;
            keycode_lookup_table[scancode] =
                mapXKeySymToWidowKeyCode(array[offset]);

            if (keycode_lookup_table[scancode] == KeyCode.Unknown and size > 1) {
                // try again.
                keycode_lookup_table[scancode] =
                    mapXKeySymToWidowKeyCode(array[offset + 1]);
            }
        }
    }
}

pub inline fn keycodeToScancode(code: u8) ScanCode {
    return SCANCODE_LOOKUP_TABLE[code];
}

pub const KeyMaps = struct {
    keycode_map: [KEYCODE_MAP_SIZE]KeyCode,
    unicode_map: SymHashMap,
    map_mem: [20 * UNICODE_MAP_SIZE]u8,
    alloc: std.heap.FixedBufferAllocator,

    const Self = @This();
    var sing_guard: std.Thread.Mutex = std.Thread.Mutex{};
    var sing_init: bool = false;
    var globl_instance: Self = .{
        .keycode_map = undefined,
        .map_mem = undefined,
        .alloc = undefined,
        .unicode_map = undefined,
    };

    pub fn initSingleton() void {
        @setCold(true);

        Self.sing_guard.lock();
        defer sing_guard.unlock();
        if (!Self.sing_init) {
            initKeyCodeTable(&globl_instance.keycode_map);
            globl_instance.alloc = std.heap.FixedBufferAllocator.init(&globl_instance.map_mem);
            globl_instance.unicode_map = SymHashMap.init(globl_instance.alloc.allocator());
            initUnicodeKeysymMapping(&globl_instance.unicode_map);
            Self.sing_init = true;
        }
    }

    pub fn deinitSingleton() void {
        @setCold(true);
        Self.sing_guard.lock();
        defer Self.sing_guard.unlock();
        if (Self.sing_init) {
            Self.sing_init = false;
            globl_instance.unicode_map.deinit();
        }
    }

    pub fn singleton() *const Self {
        std.debug.assert(Self.sing_init == true);
        return &Self.globl_instance;
    }

    pub inline fn lookupKeyCode(self: *const Self, xkeycode: u8) KeyCode {
        return self.keycode_map[xkeycode];
    }

    pub inline fn lookupKeyCharacter(self: *const Self, xkeysym: libx11.KeySym) ?u32 {
        // Latin-1
        if ((xkeysym <= 0xFF and xkeysym >= 0xA0) or (xkeysym >= 0x20 and xkeysym <= 0x7E)) {
            return @truncate(xkeysym);
        }

        // Latin-1 from Keypad.
        if (xkeysym == 0xFFBD or (xkeysym <= 0xFFB9 and xkeysym >= 0xFFAA)) {
            return @truncate(xkeysym - 0xFF80);
        }

        // Unicode (may be present).
        if ((xkeysym & 0xFF000000) == 0x01000000) {
            return @truncate(xkeysym & 0x00FFFFFF);
        }

        return self.unicode_map.get(@truncate(xkeysym));
    }
};
