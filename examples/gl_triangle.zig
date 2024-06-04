const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.keyboard.KeyCode;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

var gl_procs: widow.opengl.ProcTable = undefined;

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    // first we need to preform some platform specific initialization.
    try widow.initWidowPlatform();
    // clean up code to be called, when done using the library.
    // or don't let the os figure it's stuff.
    defer widow.deinitWidowPlatform();

    // create a WindowBuilder.
    var builder = widow.WindowBuilder.init();
    // customize the window.
    var mywindow = builder.withTitle("Hello OpenGL triangle")
        .withResize(false)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withSize(800, 600)
        .withDecoration(true)
        .build(allocator, 1) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // closes the window when done.
    defer mywindow.deinit();

    // the window will require an event queue to
    // send events.
    var ev_queue = EventQueue.init(allocator);
    defer ev_queue.deinit();

    _ = mywindow.setEventQueue(&ev_queue);

    var ctx = try mywindow.initGLContext(
        &.{ .ver = .{ .major = 3, .minor = 3 }, .profile = .Core },
    );
    defer ctx.deinit();
    _ = ctx.makeCurrent();

    if (!gl_procs.init(widow.opengl.loaderFunc)) return error.glInitFailed;

    widow.opengl.makeProcTableCurrent(&gl_procs);
    defer widow.opengl.makeProcTableCurrent(null);

    event_loop: while (true) {
        // sleeps until an event is postd.
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
                },
                EventType.WindowResize => |*new_size| {
                    widow.opengl.Viewport(0, 0, new_size.width, new_size.height);
                },
                else => continue,
            }
        }

        widow.opengl.Viewport(0, 0, 800, 600);
        widow.opengl.ClearColor(0.2, 0.3, 0.3, 1.0);
        widow.opengl.Clear(widow.opengl.COLOR_BUFFER_BIT);
        _ = ctx.swapBuffers();
    }
}
