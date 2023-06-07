const std = @import("std");
const winapi = @import("win32");
const window_impl = @import("./window_impl.zig");
const common = @import("common");
const utils = @import("utils.zig");
const win32_window_messaging = winapi.ui.windows_and_messaging;
const win32_keyboard_mouse = winapi.ui.input.keyboard_and_mouse;
const win32_gdi = winapi.graphics.gdi;
const win32_foundation = winapi.foundation;

pub inline fn closeMSGHandler(window: *window_impl.WindowImpl) void {
    // we can ask user for confirmation before closing
    // here.
    const event = common.event.createCloseEvent();
    window.queueEvent(&event);
}

pub inline fn keyMSGHandler(window: *window_impl.WindowImpl, wparam: win32_foundation.WPARAM, lparam: win32_foundation.LPARAM) void {
    // Note: the right ALT key is handled as a CTRL+ALT key.
    // for non-U.S. enhanced 102-key keyboards (AltGr),
    // Solution: don't notify the user of the ctrl event.
    if (wparam == @enumToInt(win32_keyboard_mouse.VK_CONTROL)) {
        var next_msg: win32_window_messaging.MSG = undefined;
        const last_msg_time = win32_window_messaging.GetMessageTime();
        if (win32_window_messaging.PeekMessageW(&next_msg, window.handle, 0, 0, win32_window_messaging.PM_NOREMOVE) == 1) {
            if (next_msg.message == win32_window_messaging.WM_KEYDOWN or next_msg.message == win32_window_messaging.WM_KEYUP or next_msg.message == win32_window_messaging.WM_SYSKEYDOWN or next_msg.message == win32_window_messaging.WM_SYSKEYUP) {
                if (next_msg.wParam == @enumToInt(win32_keyboard_mouse.VK_MENU) and utils.isBitSet(next_msg.lParam, 24) and next_msg.time == last_msg_time) {
                    // skip this one
                    return;
                }
            }
        }
    }

    const keys = utils.getKeyCodes(@truncate(u16, wparam), lparam);
    const mods = utils.getKeyModifiers();

    // Determine the action.
    var action = if (utils.hiWord(@bitCast(usize, lparam)) & win32_window_messaging.KF_UP == 0)
        common.input.KeyAction.Press
    else
        common.input.KeyAction.Release;

    if (keys[1] != common.input.ScanCode.Unknown) {
        // Update the key state array.
        window.data.input.keys[@intCast(usize, @enumToInt(keys[1]))] = action;
    }

    // Printscreen key only reports a release action.
    if (wparam == @enumToInt(win32_keyboard_mouse.VK_SNAPSHOT)) {
        const fake_event = common.event.createKeyboardEvent(keys[0], keys[1], common.input.KeyAction.Press, mods);
        window.queueEvent(&fake_event);
    }

    const event = common.event.createKeyboardEvent(keys[0], keys[1], action, mods);
    window.queueEvent(&event);
}

pub inline fn mouseUpMSGHandler(window: *window_impl.WindowImpl, msg: u32, wparam: win32_foundation.WPARAM) void {
    const button = switch (msg) {
        win32_window_messaging.WM_LBUTTONUP => common.input.MouseButton.Left,
        win32_window_messaging.WM_RBUTTONUP => common.input.MouseButton.Right,
        win32_window_messaging.WM_MBUTTONUP => common.input.MouseButton.Middle,
        else => if (utils.hiWord(wparam) & @enumToInt(win32_keyboard_mouse.VK_XBUTTON1) == 0)
            common.input.MouseButton.ExtraButton2
        else
            common.input.MouseButton.ExtraButton1,
    };

    const event = common.event.createMouseButtonEvent(button, common.input.KeyAction.Release, utils.getKeyModifiers());

    window.queueEvent(&event);

    window.data.input.mouse_buttons[@enumToInt(button)] = common.input.KeyAction.Release;

    // Release Capture if all keys are released.
    var any_button_pressed = false;
    for (&window.data.input.mouse_buttons) |*action| {
        if (action.* == common.input.KeyAction.Press) {
            any_button_pressed = true;
            break;
        }
    }

    if (!any_button_pressed) {
        _ = win32_keyboard_mouse.ReleaseCapture();
    }
}

pub inline fn mouseDownMSGHandler(window: *window_impl.WindowImpl, msg: u32, wparam: win32_foundation.WPARAM) void {
    var any_button_pressed = false;
    for (&window.data.input.mouse_buttons) |*action| {
        if (action.* == common.input.KeyAction.Press) {
            any_button_pressed = true;
            break;
        }
    }

    if (!any_button_pressed) {
        // After this function is called,
        // the window will continue to receive WM_MOUSEMOVE
        // messages for as long as the user holds at least
        // one mouse button down, even if the mouse quits
        // the window area.
        _ = win32_keyboard_mouse.SetCapture(window.handle);
    }

    const button = switch (msg) {
        win32_window_messaging.WM_LBUTTONDOWN => common.input.MouseButton.Left,
        win32_window_messaging.WM_RBUTTONDOWN => common.input.MouseButton.Right,
        win32_window_messaging.WM_MBUTTONDOWN => common.input.MouseButton.Middle,
        else => if (utils.hiWord(wparam) & @enumToInt(win32_keyboard_mouse.VK_XBUTTON1) == 0)
            common.input.MouseButton.ExtraButton2
        else
            common.input.MouseButton.ExtraButton1,
    };

    const event = common.event.createMouseButtonEvent(button, common.input.KeyAction.Press, utils.getKeyModifiers());

    window.queueEvent(&event);
    window.data.input.mouse_buttons[@enumToInt(button)] = common.input.KeyAction.Press;
}

