const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const utils = @import("utils.zig");
const keymaps = @import("keymaps.zig");
const opts = @import("build-options");
const kbd_mouse = common.keyboard_mouse;
const X11Driver = @import("driver.zig").X11Driver;
const Window = @import("window.zig").Window;

fn handleButtonRelease(e: *const libx11.XButtonEvent, window: *Window) void {
    // TODO: what about the button state cache.
    if (opts.LOG_PLATFORM_EVENTS) {
        std.log.info("window: #{} recieved ButtonRelease\n", .{window.data.id});
    }
    const button_event = switch (e.button) {
        libx11.Button1 => common.event.createMouseButtonEvent(
            window.data.id,
            kbd_mouse.MouseButton.Left,
            kbd_mouse.MouseButtonState.Released,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button2 => common.event.createMouseButtonEvent(
            window.data.id,
            kbd_mouse.MouseButton.Middle,
            kbd_mouse.MouseButtonState.Released,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button3 => common.event.createMouseButtonEvent(
            window.data.id,
            kbd_mouse.MouseButton.Right,
            kbd_mouse.MouseButtonState.Released,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button4,
        libx11.Button5,
        libx11.Button6,
        libx11.Button7,
        => {
            return;
        },
        else => {
            std.debug.print("\nbutton:{d}\n", .{e.button});
            return;
        },
    };
    window.sendEvent(&button_event);
}

fn handleButtonPress(e: *const libx11.XButtonEvent, window: *Window) void {
    if (opts.LOG_PLATFORM_EVENTS) {
        std.log.info("window: #{} recieved ButtonPress\n", .{window.data.id});
    }
    const button_event = switch (e.button) {
        libx11.Button1 => common.event.createMouseButtonEvent(
            window.data.id,
            kbd_mouse.MouseButton.Left,
            kbd_mouse.MouseButtonState.Pressed,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button2 => common.event.createMouseButtonEvent(
            window.data.id,
            kbd_mouse.MouseButton.Middle,
            kbd_mouse.MouseButtonState.Pressed,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button3 => common.event.createMouseButtonEvent(
            window.data.id,
            kbd_mouse.MouseButton.Right,
            kbd_mouse.MouseButtonState.Pressed,
            utils.decodeKeyMods(e.state),
        ),
        // INFO:
        // [https://github.com/libsdl-org/SDL/blob/main/src/video/x11/SDL_x11events.c#L185C5-L187C80]
        // according to the xlib docs, no specific mouse wheel events exist.
        // However, the defacto standard is that the vertical wheel is X buttons
        // 4 (up) and 5 (down) and a horizontal wheel is 6 (left) and 7 (right).
        libx11.Button4 => common.event.createScrollEvent(
            window.data.id,
            kbd_mouse.MouseWheel.VerticalWheel,
            1.0,
        ),
        libx11.Button5 => common.event.createScrollEvent(
            window.data.id,
            kbd_mouse.MouseWheel.VerticalWheel,
            -1.0,
        ),
        libx11.Button6 => common.event.createScrollEvent(
            window.data.id,
            kbd_mouse.MouseWheel.HorizontalWheel,
            1.0,
        ),
        libx11.Button7 => common.event.createScrollEvent(
            window.data.id,
            kbd_mouse.MouseWheel.HorizontalWheel,
            -1.0,
        ),
        else => return,
    };

    window.sendEvent(&button_event);
}

/// handles ICCCM messages.
fn handleClientMessage(e: *const libx11.XClientMessageEvent, w: *Window) void {
    const x11cntxt = X11Driver.singleton();
    if (e.message_type == x11cntxt.ewmh.WM_PROTOCOLS) {
        if (@as(libx11.Atom, @intCast(e.data.l[0])) == x11cntxt.ewmh.WM_DELETE_WINDOW) {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved ClientMessage:WM_DELETE_WINDOW\n",
                    .{w.handle},
                );
            }
            const event = common.event.createCloseEvent(w.data.id);
            w.sendEvent(&event);
        }
        if (@as(libx11.Atom, @intCast(e.data.l[0])) == x11cntxt.ewmh._NET_WM_PING) {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved ClientMessage:_NET_WM_PING\n",
                    .{w.handle},
                );
            }
            // ping from the wm to ensure application responsivity.
            // we just need to keep sending ping until the communication
            // is over.
            var reply = libx11.XEvent{ .xclient = e.* };
            reply.xclient.window = x11cntxt.windowManagerId();
            x11cntxt.sendXEvent(&reply, x11cntxt.windowManagerId());
        }
    }
}

fn handleKeyPress(ev: *const libx11.XKeyEvent, window: *Window) void {
    switch (ev.type) {
        libx11.KeyPress => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved KeyPress:code {}\n",
                    .{ window.data.id, ev.keycode },
                );
            }
            const keycode = 0xAA;
            // const keycode = window.widow.internals.lookupKeyCode(@intCast(ev.keycode));
            const scancode = keymaps.keycodeToScancode(@intCast(ev.keycode));
            var mods = utils.decodeKeyMods(ev.state);
            utils.fixKeyMods(&mods, .Up, kbd_mouse.KeyState.Pressed);
            var event = common.event.createKeyboardEvent(
                window.data.id,
                keycode,
                scancode,
                kbd_mouse.KeyState.Pressed,
                mods,
            );
            window.sendEvent(&event);
            var keysym: libx11.KeySym = 0;
            _ = libx11.XLookupString(@constCast(ev), null, 0, &keysym, null);
            if (window.widow.internals.lookupKeyCharacter(keysym)) |codepoint| {
                if (opts.LOG_PLATFORM_EVENTS) {
                    std.log.info(
                        "window: #{} recieved Character:codepoint {}\n",
                        .{ window.data.id, codepoint },
                    );
                }
                event = common.event.createCharEvent(window.data.id, codepoint, mods);
                window.sendEvent(&event);
            }
        },
        libx11.KeyRelease => {
            // used when we can't set auto repeat through xkb.
            const KEY_EVENT_REPEAT_THRESHOLD = 25;
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info("window: #{} recieved KeyPress:code {}\n", .{ window.data.id, ev.keycode });
            }
            const x11driver = X11Driver.singleton();
            if (!x11driver.extensions.xkb.is_auto_repeat_detectable) {
                // INFO:
                // hack from glfw
                // if if we couldn't enable key autorepeat through Xkeyboard
                // extension we can simulate it by reading ahead in the event queue
                // and setting an autorepeat threshold for wich we can ignore key release
                // events.
                if (libx11.XEventsQueued(
                    x11driver.handles.xdisplay,
                    libx11.QueuedAfterReading,
                ) != 0) {
                    var next_xevent: libx11.XEvent = undefined;
                    _ = libx11.XPeekEvent(x11driver.handles.xdisplay, &next_xevent);
                    if (next_xevent.type == libx11.KeyPress and
                        next_xevent.xkey.window == ev.window and
                        next_xevent.xkey.keycode == ev.keycode and
                        (next_xevent.xkey.time - ev.time) < KEY_EVENT_REPEAT_THRESHOLD)
                    {
                        // ignore the current event
                        return;
                    }
                }
            }
            const keycode = window.widow.internals.lookupKeyCode(@intCast(ev.keycode));
            const scancode = keymaps.keycodeToScancode(@intCast(ev.keycode));
            var mods = utils.decodeKeyMods(ev.state);
            utils.fixKeyMods(&mods, keycode, kbd_mouse.KeyState.Released);
            var event = common.event.createKeyboardEvent(
                window.data.id,
                keycode,
                scancode,
                kbd_mouse.KeyState.Released,
                mods,
            );
            window.sendEvent(&event);
        },
        else => unreachable,
    }
}

