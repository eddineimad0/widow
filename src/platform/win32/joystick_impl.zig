const std = @import("std");
const joystick = @import("common").joystick;
const common_event = @import("common").event;
const LinkedList = @import("common").list.LinkedList;
const dinput = @import("dinput.zig");
const xinput = @import("xinput.zig");
const WindowImpl = @import("window_impl.zig").WindowImpl;

pub const JoystickAPI = enum { XInput, DInput };

/// Holds Platform-API-dependent data for the coresponding joystick.
pub const Win32JoyData = union(JoystickAPI) {
    // DirectInputAPI data.
    DInput: dinput.DInputData,
    // XInputAPI data.
    XInput: xinput.XInputData,
};

pub const JoystickError = error{BadId};

/// Provides an interface for managing connected joysticks.
pub const JoystickSubSystem = struct {
    allocator: std.mem.Allocator, // For initializing joysticks
    dapi: dinput.DInputInterface,
    xapi: xinput.XInputInterface,
    joys: [joystick.JOYSTICK_MAX_COUNT]joystick.Joystick,
    joys_exdata: [joystick.JOYSTICK_MAX_COUNT]Win32JoyData,
    listeners: LinkedList(*WindowImpl),
    pub const JOYSTICK_AXIS_MAX = 32767;
    pub const JOYSTICK_AXIS_MIN = -32768;
    const Self = @This();

    fn deinitJoystick(self: *Self, joy_id: u8) void {
        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.DInput => |*ddata| {
                _ = ddata.device.IDirectInputDevice8A_Unacquire();
                _ = ddata.device.IUnknown_Release();
                ddata.objects.deinit();
            },
            else => {},
        }
        // Notify
        const event = common_event.createJoyRemoveEvent(joy_id, self.joys[joy_id].type.isGamepad());
        self.notifyListeners(&event);
        self.joys[joy_id].deinit();
    }

    fn cmpListeners(window_a: *const *WindowImpl, window_b: *const *WindowImpl) bool {
        return window_a.* == window_b.*;
    }

    pub fn create(allocator: std.mem.Allocator) !*Self {
        var self: *Self = try allocator.create(Self);
        // TODO: Are these apis available on most current versions windows
        self.dapi = try dinput.createInterface();
        self.xapi = try xinput.XInputInterface.init();

        for (0..joystick.JOYSTICK_MAX_COUNT) |i| {
            const joy = &self.joys[i];
            // the connected flag is checked before use to avoid using undefined data.
            joy.connected = false;
        }
        self.listeners = LinkedList(*WindowImpl).init(allocator);
        self.allocator = allocator;
        return self;
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            if (self.joys[joy_id].connected) {
                self.deinitJoystick(@truncate(u8, joy_id));
            }
        }
        dinput.releaseInterface(self.dapi);
        self.xapi.deinit();
        self.listeners.deinit();
        allocator.destroy(self);
    }

    pub fn addListener(self: *Self, window: *WindowImpl) !void {
        try self.listeners.append(&window);
    }

    pub fn removeListener(self: *Self, window: *WindowImpl) bool {
        const index = self.listeners.find(&window, &cmpListeners) orelse return false;
        return self.listeners.removeAt(index);
    }

    pub fn notifyListeners(self: *Self, event: *const common_event.Event) void {
        for (0..self.listeners.len) |i| {
            const listener = self.listeners.getAt(i).?.*;
            listener.queueEvent(event);
        }
    }

    /// Returns an index to an empty slot in the joysticks array, null if the array is full
    /// # Note
    /// The maximum number of supported joysticks that can be connected at a given time,
    /// is defined in [`common.joystick.JOYSTICK_MAX_COUNT`].
    pub inline fn emptyJoySlot(self: *const Self) ?u8 {
        var indx: u8 = 0;
        while (indx < joystick.JOYSTICK_MAX_COUNT) {
            if (!self.joys[indx].connected) {
                return indx;
            }
            indx += 1;
        }
        return null;
    }

    /// Detect any new connected joystick.
    pub fn queryConnectedJoys(self: *Self) void {
        // XInput polling.
        xinput.pollPadsConnection(self);
        // DInput polling.
        // dinput.pollDevicesConnection(self.dapi, @ptrCast(*anyopaque, self));
    }

    /// Detect if any old joystick was disconnected.
    pub fn queryDisconnectedJoys(self: *Self) void {
        _ = self;
        // TODO:
    }

    /// Update the state for the given joystick id.
    pub fn queryJoystickState(self: *Self, joy_id: u8) void {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            return;
        }

        const joy = &self.joys[joy_id];
        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                if (!xinput.pollPadState(&self.xapi, joy, xdata)) {
                    self.deinitJoystick(joy_id);
                }
            },
            JoystickAPI.DInput => |_| {
                // if (!dinput.pollDeviceState(ddata.device, ddata.objects.items, joy)) {
                //     // Failed to get state device is disconnected.
                //     self.deinitJoystick(joy_id);
                // }
            },
        }
    }

    pub fn queryJoystickBattery(self: *Self, joy_id: u8) !joystick.BatteryInfo {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            return JoystickError.BadId;
        }

        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                return xinput.batteryInfo(&self.xapi, xdata);
            },
            JoystickAPI.DInput => |_| {
                // if (!dinput.pollDeviceState(ddata.device, ddata.objects.items, joy)) {
                //     // Failed to get state device is disconnected.
                //     self.deinitJoystick(joy_id);
                // }
            },
        }
        return error.NonCapableDevice;
    }

    pub fn rumbleJoystick(self: *Self, joy_id: u8, low_freq: u16, hi_freq: u16) !void {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            return JoystickError.BadId;
        }

        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                return xinput.rumble(&self.xapi, xdata, low_freq, hi_freq);
            },
            JoystickAPI.DInput => |_| {
                // if (!dinput.pollDeviceState(ddata.device, ddata.objects.items, joy)) {
                //     // Failed to get state device is disconnected.
                //     self.deinitJoystick(joy_id);
                // }
            },
        }
        return error.NonCapableDevice;
    }
};

