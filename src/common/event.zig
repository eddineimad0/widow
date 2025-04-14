const std = @import("std");
const mem = std.mem;
const geometry = @import("geometry.zig");
const kbd_mouse = @import("keyboard_mouse.zig");

const KeyEvent = kbd_mouse.KeyEvent;
const KeyModifiers = kbd_mouse.KeyModifiers;
const MouseButtonEvent = kbd_mouse.MouseButtonEvent;
const ScrollEvent = kbd_mouse.ScrollEvent;
const Deque = @import("deque.zig").Deque;
const WindowId = usize;

pub const EventType = enum(u8) {
    WindowClose, // The X icon on the window frame was pressed.
    WindowShown, // The window was shown to the user.
    WindowHidden, // The window was hidden from the user.
    WindowMaximize, // The window was minimized.
    WindowMinimize, // The window was maximized.
    WindowRestore, // The window was restored(from minimized or maximized state).
    MouseEnter, // The mouse entered the client area of the window.
    MouseExit, // The mouse exited the client area of the window.
    FileDrop, // Some file was released in the window area.
    RedrawRequest, // Request from the system to redraw the window's client area.
    WindowFocus, // True/False if the window got keyboard focus.
    WindowResize, // The window client area size was changed.
    WindowMove, // The window has been moved, the Point2D struct specify the
    // new coordinates for the top left corner of the window.
    MouseMove, // The mouse position (relative to the client area's top left corner) changed.
    MouseButton, // A certain Mouse button action(press or release) was performed while the mouse is over the client area.
    Keyboard, // A certain Keyboard key action(press or release) was performed.
    MouseScroll, // One of the mouse wheels(vertical,horizontal) was scrolled.
    DPIChange, // DPI change due to the window being dragged to another monitor.
    Character, // The key pressed by the user generated a character.
};

pub const ResizeEvent = struct {
    window_id: WindowId,
    width: i32, // new client width,
    height: i32, // new client height,
};

pub const MoveEvent = struct {
    window_id: WindowId,
    x: i32, // new x coordinat of the top left corner
    y: i32, // new y coordinate of the top left corner
};

pub const DPIChangeEvent = struct {
    window_id: WindowId,
    dpi: u32, // new display dpi
    scaler: f64,
};

pub const CharacterEvent = struct {
    window_id: WindowId,
    codepoint: u21, // utf8 character codepoint
    mods: KeyModifiers, // state of mod keys (shift,ctrl,caps-lock...)
};

pub const FocusEvent = struct {
    window_id: WindowId,
    has_focus: bool, // true gained focus else lost focus.
};

pub const Event = union(EventType) {
    WindowClose: WindowId,
    WindowShown: WindowId,
    WindowHidden: WindowId,
    WindowMaximize: WindowId,
    WindowMinimize: WindowId,
    WindowRestore: WindowId,
    MouseEnter: WindowId,
    MouseExit: WindowId,
    FileDrop: WindowId,
    RedrawRequest: WindowId,
    WindowFocus: FocusEvent,
    WindowResize: ResizeEvent,
    WindowMove: MoveEvent,
    MouseMove: MoveEvent,
    MouseButton: MouseButtonEvent,
    Keyboard: KeyEvent,
    MouseScroll: ScrollEvent,
    DPIChange: DPIChangeEvent,
    Character: CharacterEvent,
};

pub inline fn createCloseEvent(window_id: WindowId) Event {
    return .{ .WindowClose = window_id };
}

pub inline fn createVisibilityEvent(window_id: WindowId, shown: bool) Event {
    if (shown) {
        return .{ .WindowShown = window_id };
    } else {
        return .{ .WindowHidden = window_id };
    }
}

pub inline fn createMaximizeEvent(window_id: WindowId) Event {
    return .{ .WindowMaximize = window_id };
}

pub inline fn createMinimizeEvent(window_id: WindowId) Event {
    return .{ .WindowMinimize = window_id };
}

pub inline fn createRestoreEvent(window_id: WindowId) Event {
    return .{ .WindowRestore = window_id };
}

pub inline fn createMouseEnterEvent(window_id: WindowId) Event {
    return .{ .MouseEnter = window_id };
}

pub inline fn createMouseExitEvent(window_id: WindowId) Event {
    return .{ .MouseExit = window_id };
}

pub inline fn createDropFileEvent(window_id: WindowId) Event {
    return .{ .FileDrop = window_id };
}

pub inline fn createRedrawEvent(window_id: WindowId) Event {
    return .{ .RedrawRequest = window_id };
}

pub inline fn createFocusEvent(window_id: WindowId, focus: bool) Event {
    return .{ .WindowFocus = FocusEvent{
        .window_id = window_id,
        .has_focus = focus,
    } };
}

pub inline fn createResizeEvent(window_id: WindowId, width: i32, height: i32) Event {
    return .{ .WindowResize = ResizeEvent{
        .window_id = window_id,
        .width = width,
        .height = height,
    } };
}

pub inline fn createMoveEvent(window_id: WindowId, x: i32, y: i32, is_mouse: bool) Event {
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
    window_id: WindowId,
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
    window_id: WindowId,
    keycode: kbd_mouse.KeyCode,
    scancode: kbd_mouse.ScanCode,
    state: kbd_mouse.KeyState,
    mods: kbd_mouse.KeyModifiers,
) Event {
    return .{ .Keyboard = KeyEvent{
        .window_id = window_id,
        .keycode = keycode,
        .scancode = scancode,
        .state = state,
        .mods = mods,
    } };
}

pub inline fn createScrollEvent(
    window_id: WindowId,
    delta_x: f64,
    delta_y: f64,
) Event {
    return .{ .MouseScroll = ScrollEvent{
        .window_id = window_id,
        .x_offset = delta_x,
        .y_offset = delta_y,
    } };
}

pub inline fn createDPIEvent(window_id: WindowId, new_dpi: u32, new_scale: f64) Event {
    return .{ .DPIChange = DPIChangeEvent{
        .window_id = window_id,
        .dpi = new_dpi,
        .scaler = new_scale,
    } };
}

pub inline fn createCharEvent(
    window_id: WindowId,
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
    queue: Deque(Event),
    allocator:mem.Allocator,
    initial_capacity:usize,
    const Self = @This();

    /// initializes an event Queue For the window.
    /// call deinit when done
    /// # parameters
    /// 'allocator': used for the queue's heap allocations.
    /// 'initial_capacity': the initial capacity of the queue, shouldn't be zero.
    pub fn init(allocator: std.mem.Allocator,initial_capacity:usize) (mem.Allocator.Error||error{CapacityZero})!Self {
        return .{
            .queue = try Deque(Event).init(allocator,initial_capacity),
            .allocator = allocator,
            .initial_capacity = initial_capacity,
        };
    }

    /// frees all queued events.
    pub fn deinit(self: *Self) void {
        self.queue.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn queueEvent(self: *Self, event: *const Event) mem.Allocator.Error!void {
        try self.queue.pushBack(self.allocator, event);
    }

    pub fn popEvent(self: *Self, event: *Event) bool {
        const ok = self.queue.popFront(event);
        if(!ok and self.queue.getCapacity() > 4 * self.initial_capacity){
            // can only fail due to allocation failure, if so ignore
            _ = self.queue.shrinkCapacity(self.allocator, self.initial_capacity) catch true;
        }
        return ok;
    }
};
