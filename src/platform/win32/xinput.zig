const std = @import("std");
const module = @import("module.zig");
const joystick = @import("common").joystick;
const XInputError = @import("errors.zig").XInputError;
const event = @import("common").event;
const win32 = @import("win32_defs.zig");
const xinput = @import("zigwin32").ui.input.xbox_controller;
const win32_input = @import("zigwin32").ui.input;
const JoystickSubSystemImpl = @import("joystick_impl.zig").JoystickSubSystemImpl;
const JoystickAPI = @import("joystick_impl.zig").JoystickAPI;
const Win32JoyData = @import("joystick_impl.zig").Win32JoyData;
const Joystick = joystick.Joystick;

/// Imports Signature.
const proc_XInputGetState = *const fn (
    win32.DWORD,
    *xinput.XINPUT_STATE,
) callconv(win32.WINAPI) win32.DWORD;
const proc_XInputSetState = *const fn (
    win32.DWORD,
    *xinput.XINPUT_VIBRATION,
) callconv(win32.WINAPI) win32.DWORD;
const proc_XInputGetCapabilities = *const fn (
    win32.DWORD,
    win32.DWORD,
    *xinput.XINPUT_CAPABILITIES,
) callconv(win32.WINAPI) win32.DWORD;
const proc_XInputGetBatteryInformation = *const fn (
    win32.DWORD,
    win32.BYTE,
    *xinput.XINPUT_BATTERY_INFORMATION,
) callconv(win32.WINAPI) win32.DWORD;

pub const FMAX_JOY_AXIS = 32767.5;
// pub const MIN_JOY_AXIS = -32768;
pub const FHALF_MAX_JOY_TRIGGER = 127.5;

/// Holds XInput API data for each controller it enumerate.
pub const XInputData = struct {
    packet_number: u32,
    id: u8,
    wired: bool,
};

/// XInput api interface.
/// encapsulate all the modules and function necessary for the api to work.
pub const XInputInterface = struct {
    handle: win32.HINSTANCE,
    legacy: bool,
    getState: proc_XInputGetState,
    setState: proc_XInputSetState,
    getCaps: proc_XInputGetCapabilities,
    // Not all api versions support this.
    getBatteryInfo: ?proc_XInputGetBatteryInformation,
    const Self = @This();

    pub fn init() !Self {
        var self: Self = undefined;
        self.legacy = false;
        var dll: ?win32.HINSTANCE = module.loadWin32Module("XInput1_4.dll"); // 1.4 Ships with Windows 8.
        if (dll == null) {
            dll = module.loadWin32Module("XInput1_3.dll"); // 1.3 can be installed as a redistributable component.
        }
        if (dll == null) {
            // "9.1.0" Ships with Vista and Win7, and is more limited than 1.3+ (e.g. XInputGetStateEx is not available.)
            dll = module.loadWin32Module("XInput9_1_0.dll") orelse {
                std.log.info("Couldn't Load XInput DLL\n", .{});
                return XInputError.FailedToLoadDLL;
            };

            self.legacy = true;
        }

        self.handle = dll.?;
        self.getState = @ptrCast(module.getModuleSymbol(self.handle, "XInputGetState"));
        self.setState = @ptrCast(module.getModuleSymbol(self.handle, "XInputSetState"));
        self.getCaps = @ptrCast(module.getModuleSymbol(self.handle, "XInputGetCapabilities"));
        self.getBatteryInfo = @ptrCast(module.getModuleSymbol(self.handle, "XInputGetBatteryInformation"));
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

/// Detect if any xinput compatible pad is connected and initialize
/// a corresponding joystick instance.
pub fn pollPadsConnection(jss: *JoystickSubSystemImpl) void {
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
                }
            }
        }

        if (occupied) {
            i += 1;
            continue;
        }

        var xcaps: xinput.XINPUT_CAPABILITIES = undefined;
        if (jss.xapi.getCaps(i, xinput.XINPUT_FLAG_GAMEPAD, &xcaps) == @intFromEnum(win32.WIN32_ERROR.NO_ERROR)) {
            const joy = &jss.joys[slot];
            if (initPad(jss.allocator, joy, i)) {
                // On success.
                jss.joys_exdata[slot] = Win32JoyData{ .XInput = XInputData{
                    .id = i,
                    .packet_number = 0,
                    .wired = if (xcaps.Flags & xinput.XINPUT_CAPS_WIRELESS != 0) false else true,
                } };
                // create the event.
                const ev = event.createJoyConnectEvent(slot, true);
                jss.sendEvent(&ev);
            } else {
                // Failed to init joystick due to lack of memory space.
                break;
            }
        }
        i += 1;
    }
}

