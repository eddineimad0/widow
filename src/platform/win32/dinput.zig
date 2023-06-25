const std = @import("std");
const winapi = @import("win32");
const module = @import("module.zig");
const loWord = @import("utils.zig").loWord;
const isXInputDevice = @import("xinput.zig").isXInputDevice;
const winabi = std.os.windows.WINAPI;
const win32_hid = winapi.devices.human_interface_device;
const JoystickSubSystem = @import("joystick_impl.zig").JoystickSubSystem;
const Joystick = @import("common").joystick.Joystick;
const JoystickType = @import("common").joystick.JoystickType;
const ButtonState = @import("common").joystick.ButtonState;
const BOOL = winapi.foundation.BOOL;
const GUID = winapi.zig.Guid;
const DIDFT_OPTIONAL = 0x80000000;

const GUID_XAxis = win32_hid.GUID_XAxis;
const GUID_YAxis = win32_hid.GUID_YAxis;
const GUID_ZAxis = win32_hid.GUID_ZAxis;
const GUID_RxAxis = win32_hid.GUID_RxAxis;
const GUID_RyAxis = win32_hid.GUID_RyAxis;
const GUID_RzAxis = win32_hid.GUID_RzAxis;
const GUID_Slider = win32_hid.GUID_Slider;
const GUID_POV = win32_hid.GUID_POV;

const DIJOYSTATEOFS_X = @offsetOf(win32_hid.DIJOYSTATE, "lX");
const DIJOYSTATEOFS_Y = @offsetOf(win32_hid.DIJOYSTATE, "lY");
const DIJOYSTATEOFS_Z = @offsetOf(win32_hid.DIJOYSTATE, "lZ");
const DIJOYSTATEOFS_Rx = @offsetOf(win32_hid.DIJOYSTATE, "lRx");
const DIJOYSTATEOFS_Ry = @offsetOf(win32_hid.DIJOYSTATE, "lRy");
const DIJOYSTATEOFS_Rz = @offsetOf(win32_hid.DIJOYSTATE, "lRz");
const DIJOYSTATEOFS_Slider_0 = @offsetOf(win32_hid.DIJOYSTATE, "rglSlider");
const DIJOYSTATEOFS_Slider_1 = @offsetOf(win32_hid.DIJOYSTATE, "rglSlider") + 1 * @sizeOf(i32);
const DIJOYSTATEOFS_POV_0 = @offsetOf(win32_hid.DIJOYSTATE, "rgdwPOV");
const DIJOYSTATEOFS_POV_1 = @offsetOf(win32_hid.DIJOYSTATE, "rgdwPOV") + 1 * @sizeOf(u32);
const DIJOYSTATEOFS_POV_2 = @offsetOf(win32_hid.DIJOYSTATE, "rgdwPOV") + 2 * @sizeOf(u32);
const DIJOYSTATEOFS_POV_3 = @offsetOf(win32_hid.DIJOYSTATE, "rgdwPOV") + 3 * @sizeOf(u32);
const DIJOYSTATEOFS_Buttons_0 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 0;
const DIJOYSTATEOFS_Buttons_1 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 1 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_2 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 2 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_3 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 3 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_4 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 4 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_5 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 5 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_6 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 6 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_7 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 7 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_8 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 8 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_9 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 9 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_10 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 10 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_11 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 11 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_12 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 12 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_13 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 13 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_14 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 14 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_15 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 15 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_16 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 16 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_17 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 17 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_18 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 18 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_19 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 19 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_20 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 20 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_21 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 21 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_22 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 22 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_23 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 23 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_24 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 24 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_25 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 25 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_26 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 26 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_27 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 27 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_28 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 28 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_29 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 29 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_30 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 30 * @sizeOf(u8);
const DIJOYSTATEOFS_Buttons_31 = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + 31 * @sizeOf(u8);

