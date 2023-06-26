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

    // Only windows registered as listeners may receive joystick events.
    try context.addJoystickListener(&window);

    // The window should unsubscribe from the joystick listeners before it gets deinitialized.
    // and destroyed, otherwise we'll be working with non-valid pointers i.e undefined behaviour.
    defer _ = context.removeJoystickListener(&window);

    var event: widow.event.Event = undefined;
    event_loop: while (true) {
        if (!window.pollEvent(&event)) {
            continue :event_loop;
        }

        // Possible joystick events.
        // `JoystickConnected` // Device inserted into the system.
        // `JoystickRemoved` // Device removed from the system.
        // `JoystickButtonAction` // Device button was pressed or released.
        // `JoystickAxisMotion` // Device Axis value changed.
        // `JoystickHatMotion` // Device hat position changed.
        // `GamepadConnected` // Gamepad inserted.
        // `GamepadRemoved` // Gamepad removed.
        // `GamepadButtonAction` // Gamepad button was pressed or released.
        // `GamepadAxisMotion` // Gamepad axis value changed
        switch (event) {
            EventType.WindowClose => {
                // The user has requested to close the window,
                // and the application should proceed to calling deinit on the window instance.
                // This is merely a notification nothing is done to window in the background,
                // ignore it if you want to continue execution as normal.
                break :event_loop;
            },
            EventType.GamepadConnected => |id| {
                std.debug.print("\nGamepad #{} Connected\n", .{id});
                // TODO add methods for interfacing with joystick
            },
            EventType.GamepadRemoved => |id| {
                std.debug.print("\nGamepad #{} Removed\n", .{id});
                // TODO add methods for interfacing with joystick
            },
            else => {
                continue :event_loop;
            },
        }
    }
}
