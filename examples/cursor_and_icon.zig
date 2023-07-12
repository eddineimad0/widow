const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const ScanCode = widow.keyboard_and_mouse.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const CursorShape = widow.cursor.CursorShape;
const allocator = std.heap.c_allocator;

pub fn main() void {
    var widow_cntxt = widow.WidowContext.create(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_cntxt.destroy(allocator);

    // Grab the library's WindowBuilder instance.
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "Simple window",
        1024,
        640,
        widow_cntxt,
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

    const icon_pixels = [_]u8{ 0xF7, 0xA4, 0x1D, 0xFF } ** (32 * 32);
    window.setIcon(&icon_pixels, 32, 32) catch {
        std.debug.print("Failed to set Window icon.\n", .{});
    };
    var event: widow.Event = undefined;
    event_loop: while (true) {
        window.processEvents();

        while (widow_cntxt.pollEvents(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    if (key.state.isPressed()) {
                        switch (key.scancode) {
                            ScanCode.Q => {
                                // let's request closing the window on pressing Q key
                                window.queueCloseEvent();
                            },
                            ScanCode.C => {
                                window.setCursorMode(CursorMode.Captured);
                            },
                            ScanCode.D => {
                                window.setCursorMode(CursorMode.Disabled);
                            },
                            ScanCode.S => {
                                window.setCursorMode(CursorMode.Normal);
                            },
                            ScanCode.I => {
                                const black_box = [_]u8{255} ** (32 * 32 * 4);
                                window.setCursor(&black_box, 32, 32, 0, 0) catch {
                                    std.debug.print("Failed to set window's cursor.\n", .{});
                                };
                            },
                            else => {
                                std.debug.print("Cursor Position:{}\n", .{window.cursorPosition()});
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