const JoyObjectDataFormat = [_]win32_hid.DIOBJECTDATAFORMAT{
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_XAxis, .dwOfs = DIJOYSTATEOFS_X, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_YAxis, .dwOfs = DIJOYSTATEOFS_Y, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_ZAxis, .dwOfs = DIJOYSTATEOFS_Z, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_RxAxis, .dwOfs = DIJOYSTATEOFS_Rx, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_RyAxis, .dwOfs = DIJOYSTATEOFS_Ry, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_RzAxis, .dwOfs = DIJOYSTATEOFS_Rz, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_Slider, .dwOfs = DIJOYSTATEOFS_Slider_0, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_Slider, .dwOfs = DIJOYSTATEOFS_Slider_1, .dwType = win32_hid.DIDFT_AXIS | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = win32_hid.DIDOI_ASPECTPOSITION },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_POV, .dwOfs = DIJOYSTATEOFS_POV_0, .dwType = win32_hid.DIDFT_POV | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_POV, .dwOfs = DIJOYSTATEOFS_POV_1, .dwType = win32_hid.DIDFT_POV | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_POV, .dwOfs = DIJOYSTATEOFS_POV_2, .dwType = win32_hid.DIDFT_POV | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = &GUID_POV, .dwOfs = DIJOYSTATEOFS_POV_3, .dwType = win32_hid.DIDFT_POV | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_0, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_1, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_2, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_3, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_4, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_5, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_6, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_7, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_8, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_9, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_10, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_11, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_12, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_13, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_14, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_15, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_16, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_17, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_18, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_19, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_20, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_21, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_22, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_23, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_24, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_25, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_26, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_27, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_28, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_29, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_30, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
    win32_hid.DIOBJECTDATAFORMAT{ .pguid = null, .dwOfs = DIJOYSTATEOFS_Buttons_31, .dwType = win32_hid.DIDFT_BUTTON | DIDFT_OPTIONAL | win32_hid.DIDFT_ANYINSTANCE, .dwFlags = 0 },
};

const c_dfDIJoystick = win32_hid.DIDATAFORMAT{
    .dwSize = @sizeOf(win32_hid.DIDATAFORMAT),
    .dwObjSize = @sizeOf(win32_hid.DIOBJECTDATAFORMAT),
    .dwFlags = win32_hid.DIDFT_ABSAXIS,
    .dwDataSize = @sizeOf(win32_hid.DIJOYSTATE),
    .dwNumObjs = 44,
    .rgodf = @constCast(&JoyObjectDataFormat[0]), // why does this need a non const pointer.
};

const DInputObjectsType = enum {
    Axis,
    Slider,
    POV,
    Button,
};

