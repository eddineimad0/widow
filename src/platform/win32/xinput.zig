const std = @import("std");
const module = @import("module.zig");
const joystick = @import("common").joystick;
const windows = std.os.windows;
const winapi = @import("win32");
const xinput = winapi.ui.input.xbox_controller;
const win32_input = winapi.ui.input;
const winabi = windows.WINAPI;
const JoystickSubSystem = @import("joystick_impl.zig").JoystickSubSystem;
const JoystickAPI = @import("joystick_impl.zig").JoystickAPI;
const Win32JoyData = @import("joystick_impl.zig").Win32JoyData;
const Joystick = joystick.Joystick;
const win32_error = winapi.foundation.WIN32_ERROR;
const DWORD = u32;
const proc_XInputGetState = *const fn (DWORD, *xinput.XINPUT_STATE) callconv(winabi) DWORD;
const proc_XInputSetState = *const fn (DWORD, *xinput.XINPUT_VIBRATION) callconv(winabi) DWORD;
const proc_XInputGetCapabilities = *const fn (DWORD, DWORD, *xinput.XINPUT_CAPABILITIES) callconv(winabi) DWORD;
const GUID = winapi.zig.Guid;
const XINPUT_GAMEPAD_GUIDE = @as(u32, 0x0400);

pub const XInputData = struct {
    packet_number: u32,
    id: u8,
};

pub const XInputInterface = struct {
    handle: module.HINSTANCE,
    legacy: bool,
    getState: proc_XInputGetState,
    setState: proc_XInputSetState,
    getCaps: proc_XInputGetCapabilities,
    const Self = @This();

    pub fn init() !Self {
        var self: Self = undefined;
        self.legacy = false;
        // From SDL :
        // NOTE: Don't load XinputUap.dll
        // This is XInput emulation over Windows.Gaming.Input, and has all the
        // limitations of that API (no devices at startup, no background input, etc.)
        var dll: ?module.HINSTANCE = module.loadWin32Module("XInput1_4.dll"); // 1.4 Ships with Windows 8.
        if (dll == null) {
            dll = module.loadWin32Module("XInput1_3.dll"); // 1.3 can be installed as a redistributable component.
        }
        if (dll == null) {
            // "9.1.0" Ships with Vista and Win7, and is more limited than 1.3+ (e.g. XInputGetStateEx is not available.)
            dll = module.loadWin32Module("XInput9_1_0.dll") orelse {
                std.log.err("Couldn't Load XInput DLL\n", .{});
                return XInputError.FailedToLoadDLL;
            };

            self.legacy = true;
        }

        self.handle = dll.?;
        self.getState = @ptrCast(?proc_XInputGetState, module.getModuleSymbol(self.handle, "XInputGetState")) orelse {
            module.freeWin32Module(self.handle);
            return XInputError.FailedToLoadLibraryFunc;
        };
        self.setState = @ptrCast(?proc_XInputSetState, module.getModuleSymbol(self.handle, "XInputSetState")) orelse {
            module.freeWin32Module(self.handle);
            return XInputError.FailedToLoadLibraryFunc;
        };
        self.getCaps = @ptrCast(?proc_XInputGetCapabilities, module.getModuleSymbol(self.handle, "XInputGetCapabilities")) orelse {
            module.freeWin32Module(self.handle);
            return XInputError.FailedToLoadLibraryFunc;
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        module.freeWin32Module(self.handle);
        self.handle = undefined;
        self.setState = undefined;
        self.getState = undefined;
        self.getCaps = undefined;
    }
};

// Taken from The GLFW library.
// The method propsed in MSDN looks too complexe.
fn isXInputDevice(guid: *GUID) bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var rdevices_count: u32 = undefined;
    _ = win32_input.GetRawInputDeviceList(null, &rdevices_count, @sizeOf(win32_input.RAWINPUTDEVICELIST));
    std.debug.assert(rdevices_count != 0);
    var rdevice_list = arena.allocator().alloc(win32_input.RAWINPUTDEVICELIST, rdevices_count) catch |e| {
        std.log.err("Failed to allocate a RawINPUTDEVICELIST {}\n", .{e});
        return false;
    };
    defer arena.allocator().free(rdevice_list);

    if (win32_input.GetRawInputDeviceList(rdevice_list.ptr, &rdevices_count, @sizeOf(win32_input.RAWINPUTDEVICELIST)) == @as(u32, 0xFFFFFFFF)) {
        return false;
    }

    var rdevice_info: win32_input.RID_DEVICE_INFO = undefined;
    var rdevice_name: [128]u8 = undefined;
    var rdi_size: u32 = @sizeOf(win32_input.RID_DEVICE_INFO);
    var name_size: u32 = 128;
    rdevice_info.cbSize = rdi_size;
    for (rdevice_list) |device| {
        if (device.dwType != win32_input.RIM_TYPEHID) {
            // skip mouse and keyboard.
            continue;
        }

        _ = win32_input.GetRawInputDeviceInfoA(
            device.hDevice,
            win32_input.RIDI_DEVICEINFO,
            @ptrCast(*anyopaque, &rdevice_info),
            &rdi_size,
        );

        if (guid.Ints.a !=
            ((rdevice_info.Anonymous.hid.dwProductId & 0xFFFF) << 16) | (rdevice_info.Anonymous.hid.dwVendorId & 0xFFFF))
        {
            // not the same input device
            continue;
        }

        if (win32_input.GetRawInputDeviceInfoA(
            device.hDevice,
            win32_input.RIDI_DEVICENAME,
            @ptrCast(*anyopaque, &rdevice_name),
            &name_size,
        ) == @as(u32, 0xFFFFFFFF)) {
            break;
        }
        // Xbox controllers have "IG_" somewhere in the device name.
        if (std.mem.indexOf(u8, &rdevice_name, "IG_") != null) {
            return true;
        }
    }
    return false;
}