pub fn pollPadPresence(xapi: *const XInputInterface, xid: u8) bool {
    var xstate: xinput.XINPUT_STATE = undefined;
    const result = xapi.getState(xid, &xstate);
    if (result != @intFromEnum(win32.WIN32_ERROR.NO_ERROR)) {
        // Disconnected.
        std.debug.print("NOT_CONNECTD:{}\n,", .{result});
        return false;
    }
    return true;
}

inline fn initPad(allocator: std.mem.Allocator, joy: *Joystick, id: u8) bool {
    var name_buff: [64]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buff, "Xbox Controller #{d}", .{id + 1}) catch unreachable;
    joy.* = Joystick.init(
        allocator,
        name,
        6,
        14,
        true,
    ) catch {
        std.log.err("[Joystick]:Allocation Failure, Failed To Allocate space for {s}\n", .{name});
        return false;
    };
    return true;
}

fn normalizeAxis(value: i32, is_trigger: bool, negate: bool) f32 {
    const fvalue: f32 = @floatFromInt(value);
    var norm_value: f32 = undefined;
    if (is_trigger) {
        norm_value = (fvalue / FHALF_MAX_JOY_TRIGGER) - 1.0;
    } else {
        norm_value = ((fvalue + 0.5) / FMAX_JOY_AXIS);
    }

    if (negate) {
        norm_value = -norm_value;
    }

    return norm_value;
}