fn objectCallback(object_ptr: ?*win32_hid.DIDEVICEOBJECTINSTANCEA, user_ptr: ?*anyopaque) callconv(winabi) BOOL {
    const data = @ptrCast(*ObjectEnumData, @alignCast(8, user_ptr));
    const object = object_ptr.?;
    if (object.dwType & win32_hid.DIDFT_AXIS != 0) {
        var slider: bool = false;
        var offset: u32 = undefined;
        if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_Slider.Bytes)) {
            offset = @offsetOf(win32_hid.DIJOYSTATE, "rglSlider") + data.joy_data.hid_data.slider_count * @sizeOf(i32);
            slider = true;
        } else if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_XAxis.Bytes)) {
            offset = DIJOYSTATEOFS_X;
        } else if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_YAxis.Bytes)) {
            offset = DIJOYSTATEOFS_Y;
        } else if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_ZAxis.Bytes)) {
            offset = DIJOYSTATEOFS_Z;
        } else if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_RxAxis.Bytes)) {
            offset = DIJOYSTATEOFS_Rx;
        } else if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_RyAxis.Bytes)) {
            offset = DIJOYSTATEOFS_Ry;
        } else if (std.mem.eql(u8, &object.guidType.Bytes, &GUID_RzAxis.Bytes)) {
            offset = DIJOYSTATEOFS_Rz;
        } else {
            return win32_hid.DIENUM_CONTINUE;
        }

        var prop_range: win32_hid.DIPROPRANGE = undefined;
        prop_range.diph.dwSize = @sizeOf(win32_hid.DIPROPRANGE);
        prop_range.diph.dwHeaderSize = @sizeOf(win32_hid.DIPROPHEADER);
        prop_range.diph.dwObj = object.dwType;
        prop_range.diph.dwHow = win32_hid.DIPH_BYID;
        prop_range.lMin = JoystickSubSystem.JOYSTICK_AXIS_MIN;
        prop_range.lMin = JoystickSubSystem.JOYSTICK_AXIS_MAX;

        if (data.joy_extra.dinput_device.?.IDirectInputDevice8A_SetProperty(@intToPtr(*GUID, 4), @ptrCast(*win32_hid.DIPROPHEADER, &prop_range)) < 0) {
            return win32_hid.DIENUM_CONTINUE;
        }

        if (slider) {
            data.joy_extra.dinput_objs.append(DInputObjects{
                .offs = offset,
                .type = DInputObjectsType.Slider,
            }) catch unreachable;
            data.joy_data.hid_data.slider_count += 1;
        } else {
            data.joy_extra.dinput_objs.append(DInputObjects{
                .offs = offset,
                .type = DInputObjectsType.Axis,
            }) catch unreachable;
            data.joy_data.hid_data.axis_count += 1;
        }
    } else if (object.dwType & win32_hid.DIDFT_BUTTON != 0) {
        data.joy_extra.dinput_objs.append(DInputObjects{
            .offs = @offsetOf(win32_hid.DIJOYSTATE, "rgbButtons") + data.joy_data.hid_data.buttons_count * @sizeOf(u8),
            .type = DInputObjectsType.Button,
        }) catch unreachable;
        data.joy_data.hid_data.buttons_count += 1;
    } else if (object.dwType & win32_hid.DIDFT_POV != 0) {
        data.joy_extra.dinput_objs.append(DInputObjects{
            .offs = @offsetOf(win32_hid.DIJOYSTATE, "rgdwPOV") + data.joy_data.hid_data.hats_count * @sizeOf(u32),
            .type = DInputObjectsType.POV,
        }) catch unreachable;
        data.joy_data.hid_data.hats_count += 1;
    }

    return win32_hid.DIENUM_CONTINUE;
}

