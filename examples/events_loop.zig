const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    const ctx = try widow.createWidowContext(allocator, null);
    defer widow.destroyWidowContext(allocator, ctx);

    var ev_queue = try EventQueue.init(allocator, 256);
    defer ev_queue.deinit();

    // create a WindowBuilder.
    var builder = widow.WindowBuilder.init();
    // customize the window.
    var mywindows: [1]widow.Window = undefined;
    mywindows[0] = builder.withTitle("Simple Window")
        .withSize(1024, 768)
        .withResize(false)
        .withDPIAware(false)
        .withPosition(200, 200)
        .withDecoration(true)
        .build(ctx, 0) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };
    defer mywindows[0].deinit();

    _ = mywindows[0].setEventQueue(&ev_queue);

    event_loop: while (true) {
        try mywindows[0].waitEvent();

        var event: widow.event.Event = undefined;

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                // Possible Events
                // WindowClose => The X icon on the window frame was pressed.
                // WindowResize => The window client area size was changed.
                // WindowShown, => The window was shown to the user.
                // WindowHidden, => The window was hidden from the user.
                // WindowFocus => True/False if the window got keyboard focus.
                // WindowMaximize => The window was minimized.
                // WindowMinimize => The window was maximized.
                // WindowMove => The window has been moved, the Point2D struct specify the
                // new coordinates for the top left corner of the window.
                // FileDrop => Some file was released in the window area.
                // Keyboard => A certain Keyboard key action(press or release) was performed.
                // MouseButton, => A certain Mouse button action(press or release) was performed while
                // the mouse is over the client area.
                // MouseScroll => One of the mouse wheels(vertical,horizontal) was scrolled.
                // MouseMove => The mouse position (relative to the client area's top left corner) changed.
                // MouseEnter => The mouse entered the client area of the window.
                // MouseExit => The mouse exited the client area of the window.
                // DpiChange => DPI change due to the window being dragged to another monitor.
                // Character => The key pressed by the user generated a character.
                // RePaintRequest => Request from the system to repaint the window's client area.

                EventType.WindowClose => |window_id| {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    std.debug.print("closing Window #{}\n", .{window_id});
                    break :event_loop;
                },
                EventType.Keyboard => |*key| {
                    // This event holds the keyboard key keycode (symbolic representation that
                    // depends on the layout active on the os)
                    // and scancode (Hardware representation of the key).
                    // in short scancode is the symbol of the key on the US keyboard,the virtual key is the
                    // symbol the key represents with the current input layout settings.
                    // the action that was done to the key (pressed or released),
                    // and the keymodifiers state during the event pressed(true) or released(false).
                    std.debug.print("Window #{}\nKeycode:{}\nScancode:{}\nState:{}\nmods:{}\n", .{
                        key.window_id,
                        key.keycode,
                        key.scancode,
                        key.state,
                        key.mods,
                    });

                    if (key.state.isPressed()) {
                        if (key.keycode == KeyCode.Q) {
                            // let's request closing the window on pressing Q key
                            mywindows[key.window_id].queueCloseEvent();
                        }
                        if (key.keycode == .D) {
                            mywindows[key.window_id].printDebugInfo(true, true);
                        }
                        if (key.keycode == .T) {
                            std.debug.print(
                                "DPI info:{}\n",
                                .{mywindows[key.window_id].getDpiInfo()},
                            );
                        }
                        if (key.keycode == .P) {
                            std.debug.print(
                                "ClientPosition:{}\n",
                                .{mywindows[key.window_id].getClientPosition()},
                            );
                        }
                        if (key.keycode == .M) {
                            mywindows[key.window_id].setClientPosition(0, 0);
                        }
                        if (key.keycode == .C) {
                            mywindows[key.window_id].setClientSize(1024, 640);
                        }
                        if (key.keycode == .R) {
                            const resizable = mywindows[key.window_id].isResizable();
                            mywindows[key.window_id].setResizable(!resizable);
                        }
                        if (key.keycode == .B) {
                            const decorated = mywindows[key.window_id].isDecorated();
                            mywindows[key.window_id].setDecorated(!decorated);
                        }
                        if (key.keycode == .E) {
                            _ = mywindows[key.window_id].setFullscreen(true);
                        }
                        if (key.keycode == .Escape) {
                            _ = mywindows[key.window_id].setFullscreen(false);
                        }
                        if (key.keycode == .N) {
                            if (key.mods.shift) {
                                mywindows[key.window_id].setMinSize(null);
                            } else {
                                mywindows[key.window_id].setMinSize(widow.geometry.RectSize{
                                    .width = 300,
                                    .height = 300,
                                });
                            }
                        }
                        if (key.keycode == .U) {
                            if (key.mods.shift) {
                                mywindows[key.window_id].allowDragAndDrop(true);
                            } else {
                                mywindows[key.window_id].allowDragAndDrop(false);
                            }
                        }
                        if (key.keycode == .I) {
                            const minimized = mywindows[key.window_id].isMinimized();
                            mywindows[key.window_id].setMinimized(!minimized);
                        }
                        if (key.keycode == .K) {
                            const maximized = mywindows[key.window_id].isMaximized();
                            mywindows[key.window_id].setMaximized(!maximized);
                        }
                    }
                },
                EventType.MouseButton => |*mouse_event| {
                    // This event holds the mouse button (left,middle,right,...),
                    // the action that was done to the button (pressed or released),
                    // and the keymodifiers state during the event pressed(true) or released(false).
                    std.debug.print("Window #{}\nMouse Button:{}\nState:{}\nmods:{}\n", .{
                        mouse_event.window_id,
                        mouse_event.button,
                        mouse_event.state,
                        mouse_event.mods,
                    });
                },
                EventType.MouseScroll => |*scroll| {
                    // This event holds the Wheel (horizontal or vertical) that was scrolled and by how much (delta).
                    std.debug.print("Window #{}\nvertical wheel:{d} horizontal wheel:{d}\n", .{
                        scroll.window_id,
                        scroll.y_offset,
                        scroll.x_offset,
                    });
                },
                EventType.MouseEnter => |window_id| {
                    std.debug.print("Mouse Entered the client area of window #{}\n", .{window_id});
                },
                EventType.MouseExit => |window_id| {
                    std.debug.print("Mouse Left the client area window #{}\n", .{window_id});
                },
                EventType.MouseMove => |*motion| {
                    // This event holds the new client area coordinates (x,y).
                    // the origin point is the destop's top left corner.
                    if (motion.x == 0 and motion.y == 0) {
                        std.debug.print("Mouse in client top left of window #{} \n", .{motion.window_id});
                    }
                },
                EventType.WindowFocus => |*focus_event| {
                    // This event holds a boolean flag on whether the window got or lost focus.
                    std.debug.print("Focus ", .{});
                    if (focus_event.has_focus) {
                        std.debug.print("Gained", .{});
                    } else {
                        std.debug.print("Lost", .{});
                    }
                    std.debug.print("By window #{}\n", .{focus_event.window_id});
                },
                EventType.DpiChange => |*dpi_event| {
                    // This event holds the new window dpi and the scaler to be used when drawing
                    // to the screen.
                    std.debug.print("Window #{} New DPI ({},{}), new Scaler {}\n", .{
                        dpi_event.window_id,
                        dpi_event.dpi_info.dpi_x,
                        dpi_event.dpi_info.dpi_y,
                        dpi_event.dpi_info.scale_factor,
                    });
                },
                EventType.WindowMaximize => |window_id| {
                    std.debug.print("Window #{} was maximized\n", .{window_id});
                },
                EventType.WindowMinimize => |window_id| {
                    std.debug.print("Window #{} was minimized\n", .{window_id});
                },
                EventType.WindowShown => |window_id| {
                    std.debug.print("Window #{} was Shown\n", .{window_id});
                },
                EventType.WindowHidden => |window_id| {
                    std.debug.print("Window #{} was Hidden\n", .{window_id});
                },
                EventType.WindowRestore => |window_id| {
                    std.debug.print("Window #{} was restored\n", .{window_id});
                },
                EventType.Character => |*char| {
                    // This event holds a unicode character codepoint and keymodifers that were pressed
                    // during the event.
                    if (char.codepoint == 0x47) {
                        std.debug.print("target window #{},character:{u}\nmods:{}\n", .{
                            char.window_id,
                            char.codepoint,
                            char.mods,
                        });
                    }
                },
                EventType.WindowResize => |*resize_event| {
                    // This event holds the new physical(dpi scaled) client width and height.
                    std.debug.print("new client width:{} | new client height:{} of window #{}\n", .{
                        resize_event.new_size.physical_width,
                        resize_event.new_size.physical_height,
                        resize_event.window_id,
                    });
                },
                EventType.FileDrop => |window_id| {

                    // Get a Slice containing the path(s) to the latest file(s).
                    const files = mywindows[window_id].getDroppedFilesURI();
                    for (files) |*file| {
                        std.debug.print("File: {s} Dropped on window #{}\n", .{ file.*, window_id });
                    }

                    // if the files cache exceed a certain threshold,
                    // you may want to manually free it.
                    if (files.len > 5) {
                        std.log.info("Free drop cache\n", .{});
                        mywindows[window_id].freeDroppedFilesURI();
                    }
                },
                EventType.WindowMove => |*new_pos| {
                    std.debug.print(
                        "Window #{} new client position:({},{})\n",
                        .{ new_pos.window_id, new_pos.x, new_pos.y },
                    );
                },
                else => {
                    continue;
                },
            }
        }
    }
}
