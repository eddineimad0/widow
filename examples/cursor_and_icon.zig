const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const ScanCode = widow.keyboard.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const CursorShape = widow.cursor.StandardCursorShape;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    // first we need to preform some platform specific initialization.
    try widow.initWidowPlatform();
    // clean up code to be called, when done using the library.
    defer widow.deinitWidowPlatform();

    // Start by creating a WidowContext instance.
    // the context is at the heart of the library and keeps track of monitors,clipboard,events...
    // only one instance is needed but you can create as many as you need.
    var widow_cntxt = widow.WidowContext.init(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_cntxt.deinit();

    // create a WindowBuilder.
    var builder = widow.WindowBuilder.init(&widow_cntxt);
    // customize the window.
    var mywindow = builder.withTitle("Cursor & icon")
        .withSize(1024, 800)
        .withResize(true)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withSize(800, 600)
        .withDecoration(true)
        .build() catch |err| {
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

    // const icon_pixels = [_]u8{ 0xF7, 0xA4, 0x1D, 0xFF } ** (32 * 32);
    // mywindow.setIcon(&icon_pixels, 32, 32) catch {
    //     std.debug.print("Failed to set Window icon.\n", .{});
    // };

    var event: widow.event.Event = undefined;
    event_loop: while (true) {
        try mywindow.waitEvent();

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    if (key.state.isPressed()) {
                        switch (key.scancode) {
                            ScanCode.Q => {
                                // let's request closing the window on pressing Q key
                                mywindow.queueCloseEvent();
                            },
                            ScanCode.C => {
                                mywindow.setCursorMode(CursorMode.Captured);
                            },
                            ScanCode.H => {
                                mywindow.setCursorMode(CursorMode.Hidden);
                            },
                            ScanCode.N => {
                                mywindow.setCursorMode(CursorMode.Normal);
                            },
                            ScanCode.I => {
                                // mywindow.setCursor(&icon_pixels, 32, 32, 0, 0) catch {
                                //     std.debug.print("Failed to set window's cursor.\n", .{});
                                // };
                            },
                            ScanCode.U => {
                                // mywindow.setStandardCursor(widow.cursor.StandardCursorShape.Help) catch {
                                //     std.debug.print("Failed to set standard cursor\n", .{});
                                // };
                            },
                            else => {
                                std.debug.print("Cursor Position:{}\n", .{mywindow.cursorPosition()});
                            },
                        }
                    }
                },
                else => {
                    continue;
                },
            }
        }
    }
}