fn enumCallback(instance_ptr: ?*win32_hid.DIDEVICEINSTANCEA, user_ptr: ?*anyopaque) callconv(winabi) BOOL {
    const jss = @ptrCast(*JoystickSubSystem, @alignCast(8, user_ptr));
    const instance = instance_ptr.?; // Should not be null.
    const slot = jss.emptyJoySlot() orelse {
        std.log.info("No more empty Joystick slots. Max is {}\n", .{JoystickSubSystem.JOYSTICK_MAX_COUNT});
        return win32_hid.DIENUM_STOP;
    };

    for (&jss.joys, 0..JoystickSubSystem.JOYSTICK_MAX_COUNT) |*joy, index| {
        if (joy.connected and std.mem.eql(u8, &jss.joys_exdata[index].instance_guid.Bytes, &instance.guidInstance.Bytes)) {
            return win32_hid.DIENUM_CONTINUE;
        }
    }

    if (isXInputDevice(&instance.guidProduct)) {
        // XInput api will handle this one.
        return win32_hid.DIENUM_CONTINUE;
    } else if (instance.dwDevType != win32_hid.DI8DEVTYPE_GAMEPAD and instance.dwDevType != win32_hid.DI8DEVTYPE_JOYSTICK) {
        return win32_hid.DIENUM_CONTINUE;
    }

    // Create a DirectInput device.
    var dinput_device: *win32_hid.IDirectInputDevice8A = undefined;
    if (jss.dapi.IDirectInput8A_CreateDevice(
        &instance.guidInstance,
        @ptrCast(*?*win32_hid.IDirectInputDevice8A, &dinput_device),
        null,
    ) != win32_hid.DI_OK) {
        std.log.err("Failed to create a DirectInput device.\n", .{});
        return win32_hid.DIENUM_CONTINUE;
    }

    // Set desired data format.
    if ((dinput_device.IDirectInputDevice8A_SetDataFormat(@constCast(&c_dfDIJoystick))) != win32_hid.DI_OK) {
        std.log.err("Failed to set DirectInput device data format.\n", .{});
        _ = dinput_device.IUnknown_Release();
        return win32_hid.DIENUM_CONTINUE;
    }

    // Get Device capabilities (button count, axis count,...etc).
    var device_caps: win32_hid.DIDEVCAPS = undefined;
    device_caps.dwSize = @sizeOf(win32_hid.DIDEVCAPS);
    if (dinput_device.IDirectInputDevice8A_GetCapabilities(&device_caps) != win32_hid.DI_OK) {
        std.log.err("Failed to get DirectInput device capabilities.\n", .{});
        _ = dinput_device.IUnknown_Release();
        return win32_hid.DIENUM_CONTINUE;
    }

    const extra_data = &jss.joys_exdata[slot];
    extra_data.dinput_device = dinput_device;
    extra_data.instance_guid = instance.guidInstance;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    extra_data.dinput_objs = std.ArrayList(DInputObjects).initCapacity(allocator, device_caps.dwAxes + device_caps.dwButtons + device_caps.dwPOVs) catch {
        std.log.err("Failed to get DirectInput device capabilities.\n", .{});
        _ = dinput_device.IUnknown_Release();
        return win32_hid.DIENUM_CONTINUE;
    };
    var callback_data = ObjectEnumData{
        .joy_data = &jss.joys[slot],
        .joy_extra = extra_data,
    };
    _ = dinput_device.IDirectInputDevice8A_EnumObjects(objectCallback, @ptrCast(*anyopaque, &callback_data), 0);

    var guid: [33]u8 = undefined;
    var guid_slice: []u8 = undefined;
    // https://github.com/gabomdq/SDL_GameControllerDB/issues/110
    if (std.mem.eql(u8, instance.guidProduct.Ints.d[2..], "PIDVID")) {
        guid_slice = std.fmt.bufPrint(
            &guid,
            "03000000{x:0>2}{x:0>2}0000{x:0>2}{x:0>2}000000000000",
            .{
                @truncate(u8, instance.guidProduct.Ints.a),
                @truncate(u8, instance.guidProduct.Ints.a >> 8),
                @truncate(u8, instance.guidProduct.Ints.a >> 16),
                @truncate(u8, instance.guidProduct.Ints.a >> 24),
            },
        ) catch unreachable;
    } else {
        guid_slice = std.fmt.bufPrint(
            &guid,
            "05000000{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}00",
            .{
                instance.tszInstanceName[0],
                instance.tszInstanceName[1],
                instance.tszInstanceName[2],
                instance.tszInstanceName[3],
                instance.tszInstanceName[4],
                instance.tszInstanceName[5],
                instance.tszInstanceName[6],
                instance.tszInstanceName[7],
                instance.tszInstanceName[8],
                instance.tszInstanceName[9],
                instance.tszInstanceName[10],
            },
        ) catch unreachable;
    }

    var name: []u8 = undefined;
    for (instance.tszInstanceName, 0..instance.tszInstanceName.len) |c, i| {
        if (c == 0) {
            name = instance.tszInstanceName[0..i];
            break;
        }
    }

    jss.initJoystick(
        slot,
        name,
        guid_slice,
        JoystickType.Generic,
    );
    _ = dinput_device.IDirectInputDevice8A_Acquire();
    // Notify
    jss.on_connection_change(slot, true, null);
    return win32_hid.DIENUM_CONTINUE;
}

pub const DInputObjects = struct {
    offs: u32,
    type: DInputObjectsType,
};

pub const DInputError = error{ FailedToCreateInterface, FailedToSetState };
pub const DInputDeviceInterface = *win32_hid.IDirectInputDevice8A;
pub const DInputInterface = *win32_hid.IDirectInput8A;

