const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const KeyCode = widow.keyboard.KeyCode;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();
    // first we need to preform some platform specific initialization.
    // an options tuple can be passed to customize the platform init
    // e.g on windows we can set the WNDClass name to a comptime string of our choice,
    try widow.initWidowPlatform(.{ .wnd_class = "Zig_is_awesome" });
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
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "Simple window",
        800,
        600,
        &widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // customize the window to your liking.
    _ = builder.withResize(true)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withSize(800, 600)
        .withDecoration(true);

    _ = builder.withTitle("Re:Simple Window") catch |err| {
        std.debug.print("Failed to change window title,{}\n", .{err});
        return;
    };

    // create the window,
    var mywindow = builder.build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // closes the window when done.
    defer mywindow.deinit();

    var event: widow.Event = undefined;
    event_loop: while (true) {
        // Process window events posted by the system.
        mywindow.waitEvent();

        // All entities in the library send their
        // events to a central event queue in the WidowContext instance.
        // specified at their creation.
        while (widow_cntxt.pollEvents(&event)) {
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
                // // new coordinates for the top left corner of the window.
                // FileDrop => Some file was released in the window area.
                // KeyBoard => A certain Keyboard key action(press or release) was performed.
                // MouseButton, => A certain Mouse button action(press or release) was performed while
                // the mouse is over the client area.
                // MouseScroll => One of the mouse wheels(vertical,horizontal) was scrolled.
                // MouseMove => The mouse position (relative to the client area's top left corner) changed.
                // MouseEnter => The mouse entered the client area of the window.
                // MouseLeave => The mouse exited the client area of the window.
                // DPIChange => DPI change due to the window being dragged to another monitor.
                // Character => The key pressed by the user generated a character.
                // RedrawRequest => Request from the system to redraw the window's client area.

                EventType.WindowClose => |window_id| {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    std.debug.print("closing Window #{}\n", .{window_id});
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    // This event holds the keyboard key keycode (symbolic representation that
                    // depends on the language settigns)
                    // and scancode (Hardware representation of the key, i.e the symbol of the key on the keyboard. ),
                    // in short scancode is the symbol of the key on the keyboard,the virtual key is the
                    // symbol the key represents with the current input language settings.
                    // the action that was done to the key (pressed or released),
                    // and the keymodifiers state during the event pressed(true) or released(false).
                    std.debug.print("Window #{}\nVirtual code:{}\nScan Code:{}\nState:{}\nmods:{}\n", .{
                        key.window_id,
                        key.keycode,
                        key.scancode,
                        key.state,
                        key.mods,
                    });
                    if (key.state.isPressed()) {
                        if (key.keycode == KeyCode.Q) {
                            // let's request closing the window on pressing Q key
                            mywindow.queueCloseEvent();
                        }
                        if (key.keycode == .D) {
                            mywindow.debugInfos(true, true);
                        }
                        if (key.keycode == .P) {
                            std.debug.print("ClientPosition:{}\n", .{mywindow.clientPosition()});
                        }
                        if (key.keycode == .M) {
                            mywindow.setClientPosition(0, 0);
                        }
                        if (key.keycode == .C) {
                            mywindow.setClientSize(1024, 640);
                        }
                        if (key.keycode == .R) {
                            const resizable = mywindow.isResizable();
                            mywindow.setResizable(!resizable);
                        }
                        if (key.keycode == .B) {
                            const decorated = mywindow.isDecorated();
                            mywindow.setDecorated(!decorated);
                        }
                        if (key.keycode == .E) {
                            var video = widow.VideoMode.init(800, 600, 60, 32);
                            if (key.mods.shift) {
                                _ = mywindow.setFullscreen(true, &video);
                            } else {
                                _ = mywindow.setFullscreen(true, null);
                            }
                        }
                        if (key.keycode == .Escape) {
                            _ = mywindow.setFullscreen(false, null);
                        }
                        if (key.keycode == .N) {
                            if (key.mods.shift) {
                                mywindow.setMinSize(null);
                            } else {
                                mywindow.setMinSize(widow.geometry.WidowSize{ .width = 300, .height = 300 });
                            }
                        }
                        if (key.keycode == .U) {
                            if (key.mods.shift) {
                                mywindow.setDragAndDrop(true);
                            } else {
                                mywindow.setDragAndDrop(false);
                            }
                        }
                        if (key.keycode == .I) {
                            const minimized = mywindow.isMinimized();
                            mywindow.setMinimized(!minimized);
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
                    std.debug.print("Window #{}\nwheel:{} Scrolled by :{d}\n", .{
                        scroll.window_id,
                        scroll.wheel,
                        scroll.delta,
                    });
                },
                EventType.MouseEnter => |window_id| {
                    std.debug.print("Mouse Entered the client area of window #{}\n", .{window_id});
                },
                EventType.MouseLeave => |window_id| {
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
                EventType.DPIChange => |*dpi_event| {
                    // This event holds the new window dpi and the scaler to be used when drawing
                    // to the screen.
                    std.debug.print("Window #{} New DPI {}, new Scaler {}\n", .{
                        dpi_event.window_id,
                        dpi_event.dpi,
                        dpi_event.scaler,
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
                        resize_event.width,
                        resize_event.height,
                        resize_event.window_id,
                    });
                },
                EventType.FileDrop => |window_id| {

                    // Get a Slice containing the path(s) to the latest file(s).
                    const files = mywindow.droppedFiles();
                    for (files) |*file| {
                        std.debug.print("File: {s} Dropped on window #{}\n", .{ file.*, window_id });
                    }

                    // if the files cache exceed a certain threshold,
                    // you may want to manually free it.
                    if (files.len > 5) {
                        std.log.info("Free drop cache\n", .{});
                        mywindow.freeDroppedFiles();
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
