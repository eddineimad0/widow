const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const utils = @import("utils.zig");
const X11Context = @import("global.zig").X11Context;
const keyboard_and_mouse = common.keyboard_and_mouse;
const WindowImpl = @import("window_impl.zig").WindowImpl;

fn handleButtonRelease(e: *const libx11.XButtonEvent, window: *WindowImpl) void {
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

pub fn handleXEvent(ev: *const libx11.XEvent, window: *WindowImpl) void {
    switch (ev.type) {
        libx11.ButtonPress => handleButtonPress(&ev.xbutton, window),
        libx11.ButtonRelease => handleButtonRelease(&ev.xbutton, window),

        libx11.EnterNotify => {
            const event = common.event.createMouseEnterEvent(window.data.id);
            window.sendEvent(&event);
            window.data.flags.cursor_in_client = true;
        },
        libx11.LeaveNotify => {
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseLeftEvent(window.data.id);
            window.sendEvent(&event);
        },
        libx11.DestroyNotify => {
            // TODO: this event doesn't seem to be sent.
            const event = common.event.createCloseEvent(window.data.id);
            window.sendEvent(&event);
        },
        else => {},
    }
}
