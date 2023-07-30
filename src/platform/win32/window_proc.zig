const std = @import("std");
const win32 = @import("win32_defs.zig");
const zigwin32 = @import("zigwin32");
const utils = @import("./utils.zig");
const common = @import("common");
const HelperData = @import("./internals.zig").HelperData;
const Win32Context = @import("./global.zig").Win32Context;
const window_impl = @import("./window_impl.zig");
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const win32_keyboard_mouse = zigwin32.ui.input.keyboard_and_mouse;
const win32_sys_service = zigwin32.system.system_services;

/// The procedure function for the helper window
pub fn helperWindowProc(
    hwnd: win32.HWND,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(win32.WINAPI) isize {
    const user_data = win32_window_messaging.GetWindowLongPtrW(hwnd, win32_window_messaging.GWLP_USERDATA);
    if (user_data != 0) {
        const devices = @intToPtr(*HelperData, @intCast(usize, user_data));

        switch (msg) {
            win32_window_messaging.WM_DISPLAYCHANGE => {
                // Monitor the win32_window_messaging.WM_DISPLAYCHANGE notification
                // to detect when settings change or when a
                // display is added or removed.
                if (devices.monitor_store_ptr) |store| {
                    if (!store.expected_video_change) {
                        std.debug.print("[+] WM_DISPLAYCHANGE\n", .{});
                        store.refreshMonitorsMap() catch |err| {
                            std.log.err("[Monitor]: Failed to refresh monitors,{}\n", .{err});
                        };
                    }
                }
            },

            win32_window_messaging.WM_DRAWCLIPBOARD => {
                // Sent When The clipboard content gets updated.
                devices.clipboard_change = true;
                std.debug.print("[+] Clipboard Updated\n", .{});
                if (devices.next_clipboard_viewer) |viewer| {
                    std.debug.print("Forwarding msg to next viewer\n", .{});
                    _ = win32_window_messaging.SendMessage(viewer, msg, wparam, lparam);
                }
            },
            win32_window_messaging.WM_CHANGECBCHAIN => {
                // Sent When one of the clipboard viewers is getting removed.
                if (devices.next_clipboard_viewer) |viewer| {
                    if (wparam == @ptrToInt(viewer)) {
                        devices.next_clipboard_viewer = @intToPtr(?win32.HWND, @bitCast(usize, lparam));
                    } else {
                        _ = win32_window_messaging.SendMessage(devices.next_clipboard_viewer, msg, wparam, lparam);
                    }
                }
                // last in the chain.
                return 0;
            },
            win32_window_messaging.WM_DEVICECHANGE => exit_point: {
                // Notifies an application of a change to the hardware configuration
                // of a device or the computer.
                const jss = devices.joysubsys_ptr orelse break :exit_point;
                const dbh_ptr = @intToPtr(?*win32_sys_service.DEV_BROADCAST_HDR, @bitCast(usize, lparam));
                switch (wparam) {
                    win32_sys_service.DBT_DEVICEARRIVAL => {
                        if (dbh_ptr) |ptr| {
                            if (ptr.dbch_devicetype == win32_sys_service.DBT_DEVTYP_DEVICEINTERFACE) {
                                jss.queryConnectedJoys();
                            }
                        }
                    },
                    win32_sys_service.DBT_DEVICEREMOVECOMPLETE => {
                        if (dbh_ptr) |ptr| {
                            if (ptr.dbch_devicetype == win32_sys_service.DBT_DEVTYP_DEVICEINTERFACE) {
                                jss.queryDisconnectedJoys();
                            }
                        }
                    },
                    else => {
                        break :exit_point;
                    },
                }
            },
            else => {},
        }
    }
    return win32_window_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
}

const message_handler = @import("message_handler.zig");

/// The Window Procedure function.
pub fn mainWindowProc(
    hwnd: win32.HWND,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(win32.WINAPI) isize {
    // Get a mutable refrence to the corresponding WindowImpl Structure.
    const window_user_data = win32_window_messaging.GetWindowLongPtrW(hwnd, win32_window_messaging.GWLP_USERDATA);
    var window = @intToPtr(?*window_impl.WindowImpl, @bitCast(usize, window_user_data)) orelse {
        if (msg == win32_window_messaging.WM_NCCREATE) {
            // [Win32api Docs]
            // On Windows 10 1607 or above, PMv1 applications may also call
            // EnableNonClientDpiScaling during win32_window_messaging.WM_NCCREATE to request
            // that Windows correctly scale the window's non-client area.
            const creation_struct_ptr: *win32_window_messaging.CREATESTRUCTW = @intToPtr(
                *win32_window_messaging.CREATESTRUCTW,
                @bitCast(usize, lparam),
            );
            const window_data = @ptrCast(
                *const common.window_data.WindowData,
                @alignCast(8, creation_struct_ptr.*.lpCreateParams),
            );
            const globl_data = Win32Context.singleton();
            if (window_data.flags.is_dpi_aware and globl_data.flags.is_win10b1607_or_above) {
                _ = globl_data.functions.EnableNonClientDpiScaling.?(hwnd);
            }
            creation_struct_ptr.lpCreateParams = null;
        }
        // Skip until the window pointer is registered.
        return win32_window_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
    };

    switch (msg) {
        win32_window_messaging.WM_CLOSE => {
            // Received upon an attempt to close the window.
            message_handler.closeMSGHandler(window);
            return 0;
        },

        win32_window_messaging.WM_SHOWWINDOW => {
            // Sent to a window when the window is about to be hidden or shown.
            const event = common.event.createVisibilityEvent(
                window.data.id,
                wparam == win32.TRUE,
            );
            window.sendEvent(&event);
            // Must forward the message to DefWindowProc in order to show or hide the window.
        },

        win32_window_messaging.WM_MOUSEACTIVATE => {
            // Sent when the cursor is in an inactive window and the user presses a mouse button.

            // We only use this message to delay hiding the window cursor(when the in disabled mode)
            // while the user is interacting with the non client area (resizing with borders,grabbing the title bar...),
            // this gives the user a better visual experience.
            if (utils.loWord(@bitCast(usize, lparam)) != win32_window_messaging.HTCLIENT) {
                window.win32.frame_action = true;
            }
        },

        win32_window_messaging.WM_PAINT => {
            var paint: zigwin32.graphics.gdi.PAINTSTRUCT = undefined;
            const dc = zigwin32.graphics.gdi.BeginPaint(hwnd, &paint);
            const x = paint.rcPaint.left;
            const y = paint.rcPaint.top;
            const w = paint.rcPaint.right - x;
            const h = paint.rcPaint.bottom - y;
            _ = zigwin32.graphics.gdi.PatBlt(dc, x, y, w, h, zigwin32.graphics.gdi.BLACKNESS);
            _ = zigwin32.graphics.gdi.EndPaint(hwnd, &paint);
        },

        win32_window_messaging.WM_KEYUP,
        win32_window_messaging.WM_KEYDOWN,
        win32_window_messaging.WM_SYSKEYUP,
        win32_window_messaging.WM_SYSKEYDOWN,
        => {
            // Received when a system or a non system key is pressed
            // while window has keyboard focus
            // Note: system key is (Alt+key).
            message_handler.keyMSGHandler(window, wparam, lparam);
            // [Win32api Docs]
            // If your window procedure must process a system keystroke message,
            // make sure that after processing the message the procedure passes
            // it to the DefWindowProc function.
        },

        win32_window_messaging.WM_NCPAINT => {
            // An application can intercept the win32_window_messaging.WM_NCPAINT message
            // and paint its own custom window frame
            if (!window.data.flags.is_decorated or window.data.flags.is_fullscreen) {
                // no need to paint the frame for non decorated(Borderless)
                // or fullscrenn windows;
                return 0;
            }
        },

        win32.WM_MOUSELEAVE => {
            // Posted to a window when the cursor leaves the client area
            // of the window specified in a prior call to TrackMouseEvent.
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseLeftEvent(window.data.id);
            window.sendEvent(&event);
            // All tracking requested by TrackMouseEvent is canceled when this message is generated.
            return 0;
        },

        win32_window_messaging.WM_LBUTTONUP,
        win32_window_messaging.WM_MBUTTONUP,
        win32_window_messaging.WM_RBUTTONUP,
        win32_window_messaging.WM_XBUTTONUP,
        => {
            // Received a mouse button is released
            // while the cursor is in the client area of a window.
            message_handler.mouseUpMSGHandler(window, msg, wparam);
            if (msg == win32_window_messaging.WM_XBUTTONUP) {
                return win32.TRUE;
            }
            return 0;
        },

        win32_window_messaging.WM_LBUTTONDOWN,
        win32_window_messaging.WM_MBUTTONDOWN,
        win32_window_messaging.WM_RBUTTONDOWN,
        win32_window_messaging.WM_XBUTTONDOWN,
        => {
            // Received a mouse button is pressed
            // while the cursor is in the client area of a window.
            message_handler.mouseDownMSGHandler(window, msg, wparam);
            if (msg == win32_window_messaging.WM_XBUTTONDOWN) {
                return win32.TRUE;
            }
            return 0;
        },

        win32_window_messaging.WM_MOUSEMOVE => {
            // Posted to a window when the cursor moves.
            // If the mouse is not captured,
            // the message is posted to the window that contains the cursor.
            // Otherwise, the message is posted to the window that has captured the mouse.
            if (!window.data.flags.cursor_in_client) {
                var tme = win32_keyboard_mouse.TRACKMOUSEEVENT{
                    .cbSize = @sizeOf(win32_keyboard_mouse.TRACKMOUSEEVENT),
                    .dwFlags = win32_keyboard_mouse.TME_LEAVE,
                    .hwndTrack = window.handle,
                    .dwHoverTime = 0,
                };
                // Calling TrackMouseEvent in order to receive mouse leave events.
                _ = win32_keyboard_mouse.TrackMouseEvent(&tme);
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

        win32_window_messaging.WM_MOUSEWHEEL => {
            // Sent to the active window when the mouse's vertical scroll wheel is tilted or rotated.
            // A positive value indicates that the wheel was rotated forward,
            // away from the user.
            // a negative value indicates that the wheel was rotated backward, toward the user.
            const wheel_delta = @intToFloat(f64, utils.getYLparam(wparam)) / @intToFloat(f64, win32_window_messaging.WHEEL_DELTA);
            message_handler.mouseWheelMSGHandler(window, common.keyboard_and_mouse.MouseWheel.VerticalWheel, wheel_delta);
            return 0;
        },

        win32_window_messaging.WM_MOUSEHWHEEL => {
            // Sent to the active window when the mouse's horizontal scroll wheel is tilted or rotated.
            // A positive value indicates that the wheel was rotated left,
            // a negative value indicates that the wheel was rotated right.
            const wheel_delta = -(@intToFloat(f64, utils.getYLparam(wparam)) / @intToFloat(f64, win32_window_messaging.WHEEL_DELTA));
            message_handler.mouseWheelMSGHandler(window, common.keyboard_and_mouse.MouseWheel.HorizontalWheel, wheel_delta);
            return 0;
        },

        win32_window_messaging.WM_ERASEBKGND => {
            // The message is sent to prepare an invalidated portion of a window for painting.
            // An application should return nonzero in response to win32_window_messaging.WM_ERASEBKGND
            // if it processes the message and erases the background.
            // returning true here prevents flickering and allow us to do our own drawing.
            return win32.TRUE;
        },

        win32_window_messaging.WM_GETDPISCALEDSIZE => {
            // [MSDN]
            // This message is received before a win32_window_messaging.WM_DPICHANGED
            // for PMv2 awareness, and allows the window to compute its desired size
            // for the pending DPI change.
            // [SDL]
            // Experimentation shows it's only sent during interactive dragging, not in response to
            // SetWindowPos.
            const globl_cntxt = Win32Context.singleton();
            // there is no need to process this message for a dpi aware window
            // for a non dpi aware window processing this message allows it
            // to keep a constant width and height.
            if (!window.data.flags.is_dpi_aware and globl_cntxt.flags.is_win10b1607_or_above) {
                message_handler.dpiScaledSizeHandler(window, wparam, lparam);
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        win32_window_messaging.WM_DPICHANGED => {
            // Sent when the effective dots per inch (dpi) for a window has changed.
            const suggested_rect: *win32.RECT = @intToPtr(*win32.RECT, @bitCast(usize, lparam));
            const new_dpi = utils.loWord(wparam);
            const scale = @intToFloat(f64, new_dpi) / @intToFloat(f64, win32_window_messaging.USER_DEFAULT_SCREEN_DPI);
            const flags = @enumToInt(win32_window_messaging.SWP_NOACTIVATE) |
                @enumToInt(win32_window_messaging.SWP_NOZORDER) |
                @enumToInt(win32_window_messaging.SWP_NOREPOSITION);
            const top = if (window.data.flags.is_topmost)
                win32_window_messaging.HWND_TOPMOST
            else
                win32_window_messaging.HWND_NOTOPMOST;

            _ = win32_window_messaging.SetWindowPos(
                window.handle,
                top,
                suggested_rect.left,
                suggested_rect.top,
                suggested_rect.right - suggested_rect.left,
                suggested_rect.bottom - suggested_rect.top,
                @intToEnum(win32_window_messaging.SET_WINDOW_POS_FLAGS, flags),
            );
            const event = common.event.createDPIEvent(window.data.id, new_dpi, scale);
            window.sendEvent(&event);
            return 0;
        },

        win32_window_messaging.WM_GETMINMAXINFO => {
            // Sent to a window when the size or position of the window is about to change.
            // An application can use this message to override the window's default
            // maximized size and position, or its default minimum or maximum tracking size.
            if (!window.data.flags.is_fullscreen) {
                message_handler.minMaxInfoHandler(window, lparam);
            }
            return 0;
        },

        win32_window_messaging.WM_SIZING => {
            // Sent to a window that the user is currently resizing.
            if (window.data.aspect_ratio != null) {
                const drag_rect_ptr = @intToPtr(*win32.RECT, @bitCast(usize, lparam));
                window.applyAspectRatio(drag_rect_ptr, @truncate(u32, wparam));
            }
            return win32.TRUE;
        },

        win32_window_messaging.WM_SIZE => {
            // Sent to a window after its size has changed.
            // usually due to maximizing, minimizing, resizing...etc.

            const maximized = (wparam == win32_window_messaging.SIZE_MAXIMIZED);
            if (window.data.flags.is_maximized != maximized and maximized) {
                const event = common.event.createMaximizeEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            const minimized = (wparam == win32_window_messaging.SIZE_MINIMIZED);
            if (window.data.flags.is_minimized != minimized and minimized) {
                const event = common.event.createMinimizeEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            const restored = (wparam == win32_window_messaging.SIZE_RESTORED and (window.data.flags.is_minimized or window.data.flags.is_maximized));
            if (restored) {
                const event = common.event.createRestoreEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            window.data.flags.is_maximized = maximized;
            window.data.flags.is_minimized = minimized;

            const new_width = @intCast(i32, utils.loWord(@bitCast(usize, lparam)));
            const new_height = @intCast(i32, utils.hiWord(@bitCast(usize, lparam)));

            if (minimized or (window.data.client_area.size.width == new_width and
                window.data.client_area.size.height == new_height))
            {
                // No need to report duplicate events.
                // On minimize window the system resizes the window to a width = 0 and height = 0;
                // we only report meaningfull changes to the size.
                return 0;
            }

            window.data.client_area.size.width = new_width;
            window.data.client_area.size.height = new_height;
            window.win32.size_pos_update |= window_impl.WindowWin32Data.SIZE_UPDATE;

            if (!window.win32.frame_action) {
                // This message is sent multiple times when the user resizes the window
                // by dragging it's borders if we were to queue a resize event for each
                // the user will be bombarded by multiple useless messages so we will only queue the final one.
                const event = common.event.createResizeEvent(
                    window.data.id,
                    new_width,
                    new_height,
                );
                window.sendEvent(&event);
            }

            return 0;
        },

        win32_window_messaging.WM_MOVE => blk: {
            // Sent after a window has been moved.
            // the lparam holds the new client top left coords.

            // Our minimized flag is still not set so check using the winapi.
            if (win32_window_messaging.IsIconic(window.handle) != 0) {
                // When minimized don't change the top left position.
                break :blk;
            }

            const xpos = utils.getXLparam(@bitCast(usize, lparam));
            const ypos = utils.getYLparam(@bitCast(usize, lparam));

            if (window.data.client_area.top_left.x == xpos and
                window.data.client_area.top_left.y == ypos)
            {
                // No need to report duplicate events.
                break :blk;
            }

            window.data.client_area.top_left.x = xpos;
            window.data.client_area.top_left.y = ypos;

            window.win32.size_pos_update |= window_impl.WindowWin32Data.POSITON_UPDATE;
            if (!window.win32.frame_action) {
                const event = common.event.createMoveEvent(
                    window.data.id,
                    window.data.client_area.top_left.x,
                    window.data.client_area.top_left.y,
                    false,
                );
                window.sendEvent(&event);
            }
        },

        win32_window_messaging.WM_SETCURSOR => {
            // Sent to a window if the mouse causes the cursor
            // to move within a window and mouse input is not captured.
            if (utils.loWord(@bitCast(usize, lparam)) == win32_window_messaging.HTCLIENT) {
                // the mouse just moved into the client area
                // update the cursor image acording to the current mode;
                window_impl.updateCursorImage(&window.win32.cursor);
                return win32.TRUE;
            }
        },

        win32_window_messaging.WM_SETFOCUS => {
            // Sent to a window after it has gained the keyboard focus.
            const event = common.event.createFocusEvent(window.data.id, true);
            window.sendEvent(&event);
            window.data.flags.is_focused = true;
            if (!window.win32.frame_action) {
                // Don't disable or capture the cursor.
                // until the frame action is done.
                if (window.win32.cursor.mode.is_captured()) {
                    window_impl.captureCursor(window.handle);
                } else if (window.win32.cursor.mode.is_disabled()) {
                    window_impl.disableCursor(window.handle);
                }
            }
            return 0;
        },

        win32_window_messaging.WM_KILLFOCUS => {
            // Sent to a window immediately before it loses the keyboard focus.
            if (window.win32.cursor.mode.is_captured()) {
                window_impl.releaseCursor();
            } else if (window.win32.cursor.mode.is_disabled()) {
                window_impl.enableCursor(&window.win32.cursor);
            }

            const event = common.event.createFocusEvent(window.data.id, false);
            window.sendEvent(&event);
            window.data.flags.is_focused = false;
            return 0;
        },

        win32_window_messaging.WM_SYSCOMMAND => {
            // In win32_window_messaging.WM_SYSCOMMAND messages, the four low-order bits of the wParam
            // parameter are used internally by the system.
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
            // The win32_window_messaging.WM_UNICHAR message can be used by an application
            // to post input to other windows.
            // (Tests whether a target app can process win32_window_messaging.WM_UNICHAR messages
            // by sending the message with wParam set to UNICODE_NOCHAR.)
            if (wparam == win32_window_messaging.UNICODE_NOCHAR) {
                // If wParam is UNICODE_NOCHAR and the application support this message,
                return win32.TRUE;
            }

            // The win32_window_messaging.WM_UNICHAR message is similar to WM_CHAR,
            // but it uses Unicode Transformation Format (UTF)-32
            const event = common.event.createCharEvent(window.data.id, @truncate(u32, wparam), utils.getKeyModifiers());
            window.sendEvent(&event);
            return 0;
        },

        win32_window_messaging.WM_SYSCHAR, win32_window_messaging.WM_CHAR => {
            // Posted to the window with the keyboard focus when a win32_window_messaging.WM_SYSKEYDOWN | WM_KEYDOWN
            // message is translated by the TranslateMessage function.
            // WM_CHAR | WM_SYSCHAR message uses UTF-16
            // code units in its wParam if the Unicode version of the RegisterClass function was used
            message_handler.charEventHandler(window, wparam);
            if (msg != win32_window_messaging.WM_SYSCHAR) {
                return 0;
            }
        },
        //
        win32_window_messaging.WM_ENTERSIZEMOVE => {
            // Sent one time to a window after it enters the moving or sizing or menu modal loop,
            // The window enters the moving or sizing or the menu modal
            // loop when the user clicks the window's title bar or sizing border
            // or interact with the menu.
            window.win32.frame_action = true;
            window.win32.size_pos_update = window_impl.WindowWin32Data.NO_SIZE_POSITION_UPDATE;
        },

        win32_window_messaging.WM_EXITSIZEMOVE => {
            // now we should report the resize and postion change events.

            // the frame action is done treat the cursor
            // acording to the mode.
            if (window.win32.cursor.mode.is_captured()) {
                window_impl.captureCursor(window.handle);
            } else if (window.win32.cursor.mode.is_disabled()) {
                window_impl.disableCursor(window.handle);
            }

            if (window.win32.size_pos_update & window_impl.WindowWin32Data.SIZE_UPDATE != 0) {
                // At the end of a resize loop set the new client size and width.
                const event = common.event.createResizeEvent(
                    window.data.id,
                    window.data.client_area.size.width,
                    window.data.client_area.size.height,
                );
                window.sendEvent(&event);
            }
            if (window.win32.size_pos_update & window_impl.WindowWin32Data.POSITON_UPDATE != 0) {
                const event = common.event.createMoveEvent(
                    window.data.id,
                    window.data.client_area.top_left.x,
                    window.data.client_area.top_left.y,
                    false,
                );
                window.sendEvent(&event);
            }
            window.win32.frame_action = false;
        },

        win32_window_messaging.WM_DROPFILES => {
            message_handler.dropEventHandler(window, wparam);
            return 0;
        },
        else => {},
    }
    return win32_window_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
}
