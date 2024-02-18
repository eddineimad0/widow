const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const ScanCode = widow.keyboard_and_mouse.ScanCode;
const WidowSize = widow.geometry.WidowSize;
const AspectRatio = widow.geometry.AspectRatio;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();
    // first we need to preform some platform specific initialization.
    widow.initWidowPlatform(.{}) catch {
        std.debug.print("Failed to start Widow library\n", .{});
    };
    // clean up code to be called, when done using the library.
    defer widow.deinitWidowPlatform();

    var context = widow.WidowContext.init(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer context.deinit();

    var builder = widow.WindowBuilder.init(
        "playing with inputs",
        800,
        600,
        &context,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    var window = builder.withResize(true).build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();

    defer window.deinit();

    var event: widow.Event = undefined;
    event_loop: while (true) {
        window.waitEvent();
        while (context.pollEvents(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    if (key.state.isPressed()) {
                        switch (key.scancode) {
                            ScanCode.Q => {
                                window.queueCloseEvent();
                            },
                            ScanCode.C => {
                                std.debug.print("Client Position {}\n", .{window.clientPosition()});
                            },
                            ScanCode.R => {
                                const resizable = window.isResizable();
                                window.setResizable(!resizable);
                            },
                            ScanCode.N => {
                                if (key.mods.shift) {
                                    window.setMinSize(null);
                                } else {
                                    window.setMinSize(WidowSize{ .width = 300, .height = 300 });
                                }
                            },
                            ScanCode.B => {
                                if (key.mods.shift) {
                                    window.setMaxSize(null);
                                } else {
                                    window.setMaxSize(WidowSize{ .width = 1000, .height = 1000 });
                                }
                            },
                            ScanCode.S => {
                                if (key.mods.shift) {
                                    window.setClientSize(800, 600);
                                } else if (key.mods.alt) {
                                    window.setClientSize(640, 480);
                                } else {
                                    std.debug.print("Client Size {}\n", .{window.clientSize()});
                                }
                            },
                            ScanCode.I => {
                                window.setVisible(false);
                                std.time.sleep(3 * std.time.ns_per_s);
                                std.debug.print("Window Flags\n", .{});
                                std.debug.print("Visible:{}\n", .{window.isVisible()});
                                std.debug.print("Resizable:{}\n", .{window.isResizable()});
                                std.debug.print("Decorated:{}\n", .{window.isDecorated()});
                                std.debug.print("Minimized:{}\n", .{window.isMinimized()});
                                std.debug.print("Maximized:{}\n", .{window.isMaximized()});
                                std.debug.print("Focused:{}\n", .{window.isFocused()});
                                window.setVisible(true);
                            },
                            ScanCode.T => {
                                const title = context.clipboardText() catch {
                                    std.debug.print("failed to set new title\n", .{});
                                    continue;
                                };

                                window.setTitle(title) catch {
                                    std.debug.print("failed to set new title\n", .{});
                                    continue;
                                };
                            },
                            ScanCode.M => {
                                if (key.mods.shift) {
                                    const maximized = window.isMaximized();
                                    window.setMaximized(!maximized);
                                }
                                if (key.mods.ctrl) {
                                    const minimized = window.isMinimized();
                                    window.setMinimized(!minimized);
                                    std.debug.print("Minimized:{}\n", .{window.isMinimized()});
                                }
                            },
                            ScanCode.O => {
                                var opacity: f32 = window.opacity();
                                std.debug.print("Window Opacity:{d}\n", .{opacity});
                                if (key.mods.shift) {
                                    opacity += 0.1;
                                }
                                if (key.mods.ctrl) {
                                    opacity -= 0.1;
                                }
                                window.setOpacity(opacity);
                            },
                            ScanCode.Y => {
                                window.setDecorated(false);
                            },
                            ScanCode.F => {
                                std.debug.print("--------Window Flags--------\n", .{});
                                std.debug.print("Visible:{}\n", .{window.isVisible()});
                                std.debug.print("Resizable:{}\n", .{window.isResizable()});
                                std.debug.print("Decorated:{}\n", .{window.isDecorated()});
                                std.debug.print("Minimized:{}\n", .{window.isMinimized()});
                                std.debug.print("Maximized:{}\n", .{window.isMaximized()});
                                std.debug.print("Focused:{}\n", .{window.isFocused()});
                                std.debug.print("Hovered:{}\n", .{window.isHovered()});
                                std.debug.print("Scale:{}\n", .{window.contentScale()});
                            },
                            ScanCode.A => {
                                if (key.mods.shift) {
                                    window.setAspectRatio(null);
                                } else {
                                    // a (4:3) ratio.
                                    const ratio = AspectRatio{
                                        .x = 4,
                                        .y = 3,
                                    };
                                    window.setAspectRatio(ratio);
                                }
                            },
                            else => {},
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
