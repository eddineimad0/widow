const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const ScanCode = widow.input.keyboard.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const CursorShape = widow.cursor.NativeCursorShape;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    const ctx = try widow.createWidowContext(allocator);
    defer widow.destroyWidowContext(allocator, ctx);

    var ev_queue = EventQueue.init(allocator);
    defer ev_queue.deinit();

    // create a WindowBuilder.
    var builder = widow.WindowBuilder.init();
    // customize the window.
    var mywindow = builder.withTitle("Simple Window")
        .withSize(1024, 800)
        .withResize(true)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withDecoration(true)
        .build(allocator, ctx, null) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    defer mywindow.deinit(allocator);

    _ = mywindow.setEventQueue(&ev_queue);

    const icon_pixels = [_]u8{ 0xF7, 0xA4, 0x1D, 0xFF } ** (32 * 32);
    mywindow.setIcon(&icon_pixels, 32, 32, allocator) catch {
        std.debug.print("Failed to set Window icon.\n", .{});
    };

    var event: widow.event.Event = undefined;
    event_loop: while (true) {
        try mywindow.waitEvent();

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    break :event_loop;
                },
                EventType.MouseMove => |*pos| {
                    std.debug.print("Mouse=({},{})\n", .{ pos.x, pos.y });
                },
                EventType.KeyBoard => |*key| {
                    if (key.state.isPressed()) {
                        switch (key.scancode) {
                            ScanCode.Q => {
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
                                mywindow.setCursorIcon(
                                    &icon_pixels,
                                    32,
                                    32,
                                    0,
                                    0,
                                ) catch {
                                    std.debug.print(
                                        "Failed to set window's cursor.\n",
                                        .{},
                                    );
                                };
                            },
                            ScanCode.U => {
                                mywindow.setNativeCursorIcon(
                                    widow.cursor.NativeCursorShape.Help,
                                ) catch {
                                    std.debug.print(
                                        "Failed to set standard cursor\n",
                                        .{},
                                    );
                                };
                            },
                            ScanCode.X => {
                                if (key.mods.shift) {
                                    _ = mywindow.setRawMouseMotion(true);
                                } else {
                                    _ = mywindow.setRawMouseMotion(false);
                                }
                            },
                            else => {
                                std.debug.print("Cursor Position:{}\n", .{
                                    mywindow.getCursorPosition(),
                                });
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