// fn handleXkbEvent(ev: *const x11ext.XkbEvent, helper_data: *HelperData) void {
//     _ = helper_data;
//     if (opts.LOG_PLATFORM_EVENTS) {
//         std.log.info("window: #hidden recieved XkbEvent\n", .{});
//     }
//     switch (ev.any.xkb_type) {
//         x11ext.XkbStateNotify => {
//             std.debug.print("New group:{}\n", .{ev.state.group});
//             //TODO: keycode map update.
//         },
//         else => {},
//     }
// }

// fn handleXrandrScreenChange(ev: *const libx11.XEvent, helper_data: *HelperData) void {
//     _ = helper_data;
//     if (opts.LOG_PLATFORM_EVENTS) {
//         std.log.info("window: #hidden recieved RRScreenChangeNotify\n", .{});
//     }
//     const x11driver = X11Driver.singleton();
//     _ = x11driver.extensions.xrandr.XRRUpdateConfiguration(@constCast(ev));
//     // TODO: refresh the monitor store data.
//     // helper_data.monitor_store_ptr.?.
// }

// pub fn handleHelperEvent(ev: *const libx11.XEvent, helper_window: libx11.Window) void {
//     const x11driver = X11Driver.singleton();
//     const context_ptr = x11driver.findInXContext(helper_window);
//     if (context_ptr == null) {
//         std.log.err("helper window has no corresponding data in Xcontext, this shouldn't happen.\n", .{});
//         @panic("Unexpected null pointer.");
//     }
//     const helper_data: *HelperData = @ptrCast(@alignCast(context_ptr.?));
//     if (ev.type == x11driver.extensions.xrandr.event_code + x11ext.RRScreenChangeNotify) {
//         handleXrandrScreenChange(ev, helper_data);
//     } else if (x11driver.extensions.xkb.is_available and ev.type == x11driver.extensions.xkb.event_code) {
//         handleXkbEvent(@ptrCast(ev), helper_data);
//     }
// }

pub fn handleWindowEvent(ev: *const libx11.XEvent, window: *Window) void {
    switch (ev.type) {
        libx11.ButtonPress => handleButtonPress(&ev.xbutton, window),
        libx11.ButtonRelease => handleButtonRelease(&ev.xbutton, window),
        libx11.KeyPress, libx11.KeyRelease => handleKeyPress(&ev.xkey, window),

        libx11.EnterNotify => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved EnterNotify\n",
                    .{window.data.id},
                );
            }
            const event = common.event.createMouseEnterEvent(window.data.id);
            window.sendEvent(&event);
            window.data.flags.cursor_in_client = true;
        },
        libx11.LeaveNotify => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved LeaveNotify\n",
                    .{window.data.id},
                );
            }
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseExitEvent(window.data.id);
            window.sendEvent(&event);
        },
        libx11.ClientMessage => handleClientMessage(&ev.xclient, window),
        else => {},
    }
}
