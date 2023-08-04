const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const allocator = std.heap.c_allocator;

pub fn main() void {
    // first we need to preform some platform specific initialization.
    widow.initWidowPlatform(.{}) catch {
        std.debug.print("Failed to start Widow library\n", .{});
    };
    // clean up code to be called, when done using the library.
    defer widow.deinitWidowPlatform();

    var widow_lib = widow.WidowContext.create(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_lib.destroy(allocator);

    // Grab the library's WindowBuilder instance.
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "joystick",
        800,
        600,
        widow_lib,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create our window,
    var window = builder.build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // deinitialize when done.
    defer window.deinit();

    var joy_array = std.ArrayList(u8).init(allocator);
    defer joy_array.deinit();

    // create an instance of the JoystickSubSystem.
    var joy_sys = widow.JoystickSubSystem.create(allocator, widow_lib) catch |err| {
        std.debug.print("Failed to initialize the JoystickSubSystem,{}\n", .{err});
        return;
    };
    // destroy when done.
    defer joy_sys.destroy(allocator);

    var event: widow.Event = undefined;
    event_loop: while (true) {
        window.processEvents();

        for (joy_array.items) |joy_id| {
            joy_sys.updateJoyState(joy_id);
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
                // Possible joystick events.
                // `GamepadConnected` // Gamepad inserted.
                // `GamepadRemoved` // Gamepad removed.
                // `GamepadButtonAction` // Gamepad button was pressed or released.
                // `GamepadAxisMotion` // Gamepad axis value changed
                EventType.GamepadButtonAction => |*button_event| {
                    const button: widow.joystick.XboxButton = @enumFromInt(button_event.button);
                    std.debug.print("\nJoy Id :{}\n", .{button_event.joy_id});
                    std.debug.print("Button {} | number :{}\n", .{ button, button_event.button });
                    std.debug.print("Button state :{}\n", .{button_event.state});
                    if (button_event.button == @intFromEnum(widow.joystick.XboxButton.A) and
                        button_event.state.isPressed())
                    {
                        _ = joy_sys.rumbleJoystick(button_event.joy_id, 3000);
                    }
                    if (button_event.button == @intFromEnum(widow.joystick.XboxButton.B) and
                        button_event.state.isPressed())
                    {
                        std.debug.print("Joy:#{} battery state:{}\n", .{ button_event.joy_id, joy_sys.joystickBattery(button_event.joy_id) });
                    }
                    if (button_event.button == @intFromEnum(widow.joystick.XboxButton.Y) and
                        button_event.state.isPressed())
                    {
                        _ = joy_sys.rumbleJoystick(button_event.joy_id, 0);
                    }
                },
                EventType.GamepadAxisMotion => |*axis_event| {
                    const analog_dead_zone = 0.2;

                    if (axis_event.axis != @intFromEnum(widow.joystick.XboxAxis.LTrigger) and
                        axis_event.axis != @intFromEnum(widow.joystick.XboxAxis.RTrigger))
                    {
                        // analog axis will always report a value different than 0
                        // even if they're not being moved(idle)
                        // consider using a dead zone to filter analog inputs.
                        if (axis_event.value < analog_dead_zone and axis_event.value > -analog_dead_zone) {
                            continue;
                        }
                    }

                    const axis: widow.joystick.XboxAxis = @enumFromInt(axis_event.axis);
                    std.debug.print("\nJoy Id :{}\n", .{axis_event.joy_id});
                    std.debug.print("Axis {} | number {}\n", .{ axis, axis_event.axis });
                    std.debug.print("Axis value :{d}\n", .{axis_event.value});
                },
                EventType.GamepadConnected => |id| {
                    const name = joy_sys.joystickName(id) orelse unreachable;
                    std.debug.print("\n{s} #{}  Connected\n", .{ name, id });
                    // we need to save the id so we can update the joystick later.
                    joy_array.append(id) catch |err| {
                        std.debug.print("Couldn't save joystick id {}\n", .{err});
                    };
                },
                EventType.GamepadRemoved => |id| {
                    std.debug.print("\n Gamepad #{} Removed\n", .{id});
                    // joystick ids start from 0 and goes up so it is the same as the index.
                    _ = joy_array.swapRemove(id);
                },
                else => {
                    continue :event_loop;
                },
            }
        }
    }
}
