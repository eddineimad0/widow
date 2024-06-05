const std = @import("std");
const mem = std.mem;
const geometry = @import("geometry.zig");
const kbd_mouse = @import("keyboard_mouse.zig");

const KeyEvent = kbd_mouse.KeyEvent;
const KeyModifiers = kbd_mouse.KeyModifiers;
const MouseButtonEvent = kbd_mouse.MouseButtonEvent;
const WheelEvent = kbd_mouse.WheelEvent;
const Queue = @import("queue.zig").Queue;

pub const EventType = enum(u8) {
    WindowClose, // The X icon on the window frame was pressed.
    WindowShown, // The window was shown to the user.
    WindowHidden, // The window was hidden from the user.
    WindowMaximize, // The window was minimized.
    WindowMinimize, // The window was maximized.
    WindowRestore, // The window was restored(from minimized or maximized state).
    MouseEnter, // The mouse entered the client area of the window.
    MouseLeave, // The mouse exited the client area of the window.
    FileDrop, // Some file was released in the window area.
    RedrawRequest, // Request from the system to redraw the window's client area.
    WindowFocus, // True/False if the window got keyboard focus.
    WindowResize, // The window client area size was changed.
    WindowMove, // The window has been moved, the Point2D struct specify the
    // new coordinates for the top left corner of the window.
    MouseMove, // The mouse position (relative to the client area's top left corner) changed.
    MouseButton, // A certain Mouse button action(press or release) was performed while the mouse is over the client area.
    KeyBoard, // A certain Keyboard key action(press or release) was performed.
    MouseScroll, // One of the mouse wheels(vertical,horizontal) was scrolled.
    DPIChange, // DPI change due to the window being dragged to another monitor.
    Character, // The key pressed by the user generated a character.
};

pub const ResizeEvent = struct {
    window_id: u32,
    width: u32,
    height: u32,
};

pub const MoveEvent = struct {
    window_id: u32,
    x: i32,
    y: i32,
};

pub const DPIChangeEvent = struct {
    window_id: u32,
    dpi: u32,
    scaler: f64,
};

pub const CharacterEvent = struct {
    window_id: u32,
    codepoint: u21,
    mods: KeyModifiers,
};

pub const FocusEvent = struct {
    window_id: u32,
    has_focus: bool,
};

pub const Event = union(EventType) {
    WindowClose: u32,
    WindowShown: u32,
    WindowHidden: u32,
    WindowMaximize: u32,
    WindowMinimize: u32,
    WindowRestore: u32,
    MouseEnter: u32,
    MouseLeave: u32,
    FileDrop: u32,
    RedrawRequest: u32,
    WindowFocus: FocusEvent,
    WindowResize: ResizeEvent,
    WindowMove: MoveEvent,
    MouseMove: MoveEvent,
    MouseButton: MouseButtonEvent,
    KeyBoard: KeyEvent,
    MouseScroll: WheelEvent,
    DPIChange: DPIChangeEvent,
    Character: CharacterEvent,
};

pub inline fn createCloseEvent(window_id: u32) Event {
    return .{ .WindowClose = window_id };
}

pub inline fn createVisibilityEvent(window_id: u32, shown: bool) Event {
    if (shown) {
        return .{ .WindowShown = window_id };
    } else {
        return .{ .WindowHidden = window_id };
    }
}

pub inline fn createMaximizeEvent(window_id: u32) Event {
    return .{ .WindowMaximize = window_id };
}

pub inline fn createMinimizeEvent(window_id: u32) Event {
    return .{ .WindowMinimize = window_id };
}

pub inline fn createRestoreEvent(window_id: u32) Event {
    return .{ .WindowRestore = window_id };
}

pub inline fn createMouseEnterEvent(window_id: u32) Event {
    return .{ .MouseEnter = window_id };
}

pub inline fn createMouseLeftEvent(window_id: u32) Event {
    return .{ .MouseLeave = window_id };
}

pub inline fn createDropFileEvent(window_id: u32) Event {
    return .{ .FileDrop = window_id };
}

pub inline fn createRedrawEvent(window_id: u32) Event {
    return .{ .RedrawRequest = window_id };
}

pub inline fn createFocusEvent(window_id: u32, focus: bool) Event {
    return .{ .WindowFocus = FocusEvent{
        .window_id = window_id,
        .has_focus = focus,
    } };
}

pub inline fn createResizeEvent(window_id: u32, width: i32, height: i32) Event {
    return .{ .WindowResize = ResizeEvent{
        .window_id = window_id,
        .width = width,
        .height = height,
    } };
}

pub inline fn createMoveEvent(window_id: u32, x: i32, y: i32, is_mouse: bool) Event {
    return if (!is_mouse)
        .{ .WindowMove = MoveEvent{
            .window_id = window_id,
            .x = x,
            .y = y,
        } }
    else
        .{ .MouseMove = MoveEvent{
            .window_id = window_id,
            .x = x,
            .y = y,
        } };
}

pub inline fn createMouseButtonEvent(
    window_id: u32,
    button: kbd_mouse.MouseButton,
    state: kbd_mouse.MouseButtonState,
    mods: kbd_mouse.KeyModifiers,
) Event {
    return .{ .MouseButton = MouseButtonEvent{
        .window_id = window_id,
        .button = button,
        .state = state,
        .mods = mods,
    } };
}

pub inline fn createKeyboardEvent(
    window_id: u32,
    keycode: kbd_mouse.KeyCode,
    scancode: kbd_mouse.ScanCode,
    state: kbd_mouse.KeyState,
    mods: kbd_mouse.KeyModifiers,
) Event {
    return .{ .KeyBoard = KeyEvent{
        .window_id = window_id,
        .keycode = keycode,
        .scancode = scancode,
        .state = state,
        .mods = mods,
    } };
}

pub inline fn createScrollEvent(
    window_id: u32,
    wheel: kbd_mouse.MouseWheel,
    delta: f64,
) Event {
    return .{ .MouseScroll = WheelEvent{
        .window_id = window_id,
        .wheel = wheel,
        .delta = delta,
    } };
}

pub inline fn createDPIEvent(window_id: u32, new_dpi: u32, new_scale: f64) Event {
    return .{ .DPIChange = DPIChangeEvent{
        .window_id = window_id,
        .dpi = new_dpi,
        .scaler = new_scale,
    } };
}

pub inline fn createCharEvent(
    window_id: u32,
    codepoint: u32,
    mods: kbd_mouse.KeyModifiers,
) Event {
    return .{ .Character = CharacterEvent{
        .window_id = window_id,
        .codepoint = @truncate(codepoint),
        .mods = mods,
    } };
}

pub const EventQueue = struct {
    queue: Queue(Event),
    const Self = @This();

    /// initializes an event Queue For the window.
    /// call deinit when done
    /// # parameters
    /// 'allocator': used for the queue's heap allocations.
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .queue = Queue(Event).init(allocator),
        };
    }

    /// frees all queued events.
    pub fn deinit(self: *Self) void {
        self.queue.deinit();
    }

    pub fn queueEvent(self: *Self, event: *const Event) mem.Allocator.Error!void {
        return self.queue.append(event);
    }

    pub fn popEvent(self: *Self, event: *Event) bool {
        const first = self.queue.get() orelse return false;
        event.* = first.*;
        return self.queue.removeFront();
    }
};