pub inline fn mouseWheelMSGHandler(window: *window_impl.WindowImpl, wheel: common.input.MouseWheel, wheel_delta: f64) void {
    const event = common.event.createScrollEvent(wheel, wheel_delta);
    window.queueEvent(&event);
}

pub inline fn minMaxInfoHandler(window: *window_impl.WindowImpl, lparam: win32_foundation.LPARAM) void {
    const styles = window_impl.windowStyles(&window.data);
    const ex_styles = window_impl.windowExStyles(&window.data);
    const info: *win32_window_messaging.MINMAXINFO = @intToPtr(*win32_window_messaging.MINMAXINFO, @bitCast(usize, lparam));
    var rect = win32_foundation.RECT{
        .left = 0,
        .top = 0,
        .right = 0,
        .bottom = 0,
    };

    window_impl.adjustWindowRect(
        &rect,
        window.internals.win32.functions.AdjustWindowRectExForDpi,
        styles,
        ex_styles,
        window.scalingDPI(null),
    );

    // [Win32api docs]
    // The maximum tracking size is the largest window size that can be produced
    // by using the borders to size the window.
    // The minimum tracking size is the smallest window size that can be produced
    // by using the borders to size the window.
    if (window.data.min_size) |size| {
        info.ptMinTrackSize.x = size.width + (rect.right - rect.left);
        info.ptMinTrackSize.y = size.height + (rect.bottom - rect.top);
    }

    if (window.data.max_size) |size| {
        info.ptMaxTrackSize.x = size.width + (rect.right - rect.left);
        info.ptMaxTrackSize.y = size.height + (rect.bottom - rect.top);
    }

    if (!window.data.flags.is_decorated) {
        var mi: win32_gdi.MONITORINFO = undefined;
        const monitor_handle = win32_gdi.MonitorFromWindow(window.handle, win32_gdi.MONITOR_DEFAULTTONEAREST);
        _ = win32_gdi.GetMonitorInfoW(monitor_handle, &mi);
        info.ptMaxPosition.x = mi.rcWork.left - mi.rcWork.left;
        info.ptMaxPosition.y = mi.rcWork.top - mi.rcWork.top;
        info.ptMaxSize.x = mi.rcWork.right - mi.rcWork.left;
        info.ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
    }
}

//**
pub inline fn dpiScaledSizeHandler(window: *window_impl.WindowImpl, wparam: win32_foundation.WPARAM, lparam: win32_foundation.LPARAM) bool {
    if (window.internals.win32.flags.is_win10b1607_or_above) {
        var pending_size = win32_foundation.RECT{
            .left = 0,
            .top = 0,
            .right = 0,
            .bottom = 0,
        };

        const styles = window_impl.windowStyles(&window.data);
        const ex_styles = window_impl.windowExStyles(&window.data);
        const new_dpi = utils.loWord(wparam);
        std.debug.print("scaled_size new DPI:{}\n", .{new_dpi});

        window_impl.adjustWindowRect(
            &pending_size,
            window.internals.win32.functions.AdjustWindowRectExForDpi,
            styles,
            ex_styles,
            new_dpi,
        );

        var desired_size = win32_foundation.RECT{
            .left = 0,
            .top = 0,
            .right = 0,
            .bottom = 0,
        };

        window_impl.adjustWindowRect(
            &desired_size,
            window.internals.win32.functions.AdjustWindowRectExForDpi,
            styles,
            ex_styles,
            new_dpi,
        );

        const size: *win32_foundation.SIZE = @intToPtr(*win32_foundation.SIZE, @bitCast(usize, lparam));
        size.cx += (desired_size.right - desired_size.left) - (pending_size.right - pending_size.left);
        size.cy += (desired_size.bottom - desired_size.top) - (pending_size.bottom - pending_size.top);
        return true;
    }
    return false;
}

pub inline fn charEventHandler(window: *window_impl.WindowImpl, wparam: win32_foundation.WPARAM) void {
    const surrogate = @truncate(u16, wparam);
    if (utils.isHighSurrogate(surrogate)) {
        window.win32.high_surrogate = surrogate;
    } else {
        var codepoint: u32 = 0;
        if (utils.isLowSurrogate(surrogate)) {
            if (window.win32.high_surrogate > 0) {
                codepoint += ((window.win32.high_surrogate - 0xD800) << 10);
                codepoint += (surrogate - 0xDC00);
                codepoint += 0x10000;
            }
        } else {
            window.win32.high_surrogate = 0;
            codepoint = surrogate;
        }

        if (codepoint > 0x1F and (codepoint < 0x7F or codepoint > 0x9F)) {
            const event = common.event.createCharEvent(codepoint, utils.getKeyModifiers());
            window.queueEvent(&event);
        }
    }
}