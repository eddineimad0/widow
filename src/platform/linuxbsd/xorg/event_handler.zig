const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const utils = @import("utils.zig");
const X11Driver = @import("driver.zig").X11Driver;
const keyboard_and_mouse = common.keyboard_and_mouse;
const WindowImpl = @import("window_impl.zig").WindowImpl;

fn handleButtonRelease(e: *const libx11.XButtonEvent, window: *WindowImpl) void {
    // TODO: what about the button cache store.
    if (common.LOG_PLATFORM_EVENTS) {
        std.log.info("window: #{} recieved ButtonRelease\n", .{window.data.id});
    }
    const button_event = switch (e.button) {
        libx11.Button1 => common.event.createMouseButtonEvent(
            window.data.id,
            keyboard_and_mouse.MouseButton.Left,
            keyboard_and_mouse.MouseButtonState.Released,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button2 => common.event.createMouseButtonEvent(
            window.data.id,
            keyboard_and_mouse.MouseButton.Middle,
            keyboard_and_mouse.MouseButtonState.Released,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button3 => common.event.createMouseButtonEvent(
            window.data.id,
            keyboard_and_mouse.MouseButton.Right,
            keyboard_and_mouse.MouseButtonState.Released,
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

fn handleButtonPress(e: *const libx11.XButtonEvent, window: *WindowImpl) void {
    if (common.LOG_PLATFORM_EVENTS) {
        std.log.info("window: #{} recieved ButtonPress\n", .{window.data.id});
    }
    const button_event = switch (e.button) {
        libx11.Button1 => common.event.createMouseButtonEvent(
            window.data.id,
            keyboard_and_mouse.MouseButton.Left,
            keyboard_and_mouse.MouseButtonState.Pressed,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button2 => common.event.createMouseButtonEvent(
            window.data.id,
            keyboard_and_mouse.MouseButton.Middle,
            keyboard_and_mouse.MouseButtonState.Pressed,
            utils.decodeKeyMods(e.state),
        ),
        libx11.Button3 => common.event.createMouseButtonEvent(
            window.data.id,
            keyboard_and_mouse.MouseButton.Right,
            keyboard_and_mouse.MouseButtonState.Pressed,
            utils.decodeKeyMods(e.state),
        ),
        // INFO:
        // [https://github.com/libsdl-org/SDL/blob/main/src/video/x11/SDL_x11events.c#L185C5-L187C80]
        // according to the xlib docs, no specific mouse wheel events exist.
        // However, the defacto standard is that the vertical wheel is X buttons
        // 4 (up) and 5 (down) and a horizontal wheel is 6 (left) and 7 (right).
        libx11.Button4 => common.event.createScrollEvent(
            window.data.id,
            keyboard_and_mouse.MouseWheel.VerticalWheel,
            1.0,
        ),
        libx11.Button5 => common.event.createScrollEvent(
            window.data.id,
            keyboard_and_mouse.MouseWheel.VerticalWheel,
            -1.0,
        ),
        libx11.Button6 => common.event.createScrollEvent(
            window.data.id,
            keyboard_and_mouse.MouseWheel.HorizontalWheel,
            1.0,
        ),
        libx11.Button7 => common.event.createScrollEvent(
            window.data.id,
            keyboard_and_mouse.MouseWheel.HorizontalWheel,
            -1.0,
        ),
        else => {
            std.debug.print("\nbutton:{d}\n", .{e.button});
            return;
        },
    };
    window.sendEvent(&button_event);
}

/// handles ICCCM messages.
fn handleClientMessage(e: *const libx11.XClientMessageEvent, w: *WindowImpl) void {
    const x11cntxt = X11Driver.singleton();
    if (e.message_type == x11cntxt.ewmh.WM_PROTOCOLS) {
        if (@as(libx11.Atom, @intCast(e.data.l[0])) == x11cntxt.ewmh.WM_DELETE_WINDOW) {
            if (common.LOG_PLATFORM_EVENTS) {
                std.log.info("window: #{} recieved ClientMessage:WM_DELETE_WINDOW\n", .{w.handle});
            }
            const event = common.event.createCloseEvent(w.data.id);
            w.sendEvent(&event);
        }
        if (@as(libx11.Atom, @intCast(e.data.l[0])) == x11cntxt.ewmh._NET_WM_PING) {
            if (common.LOG_PLATFORM_EVENTS) {
                std.log.info("window: #{} recieved ClientMessage:_NET_WM_PING\n", .{w.handle});
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

fn handleKeyPress(ev: *const libx11.XKeyEvent, window: *WindowImpl) void {
    const driver = X11Driver.singleton();
    switch (ev.type) {
        libx11.KeyPress => {
            if (common.LOG_PLATFORM_EVENTS) {
                std.log.info("window: #{} recieved KeyPress:code {}\n", .{ window.data.id, ev.keycode });
            }
            const mods = utils.decodeKeyMods(ev.state);
            var event = common.event.createKeyboardEvent(
                window.data.id,
                driver.lookupKeyCode(@intCast(ev.keycode)),
                utils.keycodeToScancode(@intCast(ev.keycode)),
                keyboard_and_mouse.KeyState.Pressed,
                mods,
            );
            window.sendEvent(&event);
            var keysym: libx11.KeySym = 0;
            _ = libx11.XLookupString(@constCast(ev), null, 0, &keysym, null);
            if (driver.lookupKeyCharacter(keysym)) |codepoint| {
                if (common.LOG_PLATFORM_EVENTS) {
                    std.log.info(
                        "window: #{} recieved Character:codepoint {}\n",
                        .{ window.data.id, codepoint },
                    );
                }
                event = common.event.createCharEvent(window.data.id, codepoint, mods);
                window.sendEvent(&event);
            }
        },
        libx11.KeyRelease => std.debug.print("KeyRelease:code {}\n", .{ev.keycode}),
        else => unreachable,
    }
}

pub fn handleXEvent(ev: *const libx11.XEvent, window: *WindowImpl) void {
    switch (ev.type) {
        libx11.ButtonPress => handleButtonPress(&ev.xbutton, window),
        libx11.ButtonRelease => handleButtonRelease(&ev.xbutton, window),
        libx11.KeyPress, libx11.KeyRelease => handleKeyPress(&ev.xkey, window),

        libx11.EnterNotify => {
            if (common.LOG_PLATFORM_EVENTS) {
                std.log.info("window: #{} recieved EnterNotify\n", .{window.data.id});
            }
            const event = common.event.createMouseEnterEvent(window.data.id);
            window.sendEvent(&event);
            window.data.flags.cursor_in_client = true;
        },
        libx11.LeaveNotify => {
            if (common.LOG_PLATFORM_EVENTS) {
                std.log.info("window: #{} recieved LeaveNotify\n", .{window.data.id});
            }
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseLeftEvent(window.data.id);
            window.sendEvent(&event);
        },
        libx11.ClientMessage => handleClientMessage(&ev.xclient, window),
        else => {},
    }
}
