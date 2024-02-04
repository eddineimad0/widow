const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();
    // first we need to preform some platform specific initialization.
    // an options tuple can be passed to customize the platform init
    // e.g on windows we can set the WNDClass name to a comptime string of our choice,
    try widow.initWidowPlatform(.{
        .xres_name = "SIMPLE_WINDOW",
        .xres_class = "SIMPLE_CLASS",
    });
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
        "Simple window",
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
        mywindow.waitEvent();

        while (widow_cntxt.pollEvents(&event)) {
            switch (event) {
                EventType.WindowClose => |window_id| {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    std.debug.print("closing Window #{}\n", .{window_id});
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    std.debug.print("Key Event:{}", .{key.*});
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
                EventType.WindowFocus => |*focus_event| {
                    // This event holds a boolean flag on whether the window got or lost focus.
                    std.debug.print("Focus ", .{});
                    if (focus_event.has_focus) {
                        std.debug.print("Gained", .{});
                    } else {
                        std.debug.print("Lost", .{});
                    }
                    std.debug.print("By window #{}\n", .{focus_event.window_id});
                },
                else => {
                    continue;
                },
            }
        }
    }
}
