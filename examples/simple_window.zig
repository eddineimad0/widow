const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.keyboard.KeyCode;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    // first we need to preform some platform specific initialization.
    // and build a context for the current platform.
    // TODO: between the 2 calls ctx is undefined fix that
    // and enforce that the ctx address can't change.
    const ctx = try allocator.create(widow.WidowContext);
    defer allocator.destroy(ctx);
    ctx.* = try widow.WidowContext.init();

    // create a WindowBuilder.
    var builder = widow.WindowBuilder.init();
    // customize the window.
    var mywindow = builder.withTitle("Simple Window")
        .withSize(800, 600)
        .withResize(true)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withDecoration(true)
        .build(allocator, ctx, null) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // closes the window when done.
    defer mywindow.deinit(allocator);

    // the window will require an event queue to
    // send events.
    var ev_queue = EventQueue.init(allocator);
    defer ev_queue.deinit();

    _ = mywindow.setEventQueue(&ev_queue);

    event_loop: while (true) {
        // sleeps until an event is posted.
        try mywindow.waitEvent();

        var event: widow.event.Event = undefined;

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => |window_id| {
                    std.debug.print("closing Window #{}\n", .{window_id});
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    if (key.state.isPressed()) {
                        if (key.keycode == KeyCode.Q) {
                            // let's request closing the window on
                            // pressing Q key
                            mywindow.queueCloseEvent();
                        }
                    }
                    std.debug.print("Window #{}\nKeycode:{}\nScancode:{}\nState:{}\nmods:{}\n", .{
                        key.window_id,
                        key.keycode,
                        key.scancode,
                        key.state,
                        key.mods,
                    });
                },
                EventType.Character => |*char| {
                    // This event holds a unicode character codepoint and keymodifers that were pressed
                    // during the event.
                    std.debug.print("target window #{},character:'{u}'\nmods:{}\n", .{
                        char.window_id,
                        char.codepoint,
                        char.mods,
                    });
                },

                EventType.MouseMove => |*pos| {
                    std.debug.print("Mouse position (x:{},y:{})\n", .{ pos.x, pos.y });
                },

                EventType.WindowMove => |*pos| {
                    std.debug.print("Window position (x:{},y:{})\n", .{ pos.x, pos.y });
                },

                EventType.WindowResize => |*sz| {
                    std.debug.print("Window size (w:{},h:{})\n", .{ sz.width, sz.height });
                },

                EventType.WindowFocus => |foc_ev| {
                    if (foc_ev.has_focus) {
                        std.debug.print("Focused on window:{}\n", .{foc_ev.window_id});
                    } else {
                        std.debug.print("Lost focus on window:{}\n", .{foc_ev.window_id});
                    }
                },

                EventType.MouseEnter => std.debug.print("Mouse Entered window\n", .{}),
                EventType.MouseExit => std.debug.print("Mouse Left window\n", .{}),

                else => continue,
            }
        }
    }
}