pub const DInputData = struct {
    device: DInputDeviceInterface,
    objects: std.ArrayList(DInputObjects),
    instance_guid: GUID,
};

pub const ObjectEnumData = struct {
    joy_extra: *DInputData,
    joy_data: *Joystick,
};

pub fn createInterface() !DInputInterface {
    var hinstance = try module.getProcessHandle();
    var interface: DInputInterface = undefined;
    const result = win32_hid.DirectInput8Create(
        hinstance,
        win32_hid.DIRECTINPUT_VERSION,
        win32_hid.IID_IDirectInput8A,
        @ptrCast(*?*anyopaque, &interface),
        null,
    );
    if (result != win32_hid.DI_OK) {
        std.log.err("Couldn't Create A DInput interface,error_code:{}\n", .{result});
        return DInputError.FailedToCreateInterface;
    }
    return interface;
}

pub inline fn releaseInterface(interface: DInputInterface) void {
    _ = interface.IUnknown_Release();
}

pub inline fn pollDevicesConnection(interface: DInputInterface, context: *anyopaque) void {
    _ = interface.IDirectInput8A_EnumDevices(
        win32_hid.DI8DEVCLASS_GAMECTRL,
        enumCallback,
        context,
        win32_hid.DIEDFL_ATTACHEDONLY,
    );
}

/// Returns false on failure
pub fn pollDeviceState(device: DInputDeviceInterface, objects: []DInputObjects, joy: *Joystick) bool {
    var dstate: win32_hid.DIJOYSTATE = undefined;
    _ = device.IDirectInputDevice8A_Poll();
    if (device.IDirectInputDevice8A_GetDeviceState(@sizeOf(win32_hid.DIJOYSTATE), &dstate) != win32_hid.DI_OK) {
        return false;
    }

    var axis_index: u8 = 0;
    var button_index: u8 = 0;
    var pov_index: u8 = 0;

    for (objects) |*obj| {
        // Whatever BlackMagic GLFW is doing in here.
        const data: *anyopaque = @ptrCast(*anyopaque, (@ptrCast([*]u8, &dstate) + obj.offs));
        switch (obj.type) {
            DInputObjectsType.Axis, DInputObjectsType.Slider => {
                const axis_data = @ptrCast(*i32, @alignCast(4, data));
                const value = (@intToFloat(f64, axis_data.*) + 0.5) / 32767.5;
                joy.axis[axis_index] = value;
                axis_index += 1;
            },
            DInputObjectsType.Button => {
                const button_data = @ptrCast(*u8, data);
                const value = if (button_data.* & 0x80 != 0) ButtonState.Press else ButtonState.Release;
                joy.buttons[button_index] = value;
                button_index += 1;
            },
            DInputObjectsType.POV => {
                const states = comptime [9]u8{
                    0x01,
                    0x01 | 0x02,
                    0x02,
                    0x04 | 0x02,
                    0x04,
                    0x04 | 0x08,
                    0x08,
                    0x01 | 0x08,
                    0x00,
                };
                const pov_data = @ptrCast(*u32, @alignCast(4, data));
                var state = loWord(pov_data.*) / (45 * win32_hid.DI_DEGREES);
                if (state < 0 or state > 8) {
                    state = 8;
                }
                // std.debug.print("Hid data:{}", .{joy.hid_data});
                const base = 10; //joy.hid_data.buttons_count + (pov_index * 4);
                joy.buttons[base + 1] = if (states[state] & 0x01 != 0) ButtonState.Press else ButtonState.Release; //up
                joy.buttons[base + 2] = if (states[state] & 0x02 != 0) ButtonState.Press else ButtonState.Release; //right
                joy.buttons[base + 3] = if (states[state] & 0x04 != 0) ButtonState.Press else ButtonState.Release; //down
                joy.buttons[base + 4] = if (states[state] & 0x08 != 0) ButtonState.Press else ButtonState.Release; //left
                pov_index += 1;
            },
        }
    }
    return true;
}
