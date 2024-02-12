const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const DrawingBackend = widow.DrawingBackend;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();
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
        "opengl window",
        800,
        600,
        &widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create the window,
    var glwindow = builder.build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };
    // No longer nedded.
    builder.deinit();
    // closes the window when done.
    defer glwindow.deinit();

    try glwindow.initDrawingContext(DrawingBackend.OpenGL);
    _ = glwindow.MakeDrawingContextCurrent();

    var event: widow.Event = undefined;
    event_loop: while (true) {
        glwindow.waitEvent();

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
                    if (key.state.isPressed() and key.keycode == .Q) {
                        // let's request closing the window on pressing Q key
                        glwindow.queueCloseEvent();
                    }
                },
                else => {
                    continue;
                },
            }
        }

        _ = glwindow.swapBuffers();
    }
}
