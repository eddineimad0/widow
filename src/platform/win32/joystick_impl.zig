const std = @import("std");
const joystick = @import("common").joystick;
const dinput = @import("dinput.zig");
const xinput = @import("xinput.zig");
const winapi = @import("win32");

pub const JoystickAPI = enum { XInput, DInput };

pub const Win32JoyData = union(JoystickAPI) {
    // DirectInput data.
    DInput: dinput.DInputData,
    // XInput data.
    XInput: xinput.XInputData,
};

pub const JoystickSubSystem = struct {
    allocator: std.mem.Allocator, // For initializing joysticks
    dapi: dinput.DInputInterface,
    xapi: xinput.XInputInterface,
    joys: [joystick.JOYSTICK_MAX_COUNT]joystick.Joystick,
    joys_exdata: [joystick.JOYSTICK_MAX_COUNT]Win32JoyData,
    on_connection_change: joystick.JoystickConnectCallBack,
    pub const JOYSTICK_AXIS_MAX = 32767;
    pub const JOYSTICK_AXIS_MIN = -32768;
    const Self = @This();

    pub inline fn initJoystick(self: *Self, slot: u8, name: []const u8, guid: []const u8, joy_type: joystick.JoystickType) void {
        std.debug.print("\nJoystick Name {s}\n", .{name});
        std.debug.print("\nJoystick GUID {s}\n", .{guid});
        const joy = &self.joys[slot];
        std.mem.copyForwards(u8, &joy.hid_data.name, name);
        std.mem.copyForwards(u8, &joy.hid_data.guid, guid);
        joy.type = joy_type;
        // joy.hid_data.buttons_count = button_count;
        // joy.hid_data.axis_count = axis_count;
        // joy.hid_data.hats_count = hats_count;
        joy.connected = true;
    }

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
        self.on_connection_change(joy_id, self.joys[joy_id].hid_data.name, false, null);
        // ! Don't deinit before notifying the user, the name pointer will be freed.
        self.joys[joy_id].deinit();
    }

    pub fn create(allocator: std.mem.Allocator, on_connection_change: joystick.JoystickConnectCallBack) !*Self {
        var self: *Self = try allocator.create(Self);
        self.dapi = try dinput.createInterface();
        self.xapi = try xinput.XInputInterface.init();

        for (0..joystick.JOYSTICK_MAX_COUNT) |i| {
            const joy = &self.joys[i];
            joy.connected = false;
            // const ex_data = &self.joys_exdata[i];
            // ex_data.dinput_device = null;
            // ex_data.packet_number = 0;
        }
        self.on_connection_change = on_connection_change;
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
        allocator.destroy(self);
    }

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
    }

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
};

fn dummyHandler(id: u8, name: []const u8, state: bool, user_ptr: ?*anyopaque) void {
    _ = user_ptr;
    std.debug.print("\nJoy {s} | #id {} | connected {}\n", .{ name, id, state });
}

test "Joystick sub system" {
    const testing = std.testing;
    var jss = try JoystickSubSystem.create(
        testing.allocator,
        dummyHandler,
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
            std.time.sleep(std.time.ns_per_s * 1);
        }
    }
}