pub fn pollPadsConnection(jss: *JoystickSubSystem) void {
    var i: u8 = 0;
    while (i < xinput.XUSER_MAX_COUNT) {
        // Check for empty slot.
        const slot = jss.emptyJoySlot() orelse {
            std.log.info("No more joystick slots.\n", .{});
            return;
        };

        var occupied = false;
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            if (jss.joys[joy_id].connected) {
                // !!! Attention to the connected flag
                // otherwise we're reading undefined data.
                switch (jss.joys_exdata[joy_id]) {
                    JoystickAPI.XInput => |*xdata| {
                        if (xdata.id == i) {
                            // We already registered this one.
                            occupied = true;
                            break;
                        }
                    },
                    else => {
                        continue;
                    },
                }
            }
        }

        if (occupied) {
            i += 1;
            continue;
        }

        var xcaps: xinput.XINPUT_CAPABILITIES = undefined;
        if (jss.xapi.getCaps(i, xinput.XINPUT_FLAG_GAMEPAD, &xcaps) == @enumToInt(win32_error.NO_ERROR)) {
            const joy = &jss.joys[slot];
            if (initJoystick(jss.allocator, joy, i)) {
                // On success.
                jss.joys_exdata[slot] = Win32JoyData{ .XInput = XInputData{
                    .id = i,
                    .packet_number = 0,
                } };
                // Notify user.
                jss.on_connection_change(slot, joy.hid_data.name, true, null);
            } else {
                // Failed to init joystick due to lack of memory space.
                break;
            }
        }
        i += 1;
    }
}

inline fn initJoystick(allocator: std.mem.Allocator, joy: *Joystick, id: u8) bool {
    var name_buff: [64]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buff, "Xbox Controller #{d}", .{id}) catch unreachable;
    joy.* = Joystick.init(
        allocator,
        name,
        joystick.JoystickType.Xbox,
        6,
        10,
        1,
    ) catch {
        std.log.err("[Joystick]:Allocation Failure, Failed To Allocate space for {s}\n", .{name});
        return false;
    };
    return true;
}

