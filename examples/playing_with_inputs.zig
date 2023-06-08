const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const ScanCode = widow.input.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const WidowSize = widow.geometry.WidowSize;
const AspectRatio = widow.geometry.AspectRatio;
const FullScreenMode = widow.FullScreenMode;
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
    var event: widow.event.Event = undefined;
    window.waitEvent(&event);
    std.debug.print("First event fired\n", .{});
    const success = window.waitEventTimeout(&event, 3000);
    if (success) {
        std.debug.print("Second event fired\n", .{});
    }
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
                        ScanCode.Q => {
                            if (key.mods.shift) {
                                window.queueCloseEvent();
                            }
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
                        ScanCode.P => {
                            if (key.mods.shift) {
                                window.setPosition(0, 0);
                            }
                            std.debug.print("Widnow Position {}\n", .{window.position()});
                        },
                        ScanCode.S => {
                            if (key.mods.shift) {
                                window.setClientSize(800, 600);
                            } else if (key.mods.ctrl) {
                                std.debug.print("Window Size {}\n", .{window.size()});
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
                                continue :event_loop;
                            };

                            window.setTitle(title) catch {
                                std.debug.print("failed to set new title\n", .{});
                                continue :event_loop;
                            };
                        },
                        ScanCode.D => {
                            window.debugInfos();
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
                            std.debug.print("Window Opacity:{}\n", .{opacity});
                            if (key.mods.shift) {
                                opacity += 0.1;
                            }
                            if (key.mods.ctrl) {
                                opacity -= 0.1;
                            }
                            window.setOpacity(opacity);
                        },
                        ScanCode.Y => {
                            if (key.mods.shift) {
                                const client_size = window.clientSize();
                                window.setCursorPosition(@divExact(client_size.width, 2), @divExact(client_size.height, 2));
                            } else {
                                const cursor_pos = window.cursorPosition();
                                std.debug.print("Cursor Position: ({},{})\n", .{ cursor_pos.x, cursor_pos.y });
                            }
                        },
                        ScanCode.E => {
                            if (key.mods.shift) {
                                window.setFullscreen(FullScreenMode.Exclusive) catch {
                                    std.debug.print("Failed to switch video mode\n", .{});
                                };
                            } else {
                                window.setFullscreen(FullScreenMode.Borderless) catch {
                                    unreachable;
                                };
                            }
                        },
                        ScanCode.Escape => {
                            window.setFullscreen(null) catch {
                                unreachable;
                            };
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
            EventType.Focus => |has_focus| {
                if (!has_focus and window.isVisible()) {
                    window.requestUserAttention();
                }
            },
            else => {
                continue :event_loop;
            },
        }
    }
}
