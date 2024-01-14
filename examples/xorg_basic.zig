const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const VirtualCode = widow.keyboard_and_mouse.VirtualCode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var allocator = gpa.allocator();
    // first we need to preform some platform specific initialization.
    // an options tuple can be passed to customize the platform init
    // e.g on windows we can set the WNDClass name to a comptime string of our choice,
    try widow.initWidowPlatform(.{});
    // clean up code to be called, when done using the library.
    defer widow.deinitWidowPlatform();

    var widow_cntxt = widow.WidowContext.init(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_cntxt.deinit();

    // create a WindowBuilder.
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "Xorg window",
        800,
        600,
        &widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create the window,
    var mywindow = builder.build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // closes the window when done.
    defer mywindow.deinit();

    var event: widow.Event = undefined;

    event_loop: while (true) {
        mywindow.processEvents();
        while (widow_cntxt.pollEvents(&event)) {
            switch (event) {
                // Possible Events
                // WindowClose => The X icon on the window frame was pressed.
                // WindowResize => The window client area size was changed.
                // WindowShown, => The window was shown to the user.
                // WindowHidden, => The window was hidden from the user.
                // WindowFocus => True/False if the window got keyboard focus.
                // WindowMaximize => The window was minimized.
                // WindowMinimize => The window was maximized.
                // WindowMove => The window has been moved, the Point2D struct specify the
                // // new coordinates for the top left corner of the window.
                // FileDrop => Some file was released in the window area.
                // KeyBoard => A certain Keyboard key action(press or release) was performed.
                // MouseButton, => A certain Mouse button action(press or release) was performed while
                // the mouse is over the client area.
                // MouseScroll => One of the mouse wheels(vertical,horizontal) was scrolled.
                // MouseMove => The mouse position (relative to the client area's top left corner) changed.
                // MouseEnter => The mouse entered the client area of the window.
                // MouseLeave => The mouse exited the client area of the window.
                // DPIChange => DPI change due to the window being dragged to another monitor.
                // Character => The key pressed by the user generated a character.

                EventType.WindowClose => |window_id| {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    std.debug.print("closing Window #{}\n", .{window_id});
                    break :event_loop;
                },
                EventType.MouseButton => |*mouse_event| {
                    // This event holds the mouse button (left,middle,right,...),
                    // the action that was done to the button (pressed or released),
                    // and the keymodifiers state during the event pressed(true) or released(false).
                    std.debug.print("Window #{}\nMouse Button:{}\nState:{}\nmods:{}\n", .{
                        mouse_event.window_id,
                        mouse_event.button,
                        mouse_event.state,
                        mouse_event.mods,
                    });
                },
                EventType.MouseScroll => |*scroll| {
                    // This event holds the Wheel (horizontal or vertical) that was scrolled and by how much (delta).
                    std.debug.print("Window #{}\nwheel:{} Scrolled by :{d}\n", .{
                        scroll.window_id,
                        scroll.wheel,
                        scroll.delta,
                    });
                },
                EventType.MouseEnter => |window_id| {
                    std.debug.print("Mouse Entered the client area of window #{}\n", .{window_id});
                },
                EventType.MouseLeave => |window_id| {
                    std.debug.print("Mouse Left the client area window #{}\n", .{window_id});
                },
                else => {},
            }
        }
    }

    const mywindow_title = try mywindow.title(allocator);
    defer allocator.free(mywindow_title);
    std.debug.print("Closing window {s}\n", .{mywindow_title});
}
