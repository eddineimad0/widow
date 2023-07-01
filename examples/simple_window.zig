const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const ScanCode = widow.input.ScanCode;
const CursorMode = widow.cursor.CursorMode;
const allocator = std.heap.c_allocator;

pub fn main() void {

    // Start by creating a WidowContext instance.
    // the context is at the heart of the library and keeps track of monitors,clipboard,events...
    // only one instance is needed and allocating any more would be a waste of memory.
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
        800,
        600,
        widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create our window,
    var mywindow = builder.withResize(true).withDPIScaling(false).build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // deinitialize when done.
    defer mywindow.deinit();

    var event: widow.Event = undefined;
    event_loop: while (true) {
        // Process window events posted by the system.
        mywindow.processEvents();

        while (widow_cntxt.pollEvents(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    // The user has requested to close the window,
                    // and the application should proceed to calling deinit on the window instance.
                    // This is merely a notification nothing is done to window in the background,
                    // ignore it if you want to continue execution as normal.
                    break :event_loop;
                },
                EventType.KeyBoard => |*key| {
                    // This event holds the keyboard key,
                    // the action that was done to the key (pressed or released),
                    // and the keymodifiers state during the event pressed(true) or released(false).
                    std.debug.print("Virtual Key:{}\nState:{}\nmods:{}\n", .{ key.scancode, key.state, key.mods });
                    if (key.scancode == ScanCode.N and key.state.isPressed()) {
                        if (key.mods.shift) {
                            mywindow.setCursorMode(CursorMode.Normal);
                        } else if (key.mods.ctrl) {
                            mywindow.setCursorMode(CursorMode.Disabled);
                        } else {
                            mywindow.setCursorMode(CursorMode.Captured);
                        }
                    }
                },
                EventType.MouseButton => |*mouse_event| {
                    // This event holds the mouse button (left,middle,right,...),
                    // the action that was done to the button (pressed or released),
                    // and the keymodifiers state during the event pressed(true) or released(false).
                    std.debug.print("Mouse Button:{}\nState:{}\nmods:{}\n", .{ mouse_event.button, mouse_event.state, mouse_event.mods });
                },
                EventType.MouseScroll => |*scroll| {
                    // This event holds the Wheel (horizontal or vertical) that was scrolled and by how much (delta).
                    std.debug.print("wheel:{} Scrolled by :{d}\n", .{ scroll.wheel, scroll.delta });
                },
                EventType.MouseEnter => {
                    std.debug.print("Mouse Entered the client area\n", .{});
                },
                EventType.MouseLeave => {
                    std.debug.print("Mouse Left the client area\n", .{});
                },
                EventType.MouseMove => |position| {
                    // This event holds the new client area coordinates (x,y).
                    // the origin point is the destop's top left corner.
                    if (position.x == 0 and position.y == 0) {
                        std.debug.print("Mouse in client top left \n", .{});
                    }
                },
                EventType.Focus => |has_focus| {
                    // This event holds a boolean flag on whether the window got or lost focus.
                    std.debug.print("Focus ", .{});
                    if (has_focus) {
                        std.debug.print("Gained\n", .{});
                    } else {
                        std.debug.print("Lost\n", .{});
                    }
                },
                EventType.DPIChange => |*new_settigns| {
                    // This event holds the new window dpi and the scaler to be used when drawing
                    // to the screen.
                    std.debug.print("New DPI {}, new Scaler {}\n", .{ new_settigns.dpi, new_settigns.scaler });
                },
                EventType.WindowMaximize => {
                    std.debug.print("Window was maximized\n", .{});
                },
                EventType.WindowMinimize => {
                    std.debug.print("Window was minimized\n", .{});
                },
                EventType.Character => |*char| {
                    // This event holds a unicode character codepoint and keymodifers that were pressed
                    // during the event.
                    if (char.codepoint == 0x47) {
                        std.debug.print("character:{u}\nmods:{}\n", .{ char.codepoint, char.mods });
                    }
                },
                EventType.WindowResize => |*new_size| {
                    // This event holds the new client width and height.
                    std.debug.print("new width:{} | new height:{}\n", .{ new_size.width, new_size.height });
                },
                EventType.FileDrop => {

                    // Get a Slice containing the path(s) to the latest file(s).
                    const files = mywindow.droppedFiles();
                    for (files) |*file| {
                        std.debug.print("File: {s} Dropped\n", .{file.*});
                    }

                    // if the files cache exceed a certain threshold,
                    // you may want to free it.
                    if (files.len > 5) {
                        std.log.info("Free drop cache\n", .{});
                        mywindow.freeDroppedFiles();
                    }
                },
                else => {
                    continue;
                },
            }
        }
    }
}
