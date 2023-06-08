const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const ScanCode = widow.input.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const CursorShape = widow.cursor.CursorShape;
const allocator = std.heap.c_allocator;

pub fn main() void {
    var context = widow.WidowContext.init(allocator) catch {
        std.debug.print("Failed to create a WidowContext\n", .{});
        return;
    };
    defer context.deinit();
    var builder = widow.window.WindowBuilder.init("creation_test", 480, 640, &context) catch {
        std.debug.print("Failed to create a WindowBuilder\n", .{});
        return;
    };
    var window = builder.resizable().build() catch {
        std.debug.print("Failed to create a Window\n", .{});
        return;
    };
    defer window.deinit();
    const icon_pixels = [_]u8{ 0xF7, 0xA4, 0x1D, 0xFF } ** (32 * 32);
    widow.WidowContext.setWindowIcon(&window, &icon_pixels, 32, 32) catch {
        std.debug.print("Failed to set Window icon.\n", .{});
    };
    var event: widow.event.Event = undefined;
    event_loop: while (true) {
        if (!window.pollEvent(&event)) {
            continue :event_loop;
        }
        switch (event) {
            EventType.WindowClose => {
                break :event_loop;
            },
            EventType.KeyBoard => |*key| {
                if (key.action.isPress()) {
                    switch (key.scancode) {
                        ScanCode.C => {
                            window.setCursorMode(CursorMode.Captured);
                        },
                        ScanCode.D => {
                            window.setCursorMode(CursorMode.Disabled);
                        },
                        ScanCode.S => {
                            window.setCursorMode(CursorMode.Normal);
                        },
                        // ScanCode.A => {
                        //     widow.WidowContext.setWindowStdCursor(&window, CursorShape.Default) catch {
                        //         std.debug.print("Failed to set window's cursor.\n", .{});
                        //     };
                        // },
                        // ScanCode.H => {
                        //     widow.WidowContext.setWindowStdCursor(&window, CursorShape.PointingHand) catch {
                        //         std.debug.print("Failed to set window's cursor.\n", .{});
                        //     };
                        // },
                        ScanCode.Q => {
                            const black_box = [_]u8{0} ** (32 * 32 * 4);
                            widow.WidowContext.setWindowCursor(&window, &black_box, 32, 32, 0, 0) catch {
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
                continue :event_loop;
            },
        }
    }
}
