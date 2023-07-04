const std = @import("std");
const joystick = @import("common").joystick;
const common_event = @import("common").event;
const EventQueue = @import("common").event.EventQueue;
const dinput = @import("dinput.zig");
const xinput = @import("xinput.zig");

pub const JoystickAPI = enum { XInput, DInput };

/// Holds Platform-API-dependent data for the coresponding joystick.
pub const Win32JoyData = union(JoystickAPI) {
    // DirectInputAPI data.
    DInput: dinput.DInputData,
    // XInputAPI data.
    XInput: xinput.XInputData,
};

/// Provides an interface for managing connected joysticks.
pub const JoystickSubSystemImpl = struct {
    allocator: std.mem.Allocator, // For initializing joysticks
    dapi: dinput.DInputInterface,
    xapi: xinput.XInputInterface,
    joys: [joystick.JOYSTICK_MAX_COUNT]joystick.Joystick,
    joys_exdata: [joystick.JOYSTICK_MAX_COUNT]Win32JoyData,
    events_queue_ref: *EventQueue,
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
        self.joys[joy_id].deinit();
        // create the event.
        const event = common_event.createJoyRemoveEvent(joy_id, self.joys[joy_id].is_gamepad);
        self.queueEvent(&event);
    }

    pub fn init(allocator: std.mem.Allocator, event_dst: *EventQueue) !Self {
        var self: Self = undefined;
        // TODO: Are these apis available on most current versions windows
        self.dapi = try dinput.createInterface();
        self.xapi = try xinput.XInputInterface.init();

        for (0..joystick.JOYSTICK_MAX_COUNT) |i| {
            const joy = &self.joys[i];
            // the connected flag is checked before use to avoid using undefined data.
            joy.connected = false;
        }
        self.events_queue_ref = event_dst;
        self.allocator = allocator;
        return self;
    }

    pub fn deinit(self: *Self) void {
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            if (self.joys[joy_id].connected) {
                self.deinitJoystick(@truncate(u8, joy_id));
            }
        }
        dinput.releaseInterface(self.dapi);
        self.xapi.deinit();
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

    pub inline fn queueEvent(self: *Self, event: *const common_event.Event) void {
        self.events_queue_ref.sendEvent(event);
    }

    pub fn pollEvent(self: *Self, event: *common_event.Event) bool {
        const oldest_event = self.events_queue.get() orelse return false;
        event.* = oldest_event.*;

        // always return true.
        return self.events_queue.removeFront();
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
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            // TODO why isn't this connected
            if (self.joys[joy_id].connected) {
                switch (self.joys_exdata[joy_id]) {
                    JoystickAPI.XInput => |*xdata| {
                        if (!xinput.pollPadPresence(&self.xapi, xdata.id)) {
                            self.deinitJoystick(@truncate(u8, joy_id));
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
        }
    }

    /// Update the state for the given joystick id.
    pub fn updateJoystickState(self: *Self, joy_id: u8) bool {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            std.log.warn("[Joystick]: Bad joystick id,{}", .{joy_id});
            return false;
        }

        // const joy = &self.joys[joy_id];
        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                if (!xinput.pollPadState(self, joy_id, xdata)) {
                    self.deinitJoystick(joy_id);
                    return false;
                }
            },
            JoystickAPI.DInput => |_| {
                // if (!dinput.pollDeviceState(ddata.device, ddata.objects.items, joy)) {
                //     // Failed to get state device is disconnected.
                //     self.deinitJoystick(joy_id);
                // }
            },
        }
        return true;
    }

    pub fn joystickName(self: *const Self, joy_id: u8) ?[]const u8 {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            std.log.warn("[Joystick]: Bad joystick id,{}", .{joy_id});
            return null;
        }
        return self.joys[joy_id].hid_data.name;
    }

    pub fn joystickBatteryInfo(self: *Self, joy_id: u8) joystick.BatteryInfo {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            std.log.warn("[Joystick]: Bad joystick id,{}", .{joy_id});
            return joystick.BatteryInfo.PowerUnkown;
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
        return joystick.BatteryInfo.PowerUnkown;
    }

    pub fn rumbleJoystick(self: *Self, joy_id: u8, magnitude: u16) bool {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            return false;
        }

        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                xinput.rumble(&self.xapi, xdata, magnitude) catch return false;
            },
            JoystickAPI.DInput => |_| {
                // if (!dinput.pollDeviceState(ddata.device, ddata.objects.items, joy)) {
                //     // Failed to get state device is disconnected.
                //     self.deinitJoystick(joy_id);
                // }
            },
        }

        return true;
    }
};
