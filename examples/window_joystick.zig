const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const ScanCode = widow.input.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const allocator = std.heap.c_allocator;

pub fn main() void {
    var widow_lib = widow.WidowContext.create(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_lib.destroy(allocator);

    // Grab the library's WindowBuilder instance.
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "Simple window",
        800,
        600,
        widow_lib,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create our window,
    var window = builder.withDPIScaling(false).build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // deinitialize when done.
    defer window.deinit();

    var joy_array = std.ArrayList(u8).init(allocator);
    defer joy_array.deinit();

    // By default the joystick sub system isn't initialized .
    // and can only be deinitialized during context.deinit().
    widow_lib.initJoystickSubSyst() catch |err| {
        std.debug.print("Failed to initialize the JoystickSubSystem,{}\n", .{err});
        return;
    };

    var event: widow.Event = undefined;
    event_loop: while (true) {
        window.processEvents();
        for (joy_array.items) |joy_id| {
            widow_lib.updateJoystick(joy_id);
        }
        while (widow_lib.pollJoyEvent(&event)) {
            // Possible joystick events.
            // `JoystickConnected` // Device inserted into the system.
            // `JoystickRemoved` // Device removed from the system.
            // `JoystickButtonAction` // Device button was pressed or released.
            // `JoystickAxisMotion` // Device Axis value changed.
            // `GamepadConnected` // Gamepad inserted.
            // `GamepadRemoved` // Gamepad removed.
            // `GamepadButtonAction` // Gamepad button was pressed or released.
            // `GamepadAxisMotion` // Gamepad axis value changed
            switch (event) {
                EventType.GamepadButtonAction => |*button_event| {
                    std.debug.print("\nJoy Id :{}\n", .{button_event.joy_id});
                    std.debug.print("Button {} | number :{}\n", .{ @intToEnum(widow.joystick.XboxButton, button_event.button), button_event.button });
                    std.debug.print("Button state :{}\n", .{button_event.state});
                },
                EventType.GamepadAxisMotion => |*axis_event| {
                    const analog_dead_zone = 0.2;
                    if (axis_event.value < analog_dead_zone and axis_event.value > -0.2) {
                        continue;
                    }
                    std.debug.print("\nJoy Id :{}\n", .{axis_event.joy_id});
                    std.debug.print("Axis {} | number {}\n", .{ @intToEnum(widow.joystick.XboxAxis, axis_event.axis), axis_event.axis });
                    std.debug.print("Axis value :{d}\n", .{axis_event.value});
                },
                EventType.GamepadConnected => |id| {
                    const name = widow_lib.joystickName(id) orelse unreachable;
                    std.debug.print("\n{s} #{}  Connected\n", .{ name, id });
                    joy_array.append(id) catch |err| {
                        std.debug.print("Couldn't save joystick id {}\n", .{err});
                    };
                },
                EventType.GamepadRemoved => |id| {
                    std.debug.print("\n Gamepad #{} Removed\n", .{id});
                    // the id is the same as the index.
                    _ = joy_array.swapRemove(id);
                },
                else => {
                    continue;
                },
            }
        }

        while (widow_lib.pollEvents(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    break :event_loop;
                },
                else => {
                    continue :event_loop;
                },
            }
        }
    }
}
