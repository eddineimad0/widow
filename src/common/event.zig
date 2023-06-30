const std = @import("std");
const geometry = @import("geometry.zig");
const input = @import("keyboard_and_mouse.zig");
const joystick = @import("joystick.zig");

pub const EventType = enum(u8) {
    WindowClose, // The X icon on the window frame was pressed.
    WindowResize, // The window client area size was changed.
    Focus, // True/False if the window got keyboard focus.
    WindowMaximize, // The window was minimized.
    WindowMinimize, // The window was maximized.
    WindowMove, // The window has been moved, the Point2D struct specify the
    // new coordinates for the top left corner of the window.
    FileDrop, // Some file was released in the window area.
    KeyBoard, // A certain Keyboard key action(press or release) was performed.
    MouseButton, // A certain Mouse button action(press or release) was performed while the mouse is over the client area.
    MouseScroll, // One of the mouse wheels(vertical,horizontal) was scrolled.
    MouseMove, // The mouse position (relative to the client area's top left corner) changed.
    MouseEnter, // The mouse entered the client area of the window.
    MouseLeave, // The mouse exited the client area of the window.
    DPIChange, // DPI change due to the window being dragged to another monitor.
    Character, // The key pressed by the user generated a character.
    JoystickConnected, // Device inserted into the system.
    JoystickRemoved, // Device removed from the system.
    JoystickButtonAction, // Device button was pressed or released.
    JoystickAxisMotion, // Device Axis value changed.
    GamepadConnected, // Gamepad inserted.
    GamepadRemoved, // Gamepad removed.
    GamepadButtonAction, // Gamepad button was pressed or released.
    GamepadAxisMotion, // Gamepad axis value changed
};

pub const KeyEvent = struct {
    virtualcode: input.VirtualCode,
    scancode: input.ScanCode,
    state: input.KeyState,
    mods: input.KeyModifiers,
};

pub const MouseButtonEvent = struct {
    button: input.MouseButton,
    state: input.MouseButtonState,
    mods: input.KeyModifiers,
};

pub const WheelEvent = struct {
    wheel: input.MouseWheel,
    delta: f64,
};

pub const DPIChangeEvent = struct {
    dpi: u32,
    scaler: f64,
};

pub const CharacterEvent = struct {
    codepoint: u21,
    mods: input.KeyModifiers,
};

pub const Event = union(EventType) {
    WindowClose: void,
    WindowMaximize: void,
    WindowMinimize: void,
    MouseEnter: void,
    MouseLeave: void,
    FileDrop: void,
    Focus: bool,
    WindowResize: geometry.WidowSize,
    WindowMove: geometry.WidowPoint2D,
    MouseMove: geometry.WidowPoint2D,
    MouseButton: MouseButtonEvent,
    KeyBoard: KeyEvent,
    MouseScroll: WheelEvent,
    DPIChange: DPIChangeEvent,
    Character: CharacterEvent,
    JoystickConnected: u8, // Device inserted into the system.
    JoystickRemoved: u8, // Device removed from the system.
    JoystickButtonAction: joystick.JoyButtonEvent, // Device button was pressed or released.
    JoystickAxisMotion: joystick.JoyAxisEvent, // Device Axis value changed.
    GamepadConnected: u8, // Gamepad inserted.
    GamepadRemoved: u8, // Gamepad removed.
    GamepadButtonAction: joystick.GamepadButtonEvent, // Gamepad button was pressed or released.
    GamepadAxisMotion: joystick.GamepadAxisEvent, // Gamepad axis value changed
};

pub inline fn createCloseEvent() Event {
    return Event.WindowClose;
}

pub inline fn createMaximizeEvent() Event {
    return Event.WindowMaximize;
}

pub inline fn createMinimizeEvent() Event {
    return Event.WindowMinimize;
}

pub inline fn createMouseEnterEvent() Event {
    return Event.MouseEnter;
}

pub inline fn createMouseLeftEvent() Event {
    return Event.MouseLeave;
}

pub inline fn createDropFileEvent() Event {
    return Event.FileDrop;
}

pub inline fn createFocusEvent(focus: bool) Event {
    return Event{ .Focus = focus };
}

pub inline fn createResizeEvent(width: i32, height: i32) Event {
    return Event{ .WindowResize = geometry.WidowSize{ .width = width, .height = height } };
}

pub inline fn createMoveEvent(x: i32, y: i32) Event {
    return Event{ .WindowMove = geometry.WidowPoint2D{ .x = x, .y = y } };
}

pub inline fn createMouseMoveEvent(position: geometry.WidowPoint2D) Event {
    return Event{ .MouseMove = position };
}

pub inline fn createMouseButtonEvent(button: input.MouseButton, state: input.MouseButtonState, mods: input.KeyModifiers) Event {
    return Event{ .MouseButton = MouseButtonEvent{ .button = button, .state = state, .mods = mods } };
}

pub inline fn createKeyboardEvent(virtualcode: input.VirtualCode, scancode: input.ScanCode, state: input.KeyState, mods: input.KeyModifiers) Event {
    return Event{ .KeyBoard = KeyEvent{ .virtualcode = virtualcode, .scancode = scancode, .state = state, .mods = mods } };
}

pub inline fn createScrollEvent(wheel: input.MouseWheel, delta: f64) Event {
    return Event{ .MouseScroll = WheelEvent{ .wheel = wheel, .delta = delta } };
}

pub inline fn createDPIEvent(new_dpi: u32, new_scale: f64) Event {
    return Event{ .DPIChange = DPIChangeEvent{ .dpi = new_dpi, .scaler = new_scale } };
}

pub inline fn createCharEvent(codepoint: u32, mods: input.KeyModifiers) Event {
    return Event{ .Character = CharacterEvent{ .codepoint = @truncate(u21, codepoint), .mods = mods } };
}

pub inline fn createJoyConnectEvent(id: u8, gamepad: bool) Event {
    return if (gamepad) Event{ .GamepadConnected = id } else Event{ .JoystickConnected = id };
}

pub inline fn createJoyRemoveEvent(id: u8, gamepad: bool) Event {
    return if (gamepad) Event{ .GamepadRemoved = id } else Event{ .JoystickRemoved = id };
}

pub inline fn createJoyAxisEvent(id: u8, axis: u8, value: f32, gamepad: bool) Event {
    if (gamepad) {
        return Event{ .GamepadAxisMotion = joystick.GamepadAxisEvent{
            .joy_id = id,
            .axis = axis,
            .value = value,
        } };
    } else {
        return Event{ .JoystickAxisMotion = joystick.JoyAxisEvent{
            .joy_id = id,
            .axis = axis,
            .value = value,
        } };
    }
}

pub inline fn createJoyButtonEvent(id: u8, button: u8, state: joystick.ButtonState, gamepad: bool) Event {
    if (gamepad) {
        return Event{ .GamepadButtonAction = joystick.GamepadButtonEvent{
            .joy_id = id,
            .button = button,
            .state = state,
        } };
    } else {
        return Event{ .JoystickButtonAction = joystick.JoyButtonEvent{
            .joy_id = id,
            .button = button,
            .state = state,
        } };
    }
}
