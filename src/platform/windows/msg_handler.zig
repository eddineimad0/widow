const std = @import("std");
const wndw = @import("window.zig");
const common = @import("common");
const utils = @import("utils.zig");
const keymap = @import("keymap.zig");
const win32_macros = @import("win32api/macros.zig");
const win32_input = @import("win32api/input.zig");
const win32_gfx = @import("win32api/graphics.zig");
const shell32 = @import("win32api/shell32.zig");
const win32 = std.os.windows;

pub inline fn keyMSGHandler(
    window: *wndw.Window,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) void {
    // The right ALT key is handled as a CTRL+ALT key.
    // for non-U.S. enhanced 102-key keyboards (AltGr),
    // Solution: don't notify the user of the ctrl event.
    if (wparam == win32_input.VK_CONTROL) {
        var next_msg: win32_gfx.MSG = undefined;
        const last_msg_time = win32_gfx.GetMessageTime();
        if (win32_gfx.PeekMessageW(
            &next_msg,
            window.handle,
            0,
            0,
            win32_gfx.PM_NOREMOVE,
        ) == 1) {
            if (next_msg.message == win32_gfx.WM_KEYDOWN or
                next_msg.message == win32_gfx.WM_KEYUP or
                next_msg.message == win32_gfx.WM_SYSKEYDOWN or
                next_msg.message == win32_gfx.WM_SYSKEYUP)
            {
                if (next_msg.wParam == win32_input.VK_MENU and
                    utils.isBitSet(next_msg.lParam, 24) and
                    next_msg.time == last_msg_time)
                {
                    // skip this one
                    return;
                }
            }
        }
    }

    const keycode, const scancode = keymap.translateVirtualKey(
        @truncate(wparam),
        lparam,
    );
    const mods = utils.getKeyModifiers();

    // Determine the action.
    const action = if (win32_macros.hiWord(@bitCast(lparam)) & win32_input.KF_UP == 0)
        common.keyboard_mouse.KeyState.Pressed
    else
        common.keyboard_mouse.KeyState.Released;

    switch (scancode) {
        .LShift => window.win32.input.sticky_keys.l_shift = action,
        .RShift => window.win32.input.sticky_keys.r_shift = action,
        .LSuper => window.win32.input.sticky_keys.l_super = action,
        .RSuper => window.win32.input.sticky_keys.r_super = action,
        else => {},
    }

    // Printscreen key only reports a release action.
    if (wparam == win32_input.VK_SNAPSHOT) {
        const fake_event = common.event.createKeyboardEvent(
            window.data.id,
            keycode,
            scancode,
            .Pressed,
            mods,
        );
        window.sendEvent(&fake_event);
    }

    const event = common.event.createKeyboardEvent(
        window.data.id,
        keycode,
        scancode,
        action,
        mods,
    );
    window.sendEvent(&event);
}

pub inline fn mouseUpMSGHandler(
    window: *wndw.Window,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
) void {
    // Determine the button.
    const button = switch (msg) {
        win32_gfx.WM_LBUTTONUP => common.keyboard_mouse.MouseButton.Left,
        win32_gfx.WM_RBUTTONUP => common.keyboard_mouse.MouseButton.Right,
        win32_gfx.WM_MBUTTONUP => common.keyboard_mouse.MouseButton.Middle,
        else => if (win32_macros.hiWord(wparam) & win32_input.VK_XBUTTON1 == 0)
            common.keyboard_mouse.MouseButton.ExtraButton2
        else
            common.keyboard_mouse.MouseButton.ExtraButton1,
    };

    const event = common.event.createMouseButtonEvent(
        window.data.id,
        button,
        common.keyboard_mouse.KeyState.Released,
        utils.getKeyModifiers(),
    );

    window.sendEvent(&event);

    // Update window's input state.
    window.win32.input.mouse_buttons[@intFromEnum(button)] = .Released;

    // Release Capture if all keys are released.
    var any_button_pressed = false;
    for (&window.win32.input.mouse_buttons) |*action| {
        if (action.* == common.keyboard_mouse.KeyState.Pressed) {
            any_button_pressed = true;
            break;
        }
    }
    if (!any_button_pressed) {
        _ = win32_input.ReleaseCapture();
    }
}

