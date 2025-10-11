const common = @import("common");
const win32_input = @import("win32api/input.zig");
const win32 = @import("std").os.windows;
const ScanCode = common.keyboard_mouse.ScanCode;
const KeyCode = common.keyboard_mouse.KeyCode;

const WIN32_VK_TO_SCANCODE = [512]ScanCode{
    ScanCode.Unknown, //0x000
    ScanCode.Escape, //0x001
    ScanCode.Num1, //0x002
    ScanCode.Num2, //0x003
    ScanCode.Num3, //0x004
    ScanCode.Num4, //0x005
    ScanCode.Num5, //0x006
    ScanCode.Num6, //0x007
    ScanCode.Num7, //0x008
    ScanCode.Num8, //0x009
    ScanCode.Num9, //0x00A
    ScanCode.Num0, //0x00B
    ScanCode.Hyphen, //0x00C
    ScanCode.Equal, //0x00D
    ScanCode.Backspace, //0x00E
    ScanCode.Tab, //0x00F
    ScanCode.Q, //0x010
    ScanCode.W, //0x011
    ScanCode.E, //0x012
    ScanCode.R, //0x013
    ScanCode.T, //0x014
    ScanCode.Y, //0x015
    ScanCode.U, //0x016
    ScanCode.I, //0x017
    ScanCode.O, //0x018
    ScanCode.P, //0x019
    ScanCode.LBracket, //0x01A
    ScanCode.RBracket, //0x01B
    ScanCode.Return, //0x01C
    ScanCode.LControl, //0x01D
    ScanCode.A, //0x01E
    ScanCode.S, //0x01F
    ScanCode.D, //0x020
    ScanCode.F, //0x021
    ScanCode.G, //0x022
    ScanCode.H, //0x023
    ScanCode.J, //0x024
    ScanCode.K, //0x025
    ScanCode.L, //0x026
    ScanCode.Semicolon, //0x027
    ScanCode.Quote, //0x028
    ScanCode.Grave, //0x029
    ScanCode.LShift, //0x02A
    ScanCode.Backslash, //0x02B
    ScanCode.Z, //0x02C
    ScanCode.X, //0x02D
    ScanCode.C, //0x02E
    ScanCode.V, //0x02F
    ScanCode.B, //0x030
    ScanCode.N, //0x031
    ScanCode.M, //0x032
    ScanCode.Comma, //0x033
    ScanCode.Period, //0x034
    ScanCode.Slash, //0x035
    ScanCode.RShift, //0x036
    ScanCode.NumpadMultiply, //0x037
    ScanCode.LAlt, //0x038
    ScanCode.Space, //0x039
    ScanCode.CapsLock, //0x03A
    ScanCode.F1, //0x03B
    ScanCode.F2, //0x03C
    ScanCode.F3, //0x03D
    ScanCode.F4, //0x03E
    ScanCode.F5, //0x03F
    ScanCode.F6, //0x040
    ScanCode.F7, //0x041
    ScanCode.F8, //0x042
    ScanCode.F9, //0x043
    ScanCode.F10, //0x044
    ScanCode.Pause, //0x045
    ScanCode.ScrollLock, //0x046
    ScanCode.Numpad7, //0x047
    ScanCode.Numpad8, //0x04r
    ScanCode.Numpad9, //0x049
    ScanCode.NumpadSubtract, //0x04A
    ScanCode.Numpad4, //0x04B
    ScanCode.Numpad5, //0x04C
    ScanCode.Numpad6, //0x04D
    ScanCode.NumpadAdd, //0x04E
    ScanCode.Numpad1, //0x04F
    ScanCode.Numpad2, //0x050
    ScanCode.Numpad3, //0x051
    ScanCode.Numpad0, //0x052
    ScanCode.NumpadDecimal, //0x053
    ScanCode.Unknown, //0x054
    ScanCode.Unknown, //0x055
    ScanCode.Key102nd, //0x056
    ScanCode.F11, //0x057
    ScanCode.F12, //0x058
    ScanCode.NumpadEqual, //0x059
    ScanCode.Unknown, //0x05A
    ScanCode.Unknown, //0x05B
    ScanCode.Unknown, //0x05C
    ScanCode.Unknown, //0x05D
    ScanCode.Unknown, //0x05E
    ScanCode.Unknown, //0x05F
    ScanCode.Unknown, //0x060
    ScanCode.Unknown, //0x061
    ScanCode.Unknown, //0x062
    ScanCode.Unknown, //0x063
    ScanCode.Unknown, //0x064
    ScanCode.Unknown, //0x065
    ScanCode.Unknown, //0x066
    ScanCode.Unknown, //0x067
    ScanCode.Unknown, //0x068
    ScanCode.Unknown, //0x069
    ScanCode.Unknown, //0x06A
    ScanCode.Unknown, //0x06B
    ScanCode.Unknown, //0x06C
    ScanCode.Unknown, //0x06D
    ScanCode.Unknown, //0x06E
    ScanCode.Unknown, //0x06F
    ScanCode.Unknown, //0x070
    ScanCode.Unknown, //0x071
    ScanCode.Unknown, //0x072
    ScanCode.Unknown, //0x073
    ScanCode.Unknown, //0x074
    ScanCode.Unknown, //0x075
    ScanCode.Unknown, //0x076
    ScanCode.Unknown, //0x077
    ScanCode.Unknown, //0x078
    ScanCode.Unknown, //0x079
    ScanCode.Unknown, //0x07A
    ScanCode.Unknown, //0x07B
    ScanCode.Unknown, //0x07C
    ScanCode.Unknown, //0x07D
    ScanCode.Unknown, //0x07E
    ScanCode.Unknown, //0x07F
    ScanCode.Unknown, //0x080
    ScanCode.Unknown, //0x081
    ScanCode.Unknown, //0x082
    ScanCode.Unknown, //0x083
    ScanCode.Unknown, //0x084
    ScanCode.Unknown, //0x085
    ScanCode.Unknown, //0x086
    ScanCode.Unknown, //0x087
    ScanCode.Unknown, //0x088
    ScanCode.Unknown, //0x089
    ScanCode.Unknown, //0x08A
    ScanCode.Unknown, //0x08B
    ScanCode.Unknown, //0x08C
    ScanCode.Unknown, //0x08D
    ScanCode.Unknown, //0x08E
    ScanCode.Unknown, //0x08F
    ScanCode.Unknown, //0x090
    ScanCode.Unknown, //0x091
    ScanCode.Unknown, //0x092
    ScanCode.Unknown, //0x093
    ScanCode.Unknown, //0x094
    ScanCode.Unknown, //0x095
    ScanCode.Unknown, //0x096
    ScanCode.Unknown, //0x097
    ScanCode.Unknown, //0x098
    ScanCode.Unknown, //0x099
    ScanCode.Unknown, //0x09A
    ScanCode.Unknown, //0x09B
    ScanCode.Unknown, //0x09C
    ScanCode.Unknown, //0x09D
    ScanCode.Unknown, //0x09E
    ScanCode.Unknown, //0x09F
    ScanCode.Unknown, //0x0A0
    ScanCode.Unknown, //0x0A1
    ScanCode.Unknown, //0x0A2
    ScanCode.Unknown, //0x0A3
    ScanCode.Unknown, //0x0A4
    ScanCode.Unknown, //0x0A5
    ScanCode.Unknown, //0x0A6
    ScanCode.Unknown, //0x0A7
    ScanCode.Unknown, //0x0A8
    ScanCode.Unknown, //0x0A9
    ScanCode.Unknown, //0x0AA
    ScanCode.Unknown, //0x0AB
    ScanCode.Unknown, //0x0AC
    ScanCode.Unknown, //0x0AD
    ScanCode.Unknown, //0x0AE
    ScanCode.Unknown, //0x0AF
    ScanCode.Unknown, //0x0B0
    ScanCode.Unknown, //0x0B1
    ScanCode.Unknown, //0x0B2
    ScanCode.Unknown, //0x0B3
    ScanCode.Unknown, //0x0Br
    ScanCode.Unknown, //0x0B5
    ScanCode.Unknown, //0x0B6
    ScanCode.Unknown, //0x0B7
    ScanCode.Unknown, //0x0B8
    ScanCode.Unknown, //0x0B9
    ScanCode.Unknown, //0x0BA
    ScanCode.Unknown, //0x0BB
    ScanCode.Unknown, //0x0BC
    ScanCode.Unknown, //0x0BD
    ScanCode.Unknown, //0x0BE
    ScanCode.Unknown, //0x0BF
    ScanCode.Unknown, //0x0C0
    ScanCode.Unknown, //0x0C1
    ScanCode.Unknown, //0x0C2
    ScanCode.Unknown, //0x0C3
    ScanCode.Unknown, //0x0C4
    ScanCode.Unknown, //0x0C5
    ScanCode.Unknown, //0x0C6
    ScanCode.Unknown, //0x0C7
    ScanCode.Unknown, //0x0C8
    ScanCode.Unknown, //0x0C9
    ScanCode.Unknown, //0x0CA
    ScanCode.Unknown, //0x0CB
    ScanCode.Unknown, //0x0CC
    ScanCode.Unknown, //0x0CD
    ScanCode.Unknown, //0x0CE
    ScanCode.Unknown, //0x0CF
    ScanCode.Unknown, //0x0D0
    ScanCode.Unknown, //0x0D1
    ScanCode.Unknown, //0x0D2
    ScanCode.Unknown, //0x0D3
    ScanCode.Unknown, //0x0D4
    ScanCode.Unknown, //0x0D5
    ScanCode.Unknown, //0x0D6
    ScanCode.Unknown, //0x0D7
    ScanCode.Unknown, //0x0D8
    ScanCode.Unknown, //0x0D9
    ScanCode.Unknown, //0x0DA
    ScanCode.Unknown, //0x0DB
    ScanCode.Unknown, //0x0DC
    ScanCode.Unknown, //0x0DD
    ScanCode.Unknown, //0x0DE
    ScanCode.Unknown, //0x0DF
    ScanCode.Unknown, //0x0E0
    ScanCode.Unknown, //0x0E1
    ScanCode.Unknown, //0x0E2
    ScanCode.Unknown, //0x0E3
    ScanCode.Unknown, //0x0E4
    ScanCode.Unknown, //0x0E5
    ScanCode.Unknown, //0x0E6
    ScanCode.Unknown, //0x0E7
    ScanCode.Unknown, //0x0E8
    ScanCode.Unknown, //0x0E9
    ScanCode.Unknown, //0x0EA
    ScanCode.Unknown, //0x0EB
    ScanCode.Unknown, //0x0EC
    ScanCode.Unknown, //0x0ED
    ScanCode.Unknown, //0x0EE
    ScanCode.Unknown, //0x0EF
    ScanCode.Unknown, //0x0F0
    ScanCode.Unknown, //0x0F1
    ScanCode.Unknown, //0x0F2
    ScanCode.Unknown, //0x0F3
    ScanCode.Unknown, //0x0F4
    ScanCode.Unknown, //0x0F5
    ScanCode.Unknown, //0x0F6
    ScanCode.Unknown, //0x0F7
    ScanCode.Unknown, //0x0F8
    ScanCode.Unknown, //0x0F9
    ScanCode.Unknown, //0x0FA
    ScanCode.Unknown, //0x0FB
    ScanCode.Unknown, //0x0FC
    ScanCode.Unknown, //0x0FD
    ScanCode.Unknown, //0x0FE
    ScanCode.Unknown, //0x0FF
    ScanCode.Unknown, //0x100
    ScanCode.Unknown, //0x101
    ScanCode.Unknown, //0x102
    ScanCode.Unknown, //0x103
    ScanCode.Unknown, //0x104
    ScanCode.Unknown, //0x105
    ScanCode.Unknown, //0x106
    ScanCode.Unknown, //0x107
    ScanCode.Unknown, //0x108
    ScanCode.Unknown, //0x109
    ScanCode.Unknown, //0x10A
    ScanCode.Unknown, //0x10B
    ScanCode.Unknown, //0x10C
    ScanCode.Unknown, //0x10D
    ScanCode.Unknown, //0x10E
    ScanCode.Unknown, //0x10F
    ScanCode.PrevTrack, //0x110
    ScanCode.Unknown, //0x111
    ScanCode.Unknown, //0x112
    ScanCode.Unknown, //0x113
    ScanCode.Unknown, //0x114
    ScanCode.Unknown, //0x115
    ScanCode.Unknown, //0x116
    ScanCode.Unknown, //0x117
    ScanCode.Unknown, //0x118
    ScanCode.NextTrack, //0x119
    ScanCode.Unknown, //0x11A
    ScanCode.Unknown, //0x11B
    ScanCode.NumpadReturn, //0x11C
    ScanCode.RControl, //0x11D
    ScanCode.Unknown, //0x11E
    ScanCode.Unknown, //0x11F
    ScanCode.VolumeMute, //0x120
    ScanCode.Unknown, //0x121
    ScanCode.PlayPause, //0x122
    ScanCode.Unknown, //0x123
    ScanCode.Unknown, //0x124
    ScanCode.Unknown, //0x125
    ScanCode.Unknown, //0x126
    ScanCode.Unknown, //0x127
    ScanCode.Unknown, //0x128
    ScanCode.Unknown, //0x129
    ScanCode.Unknown, //0x12A
    ScanCode.Unknown, //0x12B
    ScanCode.Unknown, //0x12C
    ScanCode.Unknown, //0x12D
    ScanCode.VolumeDown, //0x12E
    ScanCode.Unknown, //0x12F
    ScanCode.VolumeUp, //0x130
    ScanCode.Unknown, //0x131
    ScanCode.Unknown, //0x132
    ScanCode.Unknown, //0x133
    ScanCode.Unknown, //0x134
    ScanCode.NumpadDivide, //0x135
    ScanCode.Unknown, //0x136
    ScanCode.PrintScreen, //0x137
    ScanCode.RAlt, //0x138
    ScanCode.Unknown, //0x139
    ScanCode.Unknown, //0x13A
    ScanCode.Unknown, //0x13B
    ScanCode.Unknown, //0x13C
    ScanCode.Unknown, //0x13D
    ScanCode.Unknown, //0x13E
    ScanCode.Unknown, //0x13F
    ScanCode.Unknown, //0x140
    ScanCode.Unknown, //0x141
    ScanCode.Unknown, //0x142
    ScanCode.Unknown, //0x143
    ScanCode.Unknown, //0x144
    ScanCode.NumLock, //0x145
    ScanCode.Unknown, //0x146
    ScanCode.Home, //0x147
    ScanCode.Up, //0x148
    ScanCode.PageUp, //0x149
    ScanCode.Unknown, //0x14A
    ScanCode.Left, //0x14B
    ScanCode.Unknown, //0x14C
    ScanCode.Right, //0x14D
    ScanCode.Unknown, //0x14E
    ScanCode.End, //0x14F
    ScanCode.Down, //0x150
    ScanCode.PageDown, //0x151
    ScanCode.Insert, //0x152
    ScanCode.Delete, //0x153
    ScanCode.Unknown, //0x154
    ScanCode.Unknown, //0x155
    ScanCode.Unknown, //0x156
    ScanCode.Unknown, //0x157
    ScanCode.Unknown, //0x158
    ScanCode.Unknown, //0x159
    ScanCode.Unknown, //0x15A
    ScanCode.LSuper, //0x15B
    ScanCode.RSuper, //0x15C
    ScanCode.Menu, //0x15D
    ScanCode.Unknown, //0x15E
    ScanCode.Unknown, //0x15F
    ScanCode.Unknown, //0x160
    //END of `known` scancodes
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

const WIN32_VK_TO_KEYCODE = [255]KeyCode{
    KeyCode.Unknown, //0x00
    KeyCode.Unknown, //0x01
    KeyCode.Unknown, //0x02
    KeyCode.Unknown, //0x03
    KeyCode.Unknown, //0x04
    KeyCode.Unknown, //0x05
    KeyCode.Unknown, //0x06
    KeyCode.Unknown, //0x07
    KeyCode.Backspace, //0x08
    KeyCode.Tab, //0x09
    KeyCode.Unknown, //0x0A
    KeyCode.Unknown, //0x0B
    KeyCode.Unknown, //0x0C
    KeyCode.Return, //0x0D
    KeyCode.Unknown, //0x0E
    KeyCode.Unknown, //0x0F
    KeyCode.Shift, //0x10
    KeyCode.Control, //0x11
    KeyCode.Alt, //0x12
    KeyCode.Pause, //0x13
    KeyCode.CapsLock, //0x14
    KeyCode.Unknown, //0x15
    KeyCode.Unknown, //0x16
    KeyCode.Unknown, //0x17
    KeyCode.Unknown, //0x18
    KeyCode.Unknown, //0x19
    KeyCode.Unknown, //0x1A
    KeyCode.Escape, //0x1B
    KeyCode.Unknown, //0x1C
    KeyCode.Unknown, //0x1D
    KeyCode.Unknown, //0x1E
    KeyCode.Unknown, //0x1F
    KeyCode.Space, //0x20
    KeyCode.PageUp, //0x21
    KeyCode.PageDown, //0x22
    KeyCode.End, //0x23
    KeyCode.Home, //0x24
    KeyCode.Left, //0x25
    KeyCode.Up, //0x26
    KeyCode.Right, //0x27
    KeyCode.Down, //0x28
    KeyCode.Unknown, //0x29 VK_SELECT
    KeyCode.Unknown, //0x2A VK_PRINT
    KeyCode.Unknown, //0x2B //VK_EXECUTE
    KeyCode.PrintScreen, //0x2C
    KeyCode.Insert, //0x2D
    KeyCode.Delete, //0x2E
    KeyCode.Unknown, //0x2F VK_HELP
    KeyCode.Num0, //0x30
    KeyCode.Num1, //0x31
    KeyCode.Num2, //0x32
    KeyCode.Num3, //0x33
    KeyCode.Num4, //0x34
    KeyCode.Num5, //0x35
    KeyCode.Num6, //0x36
    KeyCode.Num7, //0x37
    KeyCode.Num8, //0x38
    KeyCode.Num9, //0x39
    KeyCode.Unknown, //0x3A
    KeyCode.Unknown, //0x3B
    KeyCode.Unknown, //0x3C
    KeyCode.Unknown, //0x3D
    KeyCode.Unknown, //0x3E
    KeyCode.Unknown, //0x3F
    KeyCode.Unknown, //0x40
    KeyCode.A, //0x41
    KeyCode.B, //0x42
    KeyCode.C, //0x43
    KeyCode.D, //0x44
    KeyCode.E, //0x45
    KeyCode.F, //0x46
    KeyCode.G, //0x47
    KeyCode.H, //0x48
    KeyCode.I, //0x49
    KeyCode.J, //0x4A
    KeyCode.K, //0x4B
    KeyCode.L, //0x4C
    KeyCode.M, //0x4D
    KeyCode.N, //0x4E
    KeyCode.O, //0x4F
    KeyCode.P, //0x50
    KeyCode.Q, //0x51
    KeyCode.R, //0x52
    KeyCode.S, //0x53
    KeyCode.T, //0x54
    KeyCode.U, //0x55
    KeyCode.V, //0x56
    KeyCode.W, //0x57
    KeyCode.X, //0x58
    KeyCode.Y, //0x59
    KeyCode.Z, //0x5A
    KeyCode.Super, //0x5B
    KeyCode.Super, //0x5C
    KeyCode.Unknown, //0x5D VK_APPS
    KeyCode.Unknown, //0x5E
    KeyCode.Unknown, //0x5F VK_SLEEP
    KeyCode.Numpad0, //0x60
    KeyCode.Numpad1, //0x61
    KeyCode.Numpad2, //0x62
    KeyCode.Numpad3, //0x63
    KeyCode.Numpad4, //0x64
    KeyCode.Numpad5, //0x65
    KeyCode.Numpad6, //0x66
    KeyCode.Numpad7, //0x67
    KeyCode.Numpad8, //0x68
    KeyCode.Numpad9, //0x69
    KeyCode.Multiply, //0x6A
    KeyCode.Add, //0x6B
    KeyCode.Unknown, //0x6C VK_SEPERATOR
    KeyCode.Subtract, //0x6D
    KeyCode.Period, //0x6E
    KeyCode.Divide, //0x6F
    KeyCode.F1, //0x70
    KeyCode.F2, //0x71
    KeyCode.F3, //0x72
    KeyCode.F4, //0x73
    KeyCode.F5, //0x74
    KeyCode.F6, //0x75
    KeyCode.F7, //0x76
    KeyCode.F8, //0x77
    KeyCode.F9, //0x78
    KeyCode.F10, //0x79
    KeyCode.F11, //0x7A
    KeyCode.F12, //0x7B
    // 0x7C - 0x87: F13-F24,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    // 0x88 - 0x8F: unassigned
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.NumLock, //0x90
    KeyCode.ScrollLock, //0x91
    // 0x92 - 0x9F unassigned.
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    // 0xA0 - 0xAC : No mapped enum variant.
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.VolumeMute, //0xAD
    KeyCode.VolumeDown, //0xAE
    KeyCode.VolumeUp, //0xAF
    KeyCode.NextTrack, //0xB0
    KeyCode.PrevTrack, //0xB1
    KeyCode.Unknown, //0xB2 VK_MEDIA_STOP
    KeyCode.PlayPause, //0xB3
    // 0xB4 - 0xBA: No enum variant.
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Equal, //0xBB
    KeyCode.Comma, //0xBC
    KeyCode.Hyphen, //0xBD
    KeyCode.Period, //0xBE
    // 0xBF - 0xFF: Not mapped.
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
    KeyCode.Unknown,
};

/// Maps a Windows virtual key code to a widow virtual Key Code.
fn vkToKeycode(keycode: u16) KeyCode {
    if (keycode >= 255) {
        return KeyCode.Unknown;
    }

    switch (keycode) {
        // Note: OEM keys are used for miscellanous characters
        // which can vary depending on the keyboard
        // Solution: decide depending on ther text value.
        win32_input.VK_OEM_1,
        win32_input.VK_OEM_2,
        win32_input.VK_OEM_3,
        win32_input.VK_OEM_4,
        win32_input.VK_OEM_5,
        win32_input.VK_OEM_6,
        win32_input.VK_OEM_7,
        win32_input.VK_OEM_102,
        => {
            // Use the key text to identify it.
            return keyTextToVirtual(keycode);
        },
        else => return WIN32_VK_TO_KEYCODE[keycode],
    }
}

fn keyTextToVirtual(keycode: u16) KeyCode {
    const MAPVK_VK_TO_CHAR = 2;
    const key_text = win32_input.MapVirtualKeyW(keycode, MAPVK_VK_TO_CHAR) & 0xFFFF;
    switch (key_text) {
        ';' => return KeyCode.Semicolon,
        '/' => return KeyCode.Slash,
        '`' => return KeyCode.Grave,
        '[' => return KeyCode.LBracket,
        '\\' => return KeyCode.Backslash,
        ']' => return KeyCode.RBracket,
        '\'' => return KeyCode.Quote,
        else => return KeyCode.Unknown,
    }
}

/// figure out the scancode and appropriate virtual key.
pub fn translateVirtualKey(vk: u16, lparam: win32.LPARAM) struct { KeyCode, ScanCode } {
    const MAPVK_VK_TO_VSC = 0;
    // The extended bit is necessary to find the correct scancode
    const ulparm: usize = @bitCast((lparam >> 16) & 0x1FF);
    var code: u32 = @truncate(ulparm);
    if (code == 0) {
        // scancode value shouldn't be zero
        code = win32_input.MapVirtualKeyW(vk, MAPVK_VK_TO_VSC);
    }
    // Notes:
    // According to windows
    // SysRq key scan code is emmited on Alt+Printscreen screen keystroke
    if (code == 0x54) {
        // set it back to printscreen.
        code = 0x37;
    }
    // Break key scan code is emmited on Control+Pause keystroke
    if (code == 0x146) {
        // set it back to pause.
        code = 0x45;
    }

    const virt_keycode = vkToKeycode(vk);

    const scancode = WIN32_VK_TO_SCANCODE[code];

    return .{ virt_keycode, scancode };
}