pub fn pollPadState(xapi: *const XInputInterface, joy: *Joystick, xdata: *XInputData) bool {
    const buttons = comptime [10]u32{
        xinput.XINPUT_GAMEPAD_A,
        xinput.XINPUT_GAMEPAD_B,
        xinput.XINPUT_GAMEPAD_X,
        xinput.XINPUT_GAMEPAD_Y,
        xinput.XINPUT_GAMEPAD_LEFT_SHOULDER,
        xinput.XINPUT_GAMEPAD_RIGHT_SHOULDER,
        xinput.XINPUT_GAMEPAD_BACK,
        xinput.XINPUT_GAMEPAD_START,
        xinput.XINPUT_GAMEPAD_LEFT_THUMB,
        xinput.XINPUT_GAMEPAD_RIGHT_THUMB,
    };

    var xstate: xinput.XINPUT_STATE = undefined;
    const result = xapi.getState(xdata.id, &xstate);
    if (result == @enumToInt(win32_error.ERROR_DEVICE_NOT_CONNECTED)) {
        // Disconnected.
        return false;
    }

    if (xdata.packet_number != xstate.dwPacketNumber) {
        xdata.packet_number = xstate.dwPacketNumber;
        // Each of the thumbstick axis members is a signed value between -32768 and 32767
        // describing the position of the thumbstick.
        // A value of 0 is centered. Negative values signify down or to the left.
        // Positive values signify up or to the right.
        // All axis values are normalized to a value between -1.0 and 1.0,
        // the direction of the y axis is flipped with the down being positve and up being negative.
        joy.setAxis(@enumToInt(joystick.XboxAxis.LeftX), (@intToFloat(f64, xstate.Gamepad.sThumbLX) + 0.5) / 32767.5);
        joy.setAxis(@enumToInt(joystick.XboxAxis.LeftY), -(@intToFloat(f64, xstate.Gamepad.sThumbLY) + 0.5) / 32767.5);
        joy.setAxis(@enumToInt(joystick.XboxAxis.RightX), (@intToFloat(f64, xstate.Gamepad.sThumbRX) + 0.5) / 32767.5);
        joy.setAxis(@enumToInt(joystick.XboxAxis.RightY), -(@intToFloat(f64, xstate.Gamepad.sThumbRY) + 0.5) / 32767.5);
        joy.setAxis(@enumToInt(joystick.XboxAxis.LTrigger), (@intToFloat(f64, xstate.Gamepad.bLeftTrigger) / 127.5) - 1.0);
        joy.setAxis(@enumToInt(joystick.XboxAxis.RTrigger), (@intToFloat(f64, xstate.Gamepad.bRightTrigger) / 127.5) - 1.0);

        for (buttons, 0..buttons.len) |button, index| {
            // Bitmask of the device digital buttons, A set bit indicates that the corresponding button is pressed.
            const value = if (xstate.Gamepad.wButtons & button != 0) joystick.ButtonState.Pressed else joystick.ButtonState.Released;
            joy.setButton(@truncate(u8, index), value);
        }

        var dpad: u8 = 0x00; // centered
        if (xstate.Gamepad.wButtons & xinput.XINPUT_GAMEPAD_DPAD_UP != 0)
            dpad |= @enumToInt(joystick.HatState.Up);
        if (xstate.Gamepad.wButtons & xinput.XINPUT_GAMEPAD_DPAD_RIGHT != 0)
            dpad |= @enumToInt(joystick.HatState.Right);
        if (xstate.Gamepad.wButtons & xinput.XINPUT_GAMEPAD_DPAD_DOWN != 0)
            dpad |= @enumToInt(joystick.HatState.Down);
        if (xstate.Gamepad.wButtons & xinput.XINPUT_GAMEPAD_DPAD_LEFT != 0)
            dpad |= @enumToInt(joystick.HatState.Left);

        joy.setHat(0, dpad);
    }
    return true;
}

// pub fn vibrate(self: *Self) XInputError!void {
//     if (self.connected) {
//         const vibration = xinput.XINPUT_VIBRATION{
//             .wLeftMotorSpeed = 65535,
//             .wRightMotorSpeed = 65535,
//         };
//         // ERROR_SUCCESS;
//         if (self.set_state_fun(self.gid, &vibration) != 0) {
//             return XInputError.FailedToSetState;
//         }
//     }
// }
//
// pub fn stopVibration(self: *Self) XInputError!void {
//     if (self.connected) {
//         const vibration = xinput.XINPUT_VIBRATION{
//             .wLeftMotorSpeed = 0,
//             .wRightMotorSpeed = 0,
//         };
//         // ERROR_SUCCESS;
//         if (self.set_state_fun(self.gid, &vibration) != 0) {
//             return XInputError.FailedToSetState;
//         }
//     }
// }
pub const XInputError = error{ FailedToLoadDLL, FailedToLoadLibraryFunc };
