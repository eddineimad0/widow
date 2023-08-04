const std = @import("std");
pub const ButtonState = @import("keyboard_and_mouse.zig").KeyState;

pub const JOYSTICK_MAX_COUNT = 4;

/// Struct for holding human interface devices generic data.
const HIDData = struct {
    name: []u8, // device name
    buttons_count: u8,
    axis_count: u8,
};

pub const GenericButton = enum(u8) {
    Button1 = 0,
    Button2,
    Button3,
    Button4,
    Button5,
    Button6,
    Button7,
    Button8,
    Button9,
    Button10,
    Button11,
    Button12,
    Button13,
    Button14,
    Button15,
    Button16,
};

const BUTTONS_COUNT = 16;

pub const GenericAxis = enum(u8) {
    Axis1 = 0,
    Axis2,
    Axis3,
    Axis4,
    Axis5,
    Axis6,
};

const AXES_COUNT = 6;

pub const XboxButton = enum(u8) {
    A = 0,
    B,
    X,
    Y,
    LBumper,
    RBumper,
    Back,
    Start,
    LStickButton,
    RStickButton,
    DpadUp,
    DpadRight,
    DpadDown,
    DpadLeft,
};

pub const XboxAxis = enum(u8) {
    LeftX = 0,
    LeftY,
    RightX,
    RightY,
    LTrigger,
    RTrigger,
};

pub const BatteryInfo = enum(u8) {
    PowerUnkown,
    PowerEmpty,
    PowerLow,
    PowerMedium,
    PowerFull,
    Wired,
};

pub const Joystick = struct {
    axes: std.ArrayList(f32),
    buttons: std.ArrayList(ButtonState),
    hid_data: HIDData,
    connected: bool,
    is_gamepad: bool,
    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        a_count: u8,
        b_count: u8,
        is_gamepad: bool,
    ) !Self {
        var self: Self = undefined;
        self.hid_data = HIDData{
            .name = try allocator.alloc(u8, name.len),
            .axis_count = a_count,
            .buttons_count = b_count,
        };
        errdefer allocator.free(self.hid_data.name);
        self.axes = try std.ArrayList(f32).initCapacity(allocator, a_count);
        errdefer self.axes.deinit();
        self.buttons = try std.ArrayList(ButtonState).initCapacity(allocator, b_count);
        @memcpy(self.hid_data.name, name);
        @memset(self.axes.items, 0.0);
        @memset(self.buttons.items, ButtonState.Released);
        // So we can assign by index without panics.
        self.axes.resize(self.axes.capacity) catch unreachable;
        self.buttons.resize(self.buttons.capacity) catch unreachable;
        self.is_gamepad = is_gamepad;
        self.connected = true;
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Hack as to not store the allocator.
        self.buttons.allocator.free(self.hid_data.name);
        self.buttons.deinit();
        self.axes.deinit();
        self.connected = false;
    }

    pub fn setAxis(self: *Self, axis: u8, value: f32) bool {
        std.debug.assert(axis < self.hid_data.axis_count and axis < AXES_COUNT);

        if (std.math.fabs(self.axes.items[axis] - value) < std.math.floatEps(f32)) {
            return false;
        }
        self.axes.items[axis] = value;
        return true;
    }

    pub inline fn setButton(self: *Self, button: u8, value: ButtonState) bool {
        std.debug.assert(button < self.hid_data.buttons_count and button < BUTTONS_COUNT);
        if (self.buttons.items[button] == value) {
            return false;
        }
        self.buttons.items[button] = value;
        return true;
    }
};

pub const JoyAxisEvent = struct {
    joy_id: u8,
    axis: u8,
    value: f32,
};

pub const JoyButtonEvent = struct {
    joy_id: u8,
    button: u8,
    state: ButtonState,
};

pub const GamepadAxisEvent = JoyAxisEvent;
pub const GamepadButtonEvent = JoyButtonEvent;
