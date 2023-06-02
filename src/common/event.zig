const std = @import("std");
const geometry = @import("./geometry.zig");
const input = @import("./input.zig");

pub const EventType = enum(u8) {
    WindowClose, // The X on the window frame was pressed.
    WindowResize, // The window client area size was changed.
    Focus, // True/False if the window got keyboard focus.
    WindowMaximize, // The window was minimized.
    WindowMinimize, // The window was maximized.
    WindowMove, // The window has been moved, the Point2D struct specify the
    // new coordinates for the top left corner of the window.
    FileDrop, // Some file was released in the window area.
    KeyBoard, // A certain Keyboard action was performed.
    MouseButton, // A certain Mouse button action was performed while the mouse is over the client area.
    MouseScroll, // One of the mouse wheels(vertical,horizontal) was scrolled.
    MouseMove, // The mouse position (relative to the client area's top left corner) changed.
    RawMouseMove, // For windows that enable raw mouse motion,the data specifes the
    // raw offset from the previous mouse position.
    MouseEnter, // The mouse entered the client area of the window.
    MouseLeave, // The mouse exited the client area of the window.
    DPIChange, // DPI change.
    Character, // The key pressed by the user maps to a character.
};

pub const KeyEvent = struct {
    virtualcode: input.VirtualKey,
    scancode: input.ScanCode,
    action: input.KeyAction,
    mods: input.KeyModifiers,
};

pub const MouseButtonEvent = struct {
    button: input.MouseButton,
    action: input.MouseButtonAction,
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
    Focus: bool,
    WindowResize: geometry.WidowSize,
    WindowMove: geometry.WidowPoint2D,
    MouseMove: geometry.WidowPoint2D,
    RawMouseMove: geometry.WidowPoint2D,
    MouseButton: MouseButtonEvent,
    KeyBoard: KeyEvent,
    MouseScroll: WheelEvent,
    DPIChange: DPIChangeEvent,
    Character: CharacterEvent,
    FileDrop: []std.fs.path,
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
pub inline fn createFocusEvent(focus: bool) Event {
    return Event{ .Focus = focus };
}
pub inline fn createResizeEvent(width: i32, height: i32) Event {
    return Event{ .WindowResize = geometry.WidowSize{ .width = width, .height = height } };
}
pub inline fn createMoveEvent(x: i32, y: i32) Event {
    return Event{ .WindowMove = geometry.WidowPoint2D{ .x = x, .y = y } };
}
pub inline fn createMouseMoveEvent(position: geometry.WidowPoint2D, raw: bool) Event {
    if (raw) {
        return Event{ .RawMouseMove = position };
    } else {
        return Event{ .MouseMove = position };
    }
}
pub inline fn createMouseButtonEvent(button: input.MouseButton, action: input.MouseButtonAction, mods: input.KeyModifiers) Event {
    return Event{ .MouseButton = MouseButtonEvent{ .button = button, .action = action, .mods = mods } };
}
pub inline fn createKeyboardEvent(virtualcode: input.VirtualKey, scancode: input.ScanCode, action: input.KeyAction, mods: input.KeyModifiers) Event {
    return Event{ .KeyBoard = KeyEvent{ .virtualcode = virtualcode, .scancode = scancode, .action = action, .mods = mods } };
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