test "Joystick sub system" {
    const testing = std.testing;
    var jss = try JoystickSubSystem.create(
        testing.allocator,
    );
    jss.queryConnectedJoys();
    std.debug.print("\nSize of jss:{}\n", .{@sizeOf(JoystickSubSystem)});
    std.debug.print("Bit size of jss:{}\n", .{@bitSizeOf(JoystickSubSystem)});
    while (true) {
        for (jss.joys, 0..jss.joys.len) |joy, id| {
            if (!joy.connected) {
                break;
            }
            jss.queryJoystickState(@truncate(u8, id));
            std.debug.print("--------joy:{}------\n", .{id});
            std.debug.print("buttons:{any}\n", .{joy.buttons});
            std.debug.print("axis L:{d}|{d}\n", .{ joy.axes.items[0], joy.axes.items[1] });
            std.debug.print("axis R:{d}|{d}\n", .{ joy.axes.items[2], joy.axes.items[3] });
            std.debug.print("axis T:{d}|{d}\n", .{ joy.axes.items[4], joy.axes.items[5] });
            const button_a = joy.buttons.items[@enumToInt(joystick.XboxButton.A)];
            const button_b = joy.buttons.items[@enumToInt(joystick.XboxButton.B)];
            if (button_a.isPressed()) {
                jss.rumbleJoystick(@truncate(u8, id), 69, 420) catch {
                    std.debug.print("\nrumble feature unsupported\n", .{});
                };
            }
            if (button_b.isPressed()) {
                const state = jss.queryJoystickBattery(@truncate(u8, id)) catch {
                    std.debug.print("\nBattery info feature unsupported\n", .{});
                    continue;
                };
                std.debug.print("\nBattery state for controller {} is {}\n", .{ id, state });
            }
            std.time.sleep(std.time.ns_per_s * 1);
        }
    }
}
