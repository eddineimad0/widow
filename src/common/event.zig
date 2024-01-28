const std = @import("std");
const geometry = @import("geometry.zig");
const input = @import("keyboard_and_mouse.zig");
const KeyEvent = input.KeyEvent;
const KeyModifiers = input.KeyModifiers;
const MouseButtonEvent = input.MouseButtonEvent;
const WheelEvent = input.WheelEvent;
const Queue = @import("queue.zig").Queue;

pub const EventType = enum(u8) {
    WindowClose, // The X icon on the window frame was pressed.
    WindowResize, // The window client area size was changed.
    WindowFocus, // True/False if the window got keyboard focus.
    WindowShown, // The window was shown to the user.
    WindowHidden, // The window was hidden from the user.
    WindowMaximize, // The window was minimized.
    WindowMinimize, // The window was maximized.
    WindowRestore, // The window was restored(from minimized or maximized state).
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
    RedrawRequest, // Request from the system to redraw the window's client area.
};

pub const ResizeEvent = struct {
    window_id: u32,
    width: i32,
    height: i32,
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
    WindowFocus: FocusEvent,
    WindowResize: ResizeEvent,
    WindowMove: MoveEvent,
    MouseMove: MoveEvent,
    MouseButton: MouseButtonEvent,
    KeyBoard: KeyEvent,
    MouseScroll: WheelEvent,
    DPIChange: DPIChangeEvent,
    Character: CharacterEvent,
    RedrawRequest: u32,
};

pub inline fn createCloseEvent(window_id: u32) Event {
    return Event{ .WindowClose = window_id };
}

pub inline fn createVisibilityEvent(window_id: u32, shown: bool) Event {
    if (shown) {
        return Event{ .WindowShown = window_id };
    } else {
        return Event{ .WindowHidden = window_id };
    }
}

pub inline fn createMaximizeEvent(window_id: u32) Event {
    return Event{ .WindowMaximize = window_id };
}

pub inline fn createMinimizeEvent(window_id: u32) Event {
    return Event{ .WindowMinimize = window_id };
}

pub inline fn createRestoreEvent(window_id: u32) Event {
    return Event{ .WindowRestore = window_id };
}

pub inline fn createMouseEnterEvent(window_id: u32) Event {
    return Event{ .MouseEnter = window_id };
}

pub inline fn createMouseLeftEvent(window_id: u32) Event {
    return Event{ .MouseLeave = window_id };
}

pub inline fn createDropFileEvent(window_id: u32) Event {
    return Event{ .FileDrop = window_id };
}

pub inline fn createFocusEvent(window_id: u32, focus: bool) Event {
    return Event{ .WindowFocus = FocusEvent{
        .window_id = window_id,
        .has_focus = focus,
    } };
}

pub inline fn createResizeEvent(window_id: u32, width: i32, height: i32) Event {
    return Event{ .WindowResize = ResizeEvent{
        .window_id = window_id,
        .width = width,
        .height = height,
    } };
}

pub inline fn createMoveEvent(window_id: u32, x: i32, y: i32, is_mouse: bool) Event {
    return if (!is_mouse)
        Event{ .WindowMove = MoveEvent{
            .window_id = window_id,
            .x = x,
            .y = y,
        } }
    else
        Event{ .MouseMove = MoveEvent{
            .window_id = window_id,
            .x = x,
            .y = y,
        } };
}

pub inline fn createMouseButtonEvent(
    window_id: u32,
    button: input.MouseButton,
    state: input.MouseButtonState,
    mods: input.KeyModifiers,
) Event {
    return Event{ .MouseButton = MouseButtonEvent{
        .window_id = window_id,
        .button = button,
        .state = state,
        .mods = mods,
    } };
}

pub inline fn createKeyboardEvent(
    window_id: u32,
    keycode: input.KeyCode,
    scancode: input.ScanCode,
    state: input.KeyState,
    mods: input.KeyModifiers,
) Event {
    return Event{ .KeyBoard = KeyEvent{
        .window_id = window_id,
        .keycode = keycode,
        .scancode = scancode,
        .state = state,
        .mods = mods,
    } };
}

pub inline fn createScrollEvent(window_id: u32, wheel: input.MouseWheel, delta: f64) Event {
    return Event{ .MouseScroll = WheelEvent{
        .window_id = window_id,
        .wheel = wheel,
        .delta = delta,
    } };
}

pub inline fn createDPIEvent(window_id: u32, new_dpi: u32, new_scale: f64) Event {
    return Event{ .DPIChange = DPIChangeEvent{
        .window_id = window_id,
        .dpi = new_dpi,
        .scaler = new_scale,
    } };
}

pub inline fn createCharEvent(window_id: u32, codepoint: u32, mods: input.KeyModifiers) Event {
    return Event{ .Character = CharacterEvent{
        .window_id = window_id,
        .codepoint = @truncate(codepoint),
        .mods = mods,
    } };
}

pub inline fn createRedrawEvent(window_id: u32) Event {
    return Event{ .RedrawRequest = window_id };
}

pub const EventQueue = struct {
    queue: Queue(Event),
    events_count: usize,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .queue = Queue(Event).init(allocator),
            .events_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.queue.deinit();
        self.events_count = 0;
    }

    pub fn queueEvent(self: *Self, event: *const Event) void {
        self.queue.append(event) catch |err| {
            std.log.err("[Event]: Failed to Queue Event,{}\n", .{err});
            return;
        };
        self.events_count += 1;
    }

    pub fn popEvent(self: *Self, event: *Event) bool {
        const first = self.queue.get() orelse return false;
        event.* = first.*;
        self.events_count -= 1;
        return self.queue.removeFront();
    }
};
