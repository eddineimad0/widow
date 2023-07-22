const std = @import("std");
const joystick = @import("common").joystick;
const common_event = @import("common").event;
const EventQueue = @import("common").event.EventQueue;
const xinput = @import("xinput.zig");

// Future API to come
pub const JoystickAPI = enum { XInput };

/// Holds Platform-API-dependent data for the coresponding joystick.
pub const Win32JoyData = union(JoystickAPI) {
    // XInputAPI data.
    XInput: xinput.XInputData,
};

/// Provides an interface for managing connected joysticks.
pub const JoystickSubSystemImpl = struct {
    allocator: std.mem.Allocator, // For initializing joysticks
    xapi: xinput.XInputInterface,
    joys: [joystick.JOYSTICK_MAX_COUNT]joystick.Joystick,
    joys_exdata: [joystick.JOYSTICK_MAX_COUNT]Win32JoyData,
    events_queue_ref: *EventQueue,
    const Self = @This();

    fn deinitJoystick(self: *Self, joy_id: u8) void {
        self.joys[joy_id].deinit();
        // create the event.
        const event = common_event.createJoyRemoveEvent(joy_id, self.joys[joy_id].is_gamepad);
        self.sendEvent(&event);
    }

    pub fn setup(instance: *Self, allocator: std.mem.Allocator, event_dst: *EventQueue) !void {
        instance.xapi = try xinput.XInputInterface.init();

        for (0..joystick.JOYSTICK_MAX_COUNT) |i| {
            const joy = &instance.joys[i];
            // the connected flag is checked before use to avoid using undefined data.
            joy.connected = false;
        }
        instance.events_queue_ref = event_dst;
        instance.allocator = allocator;
    }

    pub fn deinit(self: *Self) void {
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            if (self.joys[joy_id].connected) {
                self.deinitJoystick(@truncate(u8, joy_id));
            }
        }
        self.xapi.deinit();
    }

    /// Returns an index to an empty slot in the joysticks array, null if the array is full
    /// # Note
    /// The maximum number of supported joysticks that can be connected at a given time,
    /// is defined in `common.joystick.JOYSTICK_MAX_COUNT`.
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

    pub inline fn sendEvent(self: *Self, event: *const common_event.Event) void {
        self.events_queue_ref.queueEvent(event);
    }

    /// Detect any new connected joystick.
    pub fn queryConnectedJoys(self: *Self) void {
        // XInput polling.
        xinput.pollPadsConnection(self);
    }

    /// Detect if any old joystick was disconnected.
    pub fn queryDisconnectedJoys(self: *Self) void {
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            if (self.joys[joy_id].connected) {
                switch (self.joys_exdata[joy_id]) {
                    JoystickAPI.XInput => |*xdata| {
                        if (!xinput.pollPadPresence(&self.xapi, xdata.id)) {
                            self.deinitJoystick(@truncate(u8, joy_id));
                        }
                    },
                }
            }
        }
    }

    /// Update the state for the given joystick id.
    pub fn updateJoystickState(self: *Self, joy_id: u8) void {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            std.log.warn("[Joystick]: Bad joystick id,{}", .{joy_id});
        }

        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                if (!xinput.pollPadState(self, joy_id, xdata)) {
                    self.deinitJoystick(joy_id);
                }
            },
        }
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
        }
    }

    pub fn rumbleJoystick(self: *Self, joy_id: u8, magnitude: u16) bool {
        if (joy_id < 0 or joy_id > joystick.JOYSTICK_MAX_COUNT or !self.joys[joy_id].connected) {
            return false;
        }

        switch (self.joys_exdata[joy_id]) {
            JoystickAPI.XInput => |*xdata| {
                xinput.rumble(&self.xapi, xdata, magnitude) catch return false;
            },
        }
        return true;
    }

    pub fn countConnected(self: *const Self) u8 {
        var count: u8 = 0;
        for (0..joystick.JOYSTICK_MAX_COUNT) |joy_id| {
            if (self.joys[joy_id].connected) {
                count += 1;
            }
        }

        return count;
    }
};
