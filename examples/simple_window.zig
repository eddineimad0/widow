const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const ScanCode = widow.input.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const allocator = std.heap.c_allocator;

// pub const EventType = enum(u8) {
//     FileDrop, // Some file was released in the window area.
//     RawMouseMove, // For windows that enable raw mouse motion,the data specifes the
// };

pub fn main() !void {
    var context = try widow.WidowContext.init(allocator);
    defer context.deinit();
    var window = try widow.window.WindowBuilder.init("creation_test", 800, 600, &context).build();
    defer window.deinit();
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
                if (key.scancode == ScanCode.N and key.action.isPress()) {
                    if (key.mods.shift) {
                        window.set_cursor_mode(CursorMode.Normal);
                    } else if (key.mods.ctrl) {
                        window.set_cursor_mode(CursorMode.Disabled);
                    } else {
                        window.set_cursor_mode(CursorMode.Captured);
                    }
                }
            },
            EventType.MouseButton => |*mouse_event| {
                std.debug.print("Mouse Button:{}\nAction:{}\nmods:{}\n", .{ mouse_event.button, mouse_event.action, mouse_event.mods });
            },
            EventType.MouseScroll => |*scroll| {
                std.debug.print("Mouse Scroll:wheel:{}\ndelta:{d}\n", .{ scroll.wheel, scroll.delta });
            },
            EventType.MouseEnter => {
                std.debug.print("Mouse Entered\n", .{});
            },
            EventType.MouseLeave => {
                std.debug.print("Mouse Left\n", .{});
            },
            EventType.MouseMove => |position| {
                if (position.x == 0 and position.y == 0) {
                    std.debug.print("Mouse in client top left \n", .{});
                }
            },
            EventType.Focus => |has_focus| {
                std.debug.print("Focus ", .{});
                if (has_focus) {
                    std.debug.print("Gained\n", .{});
                } else {
                    std.debug.print("Lost\n", .{});
                }
            },
            EventType.DPIChange => |*new_settigns| {
                std.debug.print("New DPI {}, new UI elements Scaler {}\n", .{ new_settigns.dpi, new_settigns.scaler });
            },
            EventType.WindowMaximize => {
                std.debug.print("Window was maximized\n", .{});
            },
            EventType.WindowMinimize => {
                std.debug.print("Window was minimized\n", .{});
            },
            EventType.Character => |*char| {
                if (char.codepoint == 0x47) {
                    std.debug.print("character:{u}\nmods:{}\n", .{ char.codepoint, char.mods });
                }
            },
            EventType.WindowResize => |*new_size| {
                std.debug.print("new width:{} | new height:{}\n", .{ new_size.width, new_size.height });
            },
            else => {
                continue :event_loop;
            },
        }
    }
}
