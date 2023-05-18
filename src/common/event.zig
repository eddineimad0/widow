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
    DropFiles, // Some file was released in the window area.
    KeyBoardEvent, // A certain Keyboard action was performed.
    MouseButtonEvent, // A certain Mouse action was performed.
    MouseScroll, // One of the mouse wheels(vertical,horizontal) was scrolled.
    MouseMoved, // The mouse position changed inside the client area.
    RawMouseMove, // For windows that enable raw mouse motion,the data specifes the
    // raw offset from the previous mouse position.
    MouseEntered, // The mouse entered the client window frame
    MouseLeft, // The mouse exited the window frame
    DPIChange, // DPI change.
    Character, // The key pressed by the user maps to a character.
};

pub const KeyEvent = struct {
    virtual_code: input.VirtualKey,
    scan_code: input.ScanCode,
    action: input.KeyAction,
    mods: input.KeyModifiers,
};

pub const MouseEvent = struct {
    button: input.MouseButton,
    action: input.MouseButtonAction,
    mods: input.KeyModifiers,
};

pub const WheelEvent = struct {
    wheel: input.MouseWheel,
    delta: f64,
};

pub const DPIChangeEvent = struct {
    new_dpi: u32,
    scale_factor: f64,
};

pub const CharacterEvent = struct {
    unicode_char: u32,
    mods: input.KeyModifiers,
};

pub const Event = union(EventType) {
    WindowClose: void,
    WindowMaximize: void,
    WindowMinimize: void,
    MouseEntered: void,
    MouseLeft: void,
    Focus: bool,
    WindowResize: geometry.WidowSize,
    WindowMove: geometry.WidowPoint2D,
    MouseMoved: geometry.WidowPoint2D,
    RawMouseMove: geometry.WidowPoint2D,
    KeyBoardEvent: KeyEvent,
    MouseButtonEvent: MouseEvent,
    MouseScroll: WheelEvent,
    DPIChange: DPIChangeEvent,
    Character: CharacterEvent,
    DropFiles: []std.fs.path,
};

pub inline fn create_close_event() Event {
    return Event.WindowClose;
}
pub inline fn create_maximize_event() Event {
    return Event.WindowMaximize;
}
pub inline fn create_minimize_event() Event {
    return Event.WindowMinimize;
}
pub inline fn create_mouse_enter_event() Event {
    return Event.MouseEntered;
}
pub inline fn create_mouse_left_event() Event {
    return Event.MouseLeft;
}
pub inline fn create_focus_event(focus: bool) Event {
    return Event{ .Focus = focus };
}
