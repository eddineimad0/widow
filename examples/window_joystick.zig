const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const ScanCode = widow.input.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const allocator = std.heap.c_allocator;

pub fn main() !void {
    var context = try widow.WidowContext.init(allocator);
    defer context.deinit();
    var builder = try widow.window.WindowBuilder.init("Simple window", 800, 600, &context);
    var window = try builder.build();
    defer window.deinit();

    // By default the joystick sub system isn't initialized .
    // and can only be deinitialized during context.deinit().
    try context.initJoystickSubSyst();

    var event: widow.event.Event = undefined;
    event_loop: while (true) {
        context.updateJoystick(0);
        while (context.pollJoyEvent(&event)) {
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
                    std.debug.print("\nButton number :{}\n", .{button_event.button});
                    std.debug.print("\nButton state :{}\n", .{button_event.state});
                },
                EventType.GamepadAxisMotion => |*axis_event| {
                    const analog_dead_zone = 0.2;
                    if (axis_event.value < analog_dead_zone and axis_event.value > -0.2) {
                        continue;
                    }
                    std.debug.print("\nJoy Id :{}\n", .{axis_event.joy_id});
                    std.debug.print("\nAxis number :{}\n", .{axis_event.axis});
                    std.debug.print("\nAxis value :{d}\n", .{axis_event.value});
                },
                EventType.GamepadConnected => |id| {
                    const name = context.joystickName(id) orelse unreachable;
                    std.debug.print("\n{s} #{}  Connected\n", .{ name, id });
                },
                EventType.GamepadRemoved => |id| {
                    std.debug.print("\n Gamepad #{} Removed\n", .{id});
                },
                else => {
                    continue;
                },
            }
        }

        while (window.pollEvent(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    break :event_loop;
                },
                EventType.GamepadConnected => |id| {
                    const name = context.joystickName(id) orelse unreachable;
                    std.debug.print("\n{s} #{}  Connected\n", .{ name, id });
                },
                EventType.GamepadRemoved => |id| {
                    std.debug.print("\n Gamepad #{} Removed\n", .{id});
                },
                else => {
                    continue :event_loop;
                },
            }
        }
    }
}