/// Poll for gamepad state changes.
/// if the gamepad is disconnected it returns null otherwise it returns the number of
/// chages that happend to the gamepad state
pub fn pollPadState(jss: *JoystickSubSystemImpl, joy_id: u8, xdata: *XInputData) bool {
    const buttons = comptime [14]u32{
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
        xinput.XINPUT_GAMEPAD_DPAD_UP,
        xinput.XINPUT_GAMEPAD_DPAD_RIGHT,
        xinput.XINPUT_GAMEPAD_DPAD_DOWN,
        xinput.XINPUT_GAMEPAD_DPAD_LEFT,
    };

    var xstate: xinput.XINPUT_STATE = undefined;
    const result = jss.xapi.getState(xdata.id, &xstate);
    if (result == @intFromEnum(win32.WIN32_ERROR.ERROR_DEVICE_NOT_CONNECTED)) {
        // Disconnected.
        return false;
    }

    if (xdata.packet_number != xstate.dwPacketNumber) {
        xdata.packet_number = xstate.dwPacketNumber;
        const joy = &jss.joys[joy_id];
        var updated: bool = false;
        // Each of the thumbstick axis members is a signed value between -32768 and 32767
        // describing the position of the thumbstick.
        // A value of 0 is centered. Negative values signify down or to the left.
        // Positive values signify up or to the right.
        // All axis values are normalized to a value between -1.0 and 1.0,
        // the direction of the y axis is flipped with the down being positve and up being negative.
        var axis_value: f32 = normalizeAxis(@intCast(xstate.Gamepad.sThumbLX), false, false);
        updated = joy.setAxis(@intFromEnum(joystick.XboxAxis.LeftX), axis_value);
        if (updated) {
            const ev = event.createJoyAxisEvent(
                joy_id,
                @intFromEnum(joystick.XboxAxis.LeftX),
                joy.axes.items[@intFromEnum(joystick.XboxAxis.LeftX)],
                joy.is_gamepad,
            );
            jss.sendEvent(&ev);
        }
        axis_value = normalizeAxis(@intCast(xstate.Gamepad.sThumbLY), false, true);
        updated = joy.setAxis(@intFromEnum(joystick.XboxAxis.LeftY), axis_value);
        if (updated) {
            const ev = event.createJoyAxisEvent(
                joy_id,
                @intFromEnum(joystick.XboxAxis.LeftY),
                joy.axes.items[@intFromEnum(joystick.XboxAxis.LeftY)],
                joy.is_gamepad,
            );
            jss.sendEvent(&ev);
        }
        axis_value = normalizeAxis(@intCast(xstate.Gamepad.sThumbRX), false, false);
        updated = joy.setAxis(@intFromEnum(joystick.XboxAxis.RightX), axis_value);
        if (updated) {
            const ev = event.createJoyAxisEvent(
                joy_id,
                @intFromEnum(joystick.XboxAxis.RightX),
                joy.axes.items[@intFromEnum(joystick.XboxAxis.RightX)],
                joy.is_gamepad,
            );
            jss.sendEvent(&ev);
        }
        axis_value = normalizeAxis(@intCast(xstate.Gamepad.sThumbRY), false, true);
        updated = joy.setAxis(@intFromEnum(joystick.XboxAxis.RightY), axis_value);
        if (updated) {
            const ev = event.createJoyAxisEvent(
                joy_id,
                @intFromEnum(joystick.XboxAxis.RightY),
                joy.axes.items[@intFromEnum(joystick.XboxAxis.RightY)],
                joy.is_gamepad,
            );
            jss.sendEvent(&ev);
        }
        axis_value = normalizeAxis(@intCast(xstate.Gamepad.bLeftTrigger), true, false);
        updated = joy.setAxis(@intFromEnum(joystick.XboxAxis.LTrigger), axis_value);
        if (updated) {
            const ev = event.createJoyAxisEvent(
                joy_id,
                @intFromEnum(joystick.XboxAxis.LTrigger),
                joy.axes.items[@intFromEnum(joystick.XboxAxis.LTrigger)],
                joy.is_gamepad,
            );
            jss.sendEvent(&ev);
        }
        axis_value = normalizeAxis(@intCast(xstate.Gamepad.bRightTrigger), true, false);
        updated = joy.setAxis(@intFromEnum(joystick.XboxAxis.RTrigger), axis_value);
        if (updated) {
            const ev = event.createJoyAxisEvent(
                joy_id,
                @intFromEnum(joystick.XboxAxis.RTrigger),
                joy.axes.items[@intFromEnum(joystick.XboxAxis.RTrigger)],
                joy.is_gamepad,
            );
            jss.sendEvent(&ev);
        }

        for (buttons, 0..buttons.len) |button, index| {
            // Bitmask of the device digital buttons, A set bit indicates that the corresponding button is pressed.
            const value = if (xstate.Gamepad.wButtons & button != 0) joystick.ButtonState.Pressed else joystick.ButtonState.Released;
            updated = joy.setButton(@truncate(index), value);
            if (updated) {
                const ev = event.createJoyButtonEvent(
                    xdata.id,
                    @truncate(index),
                    value,
                    joy.is_gamepad,
                );
                jss.sendEvent(&ev);
            }
        }
    }
    return true;
}

/// Vibrate the controller
pub fn rumble(api: *const XInputInterface, xdata: *const XInputData, magnitude: u16) XInputError!void {
    var vibration = xinput.XINPUT_VIBRATION{
        .wLeftMotorSpeed = magnitude,
        .wRightMotorSpeed = magnitude,
    };

    if (api.setState(xdata.id, &vibration) != @intFromEnum(win32.WIN32_ERROR.NO_ERROR)) {
        std.debug.print("SetState error\n", .{});
        return XInputError.FailedToSetState;
    }
}

/// Returns battery state infos.
pub fn batteryInfo(api: *const XInputInterface, xdata: *const XInputData) joystick.BatteryInfo {
    if (api.legacy) {
        return joystick.BatteryInfo.PowerUnkown;
    }

    if (!xdata.wired) {
        return joystick.BatteryInfo.Wired;
    }
    var bi: xinput.XINPUT_BATTERY_INFORMATION = undefined;
    _ = api.getBatteryInfo.?(xdata.id, xinput.BATTERY_DEVTYPE_GAMEPAD, &bi);
    switch (bi.BatteryLevel) {
        xinput.BATTERY_LEVEL_LOW => return joystick.BatteryInfo.PowerLow,
        xinput.BATTERY_LEVEL_MEDIUM => return joystick.BatteryInfo.PowerMedium,
        xinput.BATTERY_LEVEL_FULL => return joystick.BatteryInfo.PowerFull,
        xinput.BATTERY_LEVEL_EMPTY => return joystick.BatteryInfo.PowerEmpty,
        else => return joystick.BatteryInfo.PowerUnkown,
    }
}