pub inline fn mouseDownMSGHandler(
    window: *wndw.Window,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
) void {
    var any_button_pressed = false;
    for (&window.win32.input.mouse_buttons) |*action| {
        if (action.* == common.keyboard_mouse.KeyState.Pressed) {
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
        // we stop the capture once all buttons are released.
        _ = win32_input.SetCapture(window.handle);
    }

    // Determine the button.
    const button = switch (msg) {
        win32_gfx.WM_LBUTTONDOWN => common.keyboard_mouse.MouseButton.Left,
        win32_gfx.WM_RBUTTONDOWN => common.keyboard_mouse.MouseButton.Right,
        win32_gfx.WM_MBUTTONDOWN => common.keyboard_mouse.MouseButton.Middle,
        else => if (win32_macros.hiWord(wparam) & win32_input.VK_XBUTTON1 == 0)
            common.keyboard_mouse.MouseButton.ExtraButton2
        else
            common.keyboard_mouse.MouseButton.ExtraButton1,
    };

    const event = common.event.createMouseButtonEvent(
        window.data.id,
        button,
        common.keyboard_mouse.KeyState.Pressed,
        utils.getKeyModifiers(),
    );

    window.sendEvent(&event);
    window.win32.input.mouse_buttons[@intFromEnum(button)] = .Pressed;
}

pub inline fn mouseWheelMSGHandler(
    window: *wndw.Window,
    wheel_delta_x: f64,
    wheel_delta_y: f64,
) void {
    const event = common.event.createScrollEvent(
        window.data.id,
        wheel_delta_x,
        wheel_delta_y,
    );
    window.sendEvent(&event);
}

pub inline fn minMaxInfoHandler(window: *wndw.Window, lparam: win32.LPARAM) void {
    const styles = wndw.windowStyles(&window.data.flags);
    const ex_styles = wndw.windowExStyles(&window.data.flags);
    const ulparam: usize = @bitCast(lparam);
    const info: *win32_gfx.MINMAXINFO = @ptrFromInt(ulparam);

    // If the size limitation is set.
    if (window.data.min_size != null or window.data.max_size != null) {

        // Depending on the styles we might need the window's
        // border width and height let's grab them here.
        var rect = win32.RECT{
            .left = 0,
            .top = 0,
            .right = 0,
            .bottom = 0,
        };

        var dpi: ?u32 = null;
        if (window.data.flags.is_dpi_aware) {
            dpi = window.getScalingDPI(null);
        }

        wndw.adjustWindowRect(
            window.ctx.driver,
            &rect,
            styles,
            ex_styles,
            dpi,
        );

        // [Win32api docs]
        // The maximum tracking size is the largest window size
        // that can be produced by using the borders to size the window.
        // The minimum tracking size is the smallest window size
        // that can be produced by using the borders to size the window.
        if (window.data.min_size) |size| {
            info.ptMinTrackSize.x = size.width + (rect.right - rect.left);
            info.ptMinTrackSize.y = size.height + (rect.bottom - rect.top);
        }

        if (window.data.max_size) |size| {
            info.ptMaxTrackSize.x = size.width + (rect.right - rect.left);
            info.ptMaxTrackSize.y = size.height + (rect.bottom - rect.top);
        }
    }

    if (!window.data.flags.is_decorated) {
        // If the window isn't decorated we need to adjust
        // the size and postion for when it's maximized.
        var mi: win32_gfx.MONITORINFO = undefined;
        const monitor_handle = win32_gfx.MonitorFromWindow(
            window.handle,
            win32_gfx.MONITOR_FROM_FLAGS.NEAREST,
        );
        _ = win32_gfx.GetMonitorInfoW(monitor_handle, &mi);
        info.ptMaxPosition.x = mi.rcWork.left - mi.rcMonitor.left;
        info.ptMaxPosition.y = mi.rcWork.top - mi.rcMonitor.top;
        info.ptMaxSize.x = mi.rcWork.right - mi.rcWork.left;
        info.ptMaxSize.y = mi.rcWork.bottom - mi.rcWork.top;
    }
}

pub inline fn dpiScaledSizeHandler(
    window: *wndw.Window,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) void {
    const styles = wndw.windowStyles(&window.data.flags);
    const ex_styles = wndw.windowExStyles(&window.data.flags);
    const new_dpi = win32_macros.loWord(wparam);
    const ulparam: usize = @bitCast(lparam);
    const size: *win32_gfx.SIZE = @ptrFromInt(ulparam);
    const old_dpi = window.getScalingDPI(null);

    var old_nc_size = win32.RECT{
        .left = 0,
        .top = 0,
        .right = 0,
        .bottom = 0,
    };

    var new_nc_size = win32.RECT{
        .left = 0,
        .top = 0,
        .right = 0,
        .bottom = 0,
    };

    wndw.adjustWindowRect(
        window.ctx.driver,
        &old_nc_size,
        styles,
        ex_styles,
        old_dpi,
    );

    wndw.adjustWindowRect(
        window.ctx.driver,
        &new_nc_size,
        styles,
        ex_styles,
        new_dpi,
    );

    size.cx += (new_nc_size.right - new_nc_size.left) -
        (old_nc_size.right - old_nc_size.left);
    size.cy += (new_nc_size.bottom - new_nc_size.top) -
        (old_nc_size.bottom - old_nc_size.top);
}

pub inline fn charEventHandler(window: *wndw.Window, wparam: win32.WPARAM) void {
    const surrogate: u16 = @truncate(wparam);
    if (win32_macros.isHighSurrogate(surrogate)) {
        window.win32.high_surrogate = surrogate;
    } else {
        var codepoint: u32 = 0;
        if (win32_macros.isLowSurrogate(surrogate)) {
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
            const event = common.event.createCharEvent(
                window.data.id,
                codepoint,
                utils.getKeyModifiers(),
            );
            window.sendEvent(&event);
        }
    }
}

pub inline fn dropEventHandler(window: *wndw.Window, wparam: win32.WPARAM) void {
    const allocator = window.ctx.allocator;
    for (window.win32.dropped_files.items) |file| {
        allocator.free(file);
    }

    var wide_slice: []u16 = undefined;
    wide_slice.len = 0;
    window.win32.dropped_files.clearRetainingCapacity();
    const drop_handle: shell32.HDROP = @ptrFromInt(wparam);
    const count = shell32.DragQueryFileW(drop_handle, 0xFFFFFFFF, null, 0);
    if (count != 0) err_exit: {
        if (window.win32.dropped_files.capacity < count) {
            window.win32.dropped_files.ensureTotalCapacity(allocator, count) catch {
                utils.postWindowErrorMsg(
                    wndw.WindowError.OutOfMemory,
                    window.handle,
                );
                break :err_exit;
            };
        }
        for (0..count) |index| {
            const buffer_len = shell32.DragQueryFileW(
                drop_handle,
                @truncate(index),
                null,
                0,
            );
            if (buffer_len != 0) {
                // The returned length doesn't account for the null terminator,
                // however DragQueryFile will write the null terminator
                // even at the cost of not copying the entire data.
                // so it's necessary to add 1
                const buffer_lenz = buffer_len + 1;
                if (wide_slice.len == 0) {
                    wide_slice = allocator.alloc(u16, buffer_lenz) catch {
                        utils.postWindowErrorMsg(
                            wndw.WindowError.OutOfMemory,
                            window.handle,
                        );
                        break :err_exit;
                    };
                } else if (wide_slice.len < buffer_lenz) {
                    wide_slice = allocator.realloc(wide_slice, buffer_lenz) catch {
                        utils.postWindowErrorMsg(
                            wndw.WindowError.OutOfMemory,
                            window.handle,
                        );
                        break :err_exit;
                    };
                }
                _ = shell32.DragQueryFileW(
                    drop_handle,
                    @truncate(index),
                    @ptrCast(wide_slice.ptr),
                    buffer_lenz,
                );
                const file_path = utils.wideToUtf8(
                    allocator,
                    wide_slice.ptr[0..buffer_len],
                ) catch {
                    utils.postWindowErrorMsg(
                        wndw.WindowError.OutOfMemory,
                        window.handle,
                    );
                    break :err_exit;
                };
                window.win32.dropped_files.append(allocator, file_path) catch unreachable;
            }
        }
        const event = common.event.createDropFileEvent(
            window.data.id,
        );
        window.sendEvent(&event);
        if (wide_slice.len != 0) allocator.free(wide_slice);
    }
    shell32.DragFinish(drop_handle);
}
