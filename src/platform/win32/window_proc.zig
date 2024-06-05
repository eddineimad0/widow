const std = @import("std");
const win32 = @import("win32_defs.zig");
const zigwin32 = @import("zigwin32");
const utils = @import("utils.zig");
const opt = @import("build-options");
const common = @import("common");
const msg_handler = @import("msg_handler.zig");
const wndw = @import("window.zig");
const display = @import("display.zig");
const Win32Driver = @import("driver.zig").Win32Driver;
const window_msg = zigwin32.ui.windows_and_messaging;
const keyboard_mouse = zigwin32.ui.input.keyboard_and_mouse;
const sys_service = zigwin32.system.system_services;

/// The Window Procedure function.
pub fn mainWindowProc(
    hwnd: win32.HWND,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(win32.WINAPI) isize {
    const window_ref_prop = window_msg.GetPropW(hwnd, wndw.WINDOW_REF_PROP);
    if (window_ref_prop == null) {
        if (msg == window_msg.WM_NCCREATE) {
            // [Win32api Docs]
            // On Windows 10 1607 or above, PMv1 applications may also call
            // EnableNonClientDpiScaling during window_msg.WM_NCCREATE to request
            // that Windows correctly scale the window's non-client area.
            const ulparam: usize = @bitCast(lparam);
            const struct_ptr: *window_msg.CREATESTRUCTW = @ptrFromInt(ulparam);
            const window_data: ?*const common.window_data.WindowData = @ptrCast(
                @alignCast(struct_ptr.*.lpCreateParams),
            );
            if (window_data) |data| {
                const drvr = Win32Driver.singleton();
                if (data.flags.is_dpi_aware and drvr.hints.is_win10b1607_or_above) {
                    _ = drvr.opt_func.EnableNonClientDpiScaling.?(hwnd);
                }
                struct_ptr.lpCreateParams = null;
            }
        }
        // Skip until the window pointer is registered.
        return window_msg.DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    var window: *wndw.Window = @ptrCast(@alignCast(window_ref_prop.?));
    switch (msg) {
        window_msg.WM_CLOSE => {
            // Received upon an attempt to close the window.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a CLOSE event\n", .{window.data.id});
            }
            const event = common.event.createCloseEvent(window.data.id);
            window.sendEvent(&event);
            return 0;
        },

        window_msg.WM_SHOWWINDOW => {
            // Sent when the window is about to be hidden or shown.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SHOWWINDOW event\n", .{window.data.id});
            }
            const event = common.event.createVisibilityEvent(
                window.data.id,
                wparam == win32.TRUE,
            );
            window.sendEvent(&event);
            // Must forward the message to DefWindowProc in order to show or hide the window.
        },

        window_msg.WM_MOUSEACTIVATE => {
            // Sent when the cursor is in an inactive window and
            // the user presses a mouse button.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: {} recieved a MOUSEACTIVATE event\n",
                    .{window.data.id},
                );
            }

            // Delay hiding the window cursor(when in hidden mode)
            // while the user is interacting with the non client area
            // (resizing with borders,grabbing the title bar...),
            // this gives the user a better visual experience.
            if (utils.loWord(@bitCast(lparam)) != window_msg.HTCLIENT) {
                window.win32.frame_action = true;
            }
        },

        window_msg.WM_PAINT => {
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a PAINT event\n", .{window.data.id});
            }
            // var paint: zigwin32.graphics.gdi.PAINTSTRUCT = undefined;
            // const dc = zigwin32.graphics.gdi.BeginPaint(hwnd, &paint);
            // const x = paint.rcPaint.left;
            // const y = paint.rcPaint.top;
            // const w = paint.rcPaint.right - x;
            // const h = paint.rcPaint.bottom - y;
            // _ = zigwin32.graphics.gdi.PatBlt(dc, x, y, w, h, zigwin32.graphics.gdi.BLACKNESS);
            // _ = zigwin32.graphics.gdi.EndPaint(hwnd, &paint);
            const event = common.event.createRedrawEvent(window.data.id);
            window.sendEvent(&event);
        },

        window_msg.WM_KEYUP,
        window_msg.WM_KEYDOWN,
        window_msg.WM_SYSKEYUP,
        window_msg.WM_SYSKEYDOWN,
        => {
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a KEY/SYSKEY event\n", .{window.data.id});
            }
            // Received when a system or a non system key is pressed
            // while window has keyboard focus
            // Note: system key is (Alt+key).
            msg_handler.keyMSGHandler(window, wparam, lparam);
            // don't return immediately.
            // [Win32api Docs]
            // If your window procedure must process a system keystroke message,
            // make sure that after processing the message the procedure passes
            // it to the DefWindowProc function.
        },

        window_msg.WM_NCPAINT => {
            // An application can intercept the window_msg.WM_NCPAINT message
            // and paint its own custom window frame
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a NCPAINT event\n", .{window.data.id});
            }
            if (!window.data.flags.is_decorated or window.data.flags.is_fullscreen) {
                // no need to paint the frame for non decorated(Borderless)
                // or fullscreen windows;
                return 0;
            }
        },

        win32.WM_MOUSELEAVE => {
            // Posted to a window when the cursor leaves the client area
            // of the window specified in a prior call to TrackMouseEvent.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSELEAVE event\n", .{window.data.id});
            }
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseLeftEvent(window.data.id);
            window.sendEvent(&event);
            // All tracking requested by TrackMouseEvent is canceled
            // when this message is generated.
            return 0;
        },

        window_msg.WM_LBUTTONUP,
        window_msg.WM_MBUTTONUP,
        window_msg.WM_RBUTTONUP,
        window_msg.WM_XBUTTONUP,
        => {
            // Received a mouse button is released
            // while the cursor is in the client area of a window.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a BUTTONUP event\n", .{window.data.id});
            }
            msg_handler.mouseUpMSGHandler(window, msg, wparam);
            if (msg == window_msg.WM_XBUTTONUP) {
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        window_msg.WM_LBUTTONDOWN,
        window_msg.WM_MBUTTONDOWN,
        window_msg.WM_RBUTTONDOWN,
        window_msg.WM_XBUTTONDOWN,
        => {
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a BUTTONDOWN event\n", .{window.data.id});
            }
            // Received a mouse button is pressed
            // while the cursor is in the client area of a window.
            msg_handler.mouseDownMSGHandler(window, msg, wparam);
            if (msg == window_msg.WM_XBUTTONDOWN) {
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        window_msg.WM_MOUSEMOVE => {
            // Posted to a window when the cursor moves.
            // If the mouse is not captured,
            // the message is posted to the window that contains the cursor.
            // Otherwise, the message is posted to the window that has captured the mouse.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSEMOVE event\n", .{window.data.id});
            }
            if (!window.data.flags.cursor_in_client) {
                var tme = keyboard_mouse.TRACKMOUSEEVENT{
                    .cbSize = @sizeOf(keyboard_mouse.TRACKMOUSEEVENT),
                    .dwFlags = keyboard_mouse.TME_LEAVE,
                    .hwndTrack = window.handle,
                    .dwHoverTime = 0,
                };
                // Calling TrackMouseEvent in order to receive mouse leave events.
                _ = keyboard_mouse.TrackMouseEvent(&tme);
                const event = common.event.createMouseEnterEvent(window.data.id);
                window.sendEvent(&event);
                window.data.flags.cursor_in_client = true;
            }
            const new_pos = utils.getMousePosition(lparam);
            const event = common.event.createMoveEvent(
                window.data.id,
                new_pos.x,
                new_pos.y,
                true,
            );
            window.sendEvent(&event);
            return 0;
        },

        window_msg.WM_MOUSEWHEEL => {
            // Sent to the active window when the mouse's vertical scroll wheel
            // is tilted or rotated. A positive value indicates that
            // the wheel was rotated forward, away from the user.
            // a negative value indicates that the wheel was rotated
            // backward, toward the user.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSEWHEEL event\n", .{window.data.id});
            }
            const scroll: f32 = @floatFromInt(utils.getYLparam(wparam));
            const wheel_delta = scroll / win32.FWHEEL_DELTA;
            msg_handler.mouseWheelMSGHandler(
                window,
                common.keyboard_mouse.MouseWheel.VerticalWheel,
                wheel_delta,
            );
            return 0;
        },

        window_msg.WM_MOUSEHWHEEL => {
            // Sent to the active window when the mouse's horizontal scroll
            // wheel is tilted or rotated. A positive value indicates that
            // the wheel was rotated left, a negative value indicates
            // that the wheel was rotated right.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSEHWHEEL event\n", .{window.data.id});
            }
            const scroll: f32 = @floatFromInt(utils.getYLparam(wparam));
            const wheel_delta = -(scroll) / win32.FWHEEL_DELTA;
            msg_handler.mouseWheelMSGHandler(
                window,
                common.keyboard_mouse.MouseWheel.HorizontalWheel,
                wheel_delta,
            );
            return 0;
        },

        window_msg.WM_ERASEBKGND => {
            // The message is sent to prepare an invalidated portion
            // of a window for painting. An application should
            // return nonzero in response to window_msg.WM_ERASEBKGND
            // if it processes the message and erases the background.
            // returning true here prevents flickering and
            // allow us to do our own drawing.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a ERASEBKGND event\n", .{window.data.id});
            }
            return win32.TRUE;
        },

        window_msg.WM_GETDPISCALEDSIZE => {
            // [MSDN]
            // This message is received before a window_msg.WM_DPICHANGED
            // for PMv2 awareness, and allows the window to compute its
            // desired size for the pending DPI change.
            // [SDL]
            // Experimentation shows it's only sent during interactive
            // dragging, not in response to SetWindowPos.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a GETDPISCALEDSIZE event\n", .{window.data.id});
            }
            const drvr = Win32Driver.singleton();
            // there is no need to process this message for a dpi aware window
            // for a non dpi aware window processing this messsage is necessary
            // to adjust it's decorations(titlebar,edges...).
            if (!window.data.flags.is_dpi_aware and drvr.hints.is_win10b1607_or_above) {
                msg_handler.dpiScaledSizeHandler(window, wparam, lparam);
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        window_msg.WM_DPICHANGED => {
            // Sent when the effective dots per inch (dpi) for a window has changed.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a DPICHANGED event\n", .{window.data.id});
            }
            const suggested_rect: *win32.RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
            const new_dpi = utils.loWord(wparam);
            const scale = @as(f64, @floatFromInt(new_dpi)) / win32.USER_DEFAULT_SCREEN_DPI_F;
            const flags = window_msg.SET_WINDOW_POS_FLAGS{
                .NOACTIVATE = 1,
                .NOZORDER = 1,
                .NOOWNERZORDER = 1,
            };
            const top = if (window.data.flags.is_topmost)
                window_msg.HWND_TOPMOST
            else
                window_msg.HWND_NOTOPMOST;

            _ = window_msg.SetWindowPos(
                window.handle,
                top,
                suggested_rect.left,
                suggested_rect.top,
                suggested_rect.right - suggested_rect.left,
                suggested_rect.bottom - suggested_rect.top,
                flags,
            );
            const event = common.event.createDPIEvent(window.data.id, new_dpi, scale);
            window.sendEvent(&event);
            return 0;
        },

        window_msg.WM_GETMINMAXINFO => {
            // Sent to a window when the size or position of the window is about
            // to change. An application can use this message to override
            // the window's default maximized size and position,
            // or its default minimum or maximum tracking size.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a GETMINMAXINFO event\n", .{window.data.id});
            }
            if (!window.data.flags.is_fullscreen) {
                msg_handler.minMaxInfoHandler(window, lparam);
            }
            return 0;
        },

        window_msg.WM_SIZING => {
            // Sent to a window that the user is currently resizing.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SIZING event\n", .{window.data.id});
            }
            if (window.data.aspect_ratio != null) {
                const ulparam: usize = @bitCast(lparam);
                const drag_rect_ptr: *win32.RECT = @ptrFromInt(ulparam);
                window.applyAspectRatio(drag_rect_ptr, @truncate(wparam));
            }
            return win32.TRUE;
        },

        window_msg.WM_SIZE => {
            // Sent to a window after its size has changed.
            // usually due to maximizing, minimizing, resizing...etc.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SIZE event\n", .{window.data.id});
            }
            const maximized = (wparam == window_msg.SIZE_MAXIMIZED);
            if (window.data.flags.is_maximized != maximized and maximized) {
                const event = common.event.createMaximizeEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            const minimized = (wparam == window_msg.SIZE_MINIMIZED);
            if (window.data.flags.is_minimized != minimized and minimized) {
                const event = common.event.createMinimizeEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            const restored = (wparam == window_msg.SIZE_RESTORED and
                (window.data.flags.is_minimized or window.data.flags.is_maximized));
            if (restored) {
                const event = common.event.createRestoreEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            window.data.flags.is_maximized = maximized;
            window.data.flags.is_minimized = minimized;

            const new_width: i32 = @intCast(utils.loWord(@bitCast(lparam)));
            const new_height: i32 = @intCast(utils.hiWord(@bitCast(lparam)));

            if (minimized or (window.data.client_area.size.width == new_width and
                window.data.client_area.size.height == new_height))
            {
                // No need to report duplicate events.
                // On minimize window the system resizes the window to a width = 0 and height = 0;
                // we only report meaningfull changes to the size.
                return 0;
            }

            window.data.client_area.size.width = @intCast(new_width);
            window.data.client_area.size.height = @intCast(new_height);

            // For windows that allows resizing by dragging it's edges,
            // this message is received multiple times during the resize process
            // causing ton of events allocations.
            const event = common.event.createResizeEvent(
                window.data.id,
                @intCast(new_width),
                @intCast(new_height),
            );
            window.sendEvent(&event);

            return 0;
        },

        window_msg.WM_MOVE => blk: {
            // Sent after a window has been moved.
            // the lparam holds the new client top left coords.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOVE event\n", .{window.data.id});
            }
            // Our minimized flag is still not set so check using the winapi.
            if (window_msg.IsIconic(window.handle) != 0) {
                // if the window was minimized don't update the top left position.
                break :blk;
            }

            const xpos = utils.getXLparam(@bitCast(lparam));
            const ypos = utils.getYLparam(@bitCast(lparam));

            if (window.data.client_area.top_left.x == xpos and
                window.data.client_area.top_left.y == ypos)
            {
                // No need to report duplicate events.
                break :blk;
            }

            window.data.client_area.top_left.x = xpos;
            window.data.client_area.top_left.y = ypos;

            if (!window.win32.frame_action) {
                const event = common.event.createMoveEvent(
                    window.data.id,
                    window.data.client_area.top_left.x,
                    window.data.client_area.top_left.y,
                    false,
                );
                window.sendEvent(&event);
            } else {
                // If the user is dragging the window around
                // we'll set this flag and send the final
                // coordinates once the user stops.
                window.win32.position_update = true;
            }
        },

        window_msg.WM_SETCURSOR => {
            // Sent if the mouse causes the cursor
            // to move within a window and mouse input is not captured.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SETCURSOR event\n", .{window.data.id});
            }
            if (utils.loWord(@bitCast(lparam)) == window_msg.HTCLIENT) {
                // the mouse just moved into the client area
                // update the cursor image acording to the current mode;
                wndw.applyCursorHints(&window.win32.cursor, window.handle);
                return win32.TRUE;
            }
        },

        window_msg.WM_SETFOCUS => {
            // Sent to a window after it has gained the keyboard focus.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SETFOCUS event\n", .{window.data.id});
            }
            const event = common.event.createFocusEvent(window.data.id, true);
            window.sendEvent(&event);
            window.data.flags.is_focused = true;
            if (!window.win32.frame_action) {
                // Don't disable or capture the cursor.
                // until the frame action is done.
                wndw.applyCursorHints(&window.win32.cursor, window.handle);
            }
            return 0;
        },

        window_msg.WM_KILLFOCUS => {
            // Sent to a window immediately before it loses the keyboard focus.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a KILLFOCUS event\n", .{window.data.id});
            }

            wndw.restoreCursor(&window.win32.cursor);

            const event = common.event.createFocusEvent(window.data.id, false);
            window.sendEvent(&event);
            window.data.flags.is_focused = false;
            return 0;
        },

        window_msg.WM_SYSCOMMAND => {
            // In window_msg.WM_SYSCOMMAND messages, the four low-order bits of the wParam
            // parameter are used internally by the system.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SYSCOMMAND event\n", .{window.data.id});
            }
            switch (wparam & 0xFFF0) {
                win32.SC_SCREENSAVE, win32.SC_MONITORPOWER => {
                    if (window.data.flags.is_fullscreen) {
                        // No screen saver for fullscreen mode
                        return 0;
                    }
                },

                else => {
                    // Let DefWindowProcW handle it;
                },
            }
        },

        win32.WM_UNICHAR => {
            // The window_msg.WM_UNICHAR message can be used by an application
            // to post input to other windows.
            // (Tests whether a target app can process window_msg.WM_UNICHAR
            // messages by sending the message with wParam
            // set to UNICODE_NOCHAR.)
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a UNICHAR event\n", .{window.data.id});
            }
            if (wparam == window_msg.UNICODE_NOCHAR) {
                // If wParam is UNICODE_NOCHAR and the application support this message,
                return win32.TRUE;
            }

            // The window_msg.WM_UNICHAR message is similar to WM_CHAR,
            // but it uses Unicode Transformation Format (UTF)-32
            const event = common.event.createCharEvent(
                window.data.id,
                @truncate(wparam),
                utils.getKeyModifiers(),
            );
            window.sendEvent(&event);
            return 0;
        },

        window_msg.WM_SYSCHAR, window_msg.WM_CHAR => {
            // Posted to the window with the keyboard focus
            // when a window_msg.WM_SYSKEYDOWN | WM_KEYDOWN
            // message is translated by the TranslateMessage function.
            // WM_CHAR | WM_SYSCHAR message uses UTF-16
            // code units in its wParam if the Unicode version of the
            // RegisterClass function was used
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SYSCHAR/CHAR event\n", .{window.data.id});
            }
            msg_handler.charEventHandler(window, wparam);
            if (msg != window_msg.WM_SYSCHAR) {
                return 0;
            }
        },

        window_msg.WM_ENTERSIZEMOVE => {
            // Sent one time to a window after it enters
            // the moving or sizing loop,
            // The window enters the moving or sizing
            // loop when the user clicks the window's title bar or sizing border
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a ENTERSIZEMOVE event\n", .{window.data.id});
            }
            window.win32.frame_action = true;
        },

        window_msg.WM_EXITSIZEMOVE => {
            // now we should report the resize and postion change events.

            // the frame action is done treat the cursor
            // acording to the mode.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a EXITSIZEMOVE event\n", .{window.data.id});
            }

            wndw.applyCursorHints(&window.win32.cursor, window.handle);

            // Send any new position events.
            if (window.win32.position_update) {
                const event = common.event.createMoveEvent(
                    window.data.id,
                    window.data.client_area.top_left.x,
                    window.data.client_area.top_left.y,
                    false,
                );
                window.sendEvent(&event);
                window.win32.position_update = false;
            }
            window.win32.frame_action = false;
        },

        window_msg.WM_DROPFILES => {
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a DROPFILES event\n", .{window.data.id});
            }
            msg_handler.dropEventHandler(window, wparam);
            return 0;
        },
        else => {},
    }
    return window_msg.DefWindowProcW(hwnd, msg, wparam, lparam);
}
