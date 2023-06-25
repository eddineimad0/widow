const std = @import("std");
pub const ButtonState = @import("keyboard_and_mouse.zig").KeyState;

pub const JOYSTICK_MAX_COUNT = 4;

/// Struct for holding human interface devices generic data.
const HIDData = struct {
    name: []u8, // device name
    buttons_count: u8,
    axis_count: u8,
    hats_count: u8,
};

pub const JoystickType = enum(u8) {
    Generic = 0,
    Xbox,
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

pub const GenericHat = enum(u8) {
    Hat1 = 0, // Usually the POV Hat or Dpad.
    Hat2,
    Hat3,
    Hat4,
};

const HATS_COUNT = 4;

pub const HatState = enum(u8) {
    Center = 0,
    Up = 1,
    Right = 2,
    Down = 4,
    Left = 8,
};

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
    DpadLeft,
    DpadDown,
    DpadRight,
};

pub const XboxAxis = enum(u8) {
    LeftX = 0,
    LeftY,
    RightX,
    RightY,
    LTrigger,
    RTrigger,
};

pub const Joystick = struct {
    axes: std.ArrayList(f64),
    buttons: std.ArrayList(ButtonState),
    connected: bool,
    type: JoystickType,
    hid_data: HIDData,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8, joy_type: JoystickType, a_count: u8, b_count: u8, h_count: u8) !Self {
        var self: Self = undefined;
        self.hid_data = HIDData{
            .name = try allocator.alloc(u8, name.len),
            .axis_count = a_count,
            .buttons_count = b_count,
            .hats_count = h_count,
        };
        errdefer allocator.free(self.hid_data.name);
        std.debug.print("acount:{},bcount:{},hcount:{}\n", .{ a_count, b_count, h_count });
        self.axes = try std.ArrayList(f64).initCapacity(allocator, a_count);
        errdefer self.axes.deinit();
        // consider 4 buttons for each hat.
        self.buttons = try std.ArrayList(ButtonState).initCapacity(allocator, b_count + (h_count << 2));
        @memcpy(self.hid_data.name, name);
        @memset(self.axes.items, 0.0);
        @memset(self.buttons.items, ButtonState.Released);
        // So we can assign be index without panics.
        self.axes.resize(self.axes.capacity) catch unreachable;
        self.buttons.resize(self.buttons.capacity) catch unreachable;
        self.type = joy_type;
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

    pub fn setAxis(self: *Self, axis: u8, value: f64) void {
        std.debug.assert(axis < self.hid_data.axis_count and axis < AXES_COUNT);
        self.axes.items[axis] = value;
    }

    pub inline fn setButton(self: *Self, button: u8, value: ButtonState) void {
        std.debug.assert(button < self.hid_data.buttons_count and button < BUTTONS_COUNT);
        self.buttons.items[button] = value;
    }

    pub fn setHat(self: *Self, hat: u8, value: u8) void {
        std.debug.assert(hat < self.hid_data.hats_count and hat < HATS_COUNT);
        const base = self.hid_data.buttons_count + (hat << 2);
        std.debug.assert(base < self.buttons.items.len - 3);
        // UP
        self.buttons.items[base] = if (value & 0x01 != 0) ButtonState.Pressed else ButtonState.Released;
        // RIGHT
        self.buttons.items[base + 1] = if (value & 0x02 != 0) ButtonState.Pressed else ButtonState.Released;
        // DOWN
        self.buttons.items[base + 2] = if (value & 0x04 != 0) ButtonState.Pressed else ButtonState.Released;
        // LEFT
        self.buttons.items[base + 3] = if (value & 0x08 != 0) ButtonState.Pressed else ButtonState.Released;
    }
};

pub const JoystickConnectCallBack = *const fn (joy_id: u8, name: []const u8, connected: bool, user_ptr: ?*anyopaque) void;
