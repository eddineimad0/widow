const std = @import("std");
const utils = @import("utils.zig");
const opt = @import("build-options");
const common = @import("common");
const msg_handler = @import("msg_handler.zig");
const wndw = @import("window.zig");
const display = @import("display.zig");
const win32_macros = @import("win32api/macros.zig");
const win32_input = @import("win32api/input.zig");
const win32_gfx = @import("win32api/graphics.zig");

const WidowContext = @import("platform.zig").WidowContext;
const win32 = std.os.windows;

/// The procedure function for the helper window
pub fn helperWindowProc(
    hwnd: win32.HWND,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(.winapi) isize {
    switch (msg) {
        win32_gfx.WM_DISPLAYCHANGE => {
            // Monitor the window_msg.WM_DISPLAYCHANGE notification
            // to detect when settings change or when a
            // display is added or removed.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: hidden recieved a DISPLAYCHANGE event\n",
                    .{},
                );
            }
            const ctx_ref = win32_gfx.GetPropW(
                hwnd,
                display.HELPER_DISPLAY_PROP,
            );
            if (ctx_ref) |ref| {
                const widow_ctx: *WidowContext = @ptrCast(@alignCast(ref));
                const display_mgr: *display.DisplayManager = &widow_ctx.display_mgr;
                if (!display_mgr.expected_video_change) {
                    display_mgr.rePollDisplays(widow_ctx.allocator) catch |err| {
                        // updateDisplays should only fail if we ran out of memory
                        // which is very unlikely on windows 64 bit systems
                        // but if it does happen the library should panic.
                        std.log.err(
                            "[Display Manager]: Failed to refresh Displays, error={}\n",
                            .{err},
                        );
                        @panic("[Widow]: Ran out of memory, can't update display data");
                    };
                }
            }
        },

        else => {},
    }
    return win32_gfx.DefWindowProcW(hwnd, msg, wparam, lparam);
}

/// The Window Procedure function.
pub fn mainWindowProc(
    hwnd: win32.HWND,
    msg: win32.DWORD,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM,
) callconv(.winapi) isize {
    const window_ref_prop = win32_gfx.GetPropW(hwnd, wndw.WINDOW_REF_PROP);
    if (window_ref_prop == null) {
        if (msg == win32_gfx.WM_NCCREATE) {
            // [Win32api Docs]
            // On Windows 10 1607 or above, PMv1 applications may also call
            // EnableNonClientDpiScaling during win32_gfx.WM_NCCREATE to request
            // that Windows correctly scale the window's non-client area.
            const ulparam: usize = @bitCast(lparam);
            const struct_ptr: *win32_gfx.CREATESTRUCTW = @ptrFromInt(ulparam);
            const create_lparam: ?*const wndw.CreationLparamTuple = @ptrCast(
                @alignCast(struct_ptr.*.lpCreateParams),
            );
            if (create_lparam) |param| {
                const drvr = param.*[1];
                const data = param.*[0];
                if (data.flags.is_dpi_aware and drvr.hints.is_win10b1607_or_above) {
                    _ = drvr.opt_func.EnableNonClientDpiScaling.?(hwnd);
                }
                struct_ptr.lpCreateParams = null;
            }
        }
        // Skip until the window pointer is registered.
        return win32_gfx.DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    var window: *wndw.Window = @ptrCast(@alignCast(window_ref_prop.?));
    switch (msg) {
        win32_gfx.WM_CLOSE => {
            // Received upon an attempt to close the window.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a CLOSE event\n", .{window.data.id});
            }
            const event = common.event.createCloseEvent(window.data.id);
            window.sendEvent(&event);
            return 0;
        },

        win32_gfx.WM_SHOWWINDOW => {
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

        win32_gfx.WM_MOUSEACTIVATE => {
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
            if (win32_macros.loWord(@bitCast(lparam)) != win32_gfx.HTCLIENT) {
                window.win32.frame_action = true;
            }
        },

        win32_gfx.WM_PAINT => {
            // No serious window application uses WM_PAINT for rendering
            // since most of the time you should decide when to render and not
            // the windows event loop. however for some event like the user resizing the window
            // you want the rendering code to respond to WM_PAINT and paint the new regions.
            // so we should notify the client that a repaint was requested but when the user
            // is doing such actions windows OS decides to hold our thread hostage
            // and keeps calling this function with WM_PAINT, WM_SIZE...etc until the user stop
            // so in order to respond to the user actions and repaint the window i can think of 3 options
            // 1. use a callback or build the library around callbacks like glfw did (too late for this)
            // 2. have the rendering code be on another thread and notify it using messages
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a PAINT event\n", .{window.data.id});
            }
            const event = common.event.createRePaintEvent(window.data.id);
            window.sendEvent(&event);
        },

        win32_gfx.WM_KEYUP,
        win32_gfx.WM_KEYDOWN,
        win32_gfx.WM_SYSKEYUP,
        win32_gfx.WM_SYSKEYDOWN,
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

        win32_gfx.WM_NCPAINT, win32_gfx.WM_NCACTIVATE => {
            // An application can intercept the win32_gfx.WM_NCPAINT message
            // and paint its own custom window frame
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a NCPAINT or NCACTIVATE event\n", .{window.data.id});
            }
            if (!window.data.flags.is_decorated or window.data.flags.is_fullscreen) {
                // no need to paint the frame for non decorated(Borderless)
                // or fullscreen windows;
                return 0;
            }
        },

        win32_gfx.WM_MOUSELEAVE => {
            // Posted to a window when the cursor leaves the client area
            // of the window specified in a prior call to TrackMouseEvent.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSELEAVE event\n", .{window.data.id});
            }
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseExitEvent(window.data.id);
            window.sendEvent(&event);
            // All tracking requested by TrackMouseEvent is canceled
            // when this message is generated.
            return 0;
        },

        win32_gfx.WM_LBUTTONUP,
        win32_gfx.WM_MBUTTONUP,
        win32_gfx.WM_RBUTTONUP,
        win32_gfx.WM_XBUTTONUP,
        => {
            // Received a mouse button is released
            // while the cursor is in the client area of a window.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a BUTTONUP event\n", .{window.data.id});
            }
            msg_handler.mouseUpMSGHandler(window, msg, wparam);
            if (msg == win32_gfx.WM_XBUTTONUP) {
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        win32_gfx.WM_LBUTTONDOWN,
        win32_gfx.WM_MBUTTONDOWN,
        win32_gfx.WM_RBUTTONDOWN,
        win32_gfx.WM_XBUTTONDOWN,
        => {
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a BUTTONDOWN event\n", .{window.data.id});
            }
            // Received a mouse button is pressed
            // while the cursor is in the client area of a window.
            msg_handler.mouseDownMSGHandler(window, msg, wparam);
            if (msg == win32_gfx.WM_XBUTTONDOWN) {
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        win32_gfx.WM_MOUSEMOVE => {
            // Posted to a window when the cursor moves.
            // If the mouse is not captured,
            // the message is posted to the window that contains the cursor.
            // Otherwise, the message is posted to the window that has captured the mouse.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSEMOVE event\n", .{window.data.id});
            }
            if (!window.data.flags.cursor_in_client) {
                var tme = win32_input.TRACKMOUSEEVENT{
                    .cbSize = @sizeOf(win32_input.TRACKMOUSEEVENT),
                    .dwFlags = win32_input.TME_LEAVE,
                    .hwndTrack = window.handle,
                    .dwHoverTime = 0,
                };
                // Calling TrackMouseEvent in order to receive mouse leave events.
                _ = win32_input.TrackMouseEvent(&tme);
                const event = common.event.createMouseEnterEvent(window.data.id);
                window.sendEvent(&event);
                window.data.flags.cursor_in_client = true;
            }
            const new_pos = utils.getMousePosition(lparam);

            const dx = new_pos.x - window.win32.cursor.pos.x;
            const dy = new_pos.y - window.win32.cursor.pos.y;
            if (dx == 0 and dy == 0) {
                return 0;
            }

            if (window.win32.cursor.mode == .Hidden) {
                if (window.data.flags.has_raw_mouse) {
                    return 0;
                }

                window.win32.cursor.accum_pos.x +%= dx;
                window.win32.cursor.accum_pos.y +%= dy;
            } else {
                window.win32.cursor.accum_pos.x = new_pos.x;
                window.win32.cursor.accum_pos.y = new_pos.y;
            }

            const event = common.event.createMoveEvent(
                window.data.id,
                window.win32.cursor.accum_pos.x,
                window.win32.cursor.accum_pos.y,
                true,
            );
            window.sendEvent(&event);

            window.win32.cursor.pos.x = new_pos.x;
            window.win32.cursor.pos.y = new_pos.y;

            return 0;
        },

        win32_gfx.WM_MOUSEWHEEL => {
            // Sent to the active window when the mouse's vertical scroll wheel
            // is tilted or rotated. A positive value indicates that
            // the wheel was rotated forward, away from the user.
            // a negative value indicates that the wheel was rotated
            // backward, toward the user.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSEWHEEL event\n", .{window.data.id});
            }
            const scroll: f64 = @floatFromInt(win32_macros.getYLparam(wparam));
            const wheel_delta = scroll / @as(f64, win32_gfx.WHEEL_DELTA);
            msg_handler.mouseWheelMSGHandler(
                window,
                0.0,
                wheel_delta,
            );
            return 0;
        },

        win32_gfx.WM_MOUSEHWHEEL => {
            // Sent to the active window when the mouse's horizontal scroll
            // wheel is tilted or rotated. A positive value indicates that
            // the wheel was rotated left, a negative value indicates
            // that the wheel was rotated right.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOUSEHWHEEL event\n", .{window.data.id});
            }
            const scroll: f64 = @floatFromInt(win32_macros.getYLparam(wparam));
            const wheel_delta = -(scroll) / @as(f64, win32_gfx.WHEEL_DELTA);
            msg_handler.mouseWheelMSGHandler(
                window,
                wheel_delta,
                0.0,
            );
            return 0;
        },

        win32_gfx.WM_ERASEBKGND => {
            // The message is sent to prepare an invalidated portion
            // of a window for painting. An application should
            // return nonzero in response to win32_gfx.WM_ERASEBKGND
            // if it processes the message and erases the background.
            // returning true here prevents flickering and
            // allow us to do our own drawing.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a ERASEBKGND event\n", .{window.data.id});
            }
            return win32.TRUE;
        },

        win32_gfx.WM_GETDPISCALEDSIZE => {
            // [MSDN]
            // This message is received before a win32_gfx.WM_DPICHANGED
            // for PMv2 awareness, and allows the window to compute its
            // desired size for the pending DPI change.
            // [SDL]
            // Experimentation shows it's only sent during interactive
            // dragging, not in response to SetWindowPos.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a GETDPISCALEDSIZE event\n", .{window.data.id});
            }
            const drvr = window.ctx.driver;
            // there is no need to process this message for a dpi aware window
            // for a non dpi aware window processing this messsage is necessary
            // to adjust it's decorations(titlebar,edges...).
            if (!window.data.flags.is_dpi_aware and drvr.hints.is_win10b1607_or_above) {
                msg_handler.dpiScaledSizeHandler(window, wparam, lparam);
                return win32.TRUE;
            }
            return win32.FALSE;
        },

        win32_gfx.WM_DPICHANGED => {
            // Sent when the effective dots per inch (dpi) for a window has changed.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a DPICHANGED event\n", .{window.data.id});
            }
            const suggested_rect: *win32.RECT = @ptrFromInt(@as(usize, @bitCast(lparam)));
            const new_dpi_x = win32_macros.loWord(wparam);
            const new_dpi_y = win32_macros.hiWord(wparam);
            const scale = @as(f64, @floatFromInt(new_dpi_x)) / win32_gfx.USER_DEFAULT_SCREEN_DPI_F;
            const flags = win32_gfx.SET_WINDOW_POS_FLAGS{
                .NOACTIVATE = 1,
                .NOZORDER = 1,
                .NOOWNERZORDER = 1,
            };
            const top = if (window.data.flags.is_topmost)
                win32_gfx.HWND_TOPMOST
            else
                win32_gfx.HWND_NOTOPMOST;

            _ = win32_gfx.SetWindowPos(
                window.handle,
                top,
                suggested_rect.left,
                suggested_rect.top,
                suggested_rect.right - suggested_rect.left,
                suggested_rect.bottom - suggested_rect.top,
                flags,
            );
            const event = common.event.createDpiEvent(
                window.data.id,
                @floatFromInt(new_dpi_x),
                @floatFromInt(new_dpi_y),
                scale,
            );
            window.sendEvent(&event);
            return 0;
        },

        win32_gfx.WM_GETMINMAXINFO => {
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

        win32_gfx.WM_SIZING => {
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

        win32_gfx.WM_SIZE => {
            // Sent to a window after its size has changed.
            // usually due to maximizing, minimizing, resizing...etc.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SIZE event\n", .{window.data.id});
            }
            const maximized = (wparam == win32_gfx.SIZE_MAXIMIZED);
            if (window.data.flags.is_maximized != maximized and maximized) {
                const event = common.event.createMaximizeEvent(
                    window.data.id,
                );
                window.sendEvent(&event);
            }

            const minimized = (wparam == win32_gfx.SIZE_MINIMIZED);
            if (window.data.flags.is_minimized != minimized and minimized) {
                const event = common.event.createMinimizeEvent(
                    window.data.id,
                );
                window.sendEvent(&event);

                if (window.data.flags.is_fullscreen) {
                    _ = window.setFullscreen(false);
                    // undo the flag change, for when we restore the window.
                    window.data.flags.is_fullscreen = true;
                }
            }

            const restored = (wparam == win32_gfx.SIZE_RESTORED and
                (window.data.flags.is_minimized or window.data.flags.is_maximized));
            if (restored) {
                const event = common.event.createRestoreEvent(
                    window.data.id,
                );
                window.sendEvent(&event);

                if (window.data.flags.is_fullscreen) {
                    // clear the flag so that we can call setFullscreen.
                    window.data.flags.is_fullscreen = false;
                    // if we fail then just leave the window not in fullscreen
                    // maybe post a window error message
                    _ = window.setFullscreen(true);
                }
            }

            window.data.flags.is_maximized = maximized;
            window.data.flags.is_minimized = minimized;

            const new_width: i32 = @intCast(win32_macros.loWord(@bitCast(lparam)));
            const new_height: i32 = @intCast(win32_macros.hiWord(@bitCast(lparam)));

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

            // For windows that allows resizing by dragging it's edges,
            // this message is received multiple times during the resize process
            var sz = common.window_data.WindowSize{
                .logical_width = 0,
                .logical_height = 0,
                .scale = 0,
                .physical_width = 0,
                .physical_height = 0,
            };
            window.getClientSize(&sz);
            const event = common.event.createResizeEvent(
                window.data.id,
                &sz,
            );
            window.sendEvent(&event);

            return 0;
        },

        win32_gfx.WM_MOVE => blk: {
            // Sent after a window has been moved.
            // the lparam holds the new client top left coords.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a MOVE event\n", .{window.data.id});
            }
            // Our minimized flag is still not set so check using the winapi.
            if (win32_gfx.IsIconic(window.handle) != 0) {
                // if the window was minimized don't update the top left position.
                break :blk;
            }

            const xpos = win32_macros.getXLparam(@bitCast(lparam));
            const ypos = win32_macros.getYLparam(@bitCast(lparam));

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

        win32_gfx.WM_SETCURSOR => {
            // Sent if the mouse causes the cursor
            // to move within a window and mouse input is not captured.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SETCURSOR event\n", .{window.data.id});
            }
            if (win32_macros.loWord(@bitCast(lparam)) == win32_gfx.HTCLIENT) {
                // the mouse just moved into the client area
                // update the cursor image acording to the current mode;
                wndw.applyCursorHints(&window.win32.cursor, window.handle);
                return win32.TRUE;
            }
        },

        win32_gfx.WM_SETFOCUS => {
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
                if (window.data.flags.has_raw_mouse and window.win32.cursor.mode == .Hidden) {
                    _ = wndw.enableRawMouseMotion(window.handle);
                }
            }
            return 0;
        },

        win32_gfx.WM_KILLFOCUS => {
            // Sent to a window immediately before it loses the keyboard focus.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a KILLFOCUS event\n", .{window.data.id});
            }

            wndw.restoreCursor(&window.win32.cursor);
            if (window.data.flags.has_raw_mouse and window.win32.cursor.mode == .Hidden) {
                _ = wndw.disableRawMouseMotion();
            }

            const event = common.event.createFocusEvent(window.data.id, false);
            window.sendEvent(&event);
            window.data.flags.is_focused = false;
            return 0;
        },

        win32_gfx.WM_SYSCOMMAND => {
            // In win32_gfx.WM_SYSCOMMAND messages, the four low-order bits of the wParam
            // parameter are used internally by the system.
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SYSCOMMAND event\n", .{window.data.id});
            }
            switch (wparam & 0xFFF0) {
                win32_gfx.SC_SCREENSAVE, win32_gfx.SC_MONITORPOWER => {
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

        win32_gfx.WM_UNICHAR => {
            // The win32_gfx.WM_UNICHAR message can be used by an application
            // to post input to other windows.
            // (Tests whether a target app can process win32_gfx.WM_UNICHAR
            // messages by sending the message with wParam
            // set to UNICODE_NOCHAR.)
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a UNICHAR event\n", .{window.data.id});
            }
            if (wparam == win32_gfx.UNICODE_NOCHAR) {
                // If wParam is UNICODE_NOCHAR and the application support this message,
                return win32.TRUE;
            }

            // The win32_gfx.WM_UNICHAR message is similar to WM_CHAR,
            // but it uses Unicode Transformation Format (UTF)-32
            const event = common.event.createCharEvent(
                window.data.id,
                @truncate(wparam),
                utils.getKeyModifiers(),
            );
            window.sendEvent(&event);
            return 0;
        },

        win32_gfx.WM_SYSCHAR, win32_gfx.WM_CHAR => {
            // Posted to the window with the keyboard focus
            // when a win32_gfx.WM_SYSKEYDOWN | WM_KEYDOWN
            // message is translated by the TranslateMessage function.
            // WM_CHAR | WM_SYSCHAR message uses UTF-16
            // code units in its wParam if the Unicode version of the
            // RegisterClass function was used
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a SYSCHAR/CHAR event\n", .{window.data.id});
            }
            msg_handler.charEventHandler(window, wparam);
            if (msg != win32_gfx.WM_SYSCHAR) {
                return 0;
            }
        },

        win32_gfx.WM_ENTERSIZEMOVE => {
            // Sent one time to a window after it enters
            // the moving or sizing loop,
            // The window enters the moving or sizing
            // loop when the user clicks the window's title bar or sizing border
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a ENTERSIZEMOVE event\n", .{window.data.id});
            }
            window.win32.frame_action = true;
        },

        win32_gfx.WM_EXITSIZEMOVE => {
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

        win32_gfx.WM_DROPFILES => {
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a DROPFILES event\n", .{window.data.id});
            }
            msg_handler.dropEventHandler(window, wparam);
            return 0;
        },

        win32_gfx.WM_INPUT => {
            if (window.data.flags.has_raw_mouse != true or window.win32.cursor.mode != .Hidden) {
                return 0;
            }
            if (opt.LOG_PLATFORM_EVENTS) {
                std.log.info("window: {} recieved a WM_INPUT event\n", .{window.data.id});
            }

            const ulparam: usize = @bitCast(lparam);
            const raw_input: win32_input.HRAWINPUT = @ptrFromInt(ulparam);
            var inpt: win32_input.RAWINPUT = undefined;
            var raw_data_size: c_uint = @sizeOf(win32_input.RAWINPUT);

            const ret = win32_input.GetRawInputData(
                raw_input,
                win32_input.RID_INPUT,
                &inpt,
                &raw_data_size,
                @sizeOf(win32_input.RAWINPUTHEADER),
            );

            if (ret != raw_data_size) {
                // error.
                return 0;
            }

            var dx: i32, var dy: i32 = .{ 0, 0 };
            if (inpt.data.mouse.usFlags & 0x01 != 0) {
                var x: i32, var y: i32 = .{ 0, 0 };
                var width: i32, var height: i32 = .{ 0, 0 };

                if (inpt.data.mouse.usFlags & 0x02 != 0) {
                    x += win32_gfx.GetSystemMetrics(win32_gfx.SM_XVIRTUALSCREEN);
                    y += win32_gfx.GetSystemMetrics(win32_gfx.SM_XVIRTUALSCREEN);
                    width = win32_gfx.GetSystemMetrics(win32_gfx.SM_CXVIRTUALSCREEN);
                    height = win32_gfx.GetSystemMetrics(win32_gfx.SM_CYVIRTUALSCREEN);
                } else {
                    width = win32_gfx.GetSystemMetrics(win32_gfx.SM_CXSCREEN);
                    height = win32_gfx.GetSystemMetrics(win32_gfx.SM_CYSCREEN);
                }

                x += @intFromFloat(@as(f64, @floatFromInt(inpt.data.mouse.lLastX)) / @as(f64, 65535) *
                    @as(f64, @floatFromInt(width)));
                y += @intFromFloat(@as(f64, @floatFromInt(inpt.data.mouse.lLastY)) / @as(f64, 65535) *
                    @as(f64, @floatFromInt(height)));

                var cur_pos: win32.POINT = .{ .x = x, .y = y };
                _ = win32_gfx.ScreenToClient(window.handle, &cur_pos);

                dx = cur_pos.x - window.win32.cursor.pos.x;
                dy = cur_pos.y - window.win32.cursor.pos.y;
            } else {
                dx = inpt.data.mouse.lLastX;
                dy = inpt.data.mouse.lLastY;
            }

            window.win32.cursor.accum_pos.x +%= dx;
            window.win32.cursor.accum_pos.y +%= dy;

            const event = common.event.createMoveEvent(
                window.data.id,
                window.win32.cursor.accum_pos.x,
                window.win32.cursor.accum_pos.y,
                true,
            );
            window.sendEvent(&event);

            window.win32.cursor.pos.x += dx;
            window.win32.cursor.pos.y += dy;
            return 0;
        },

        else => {},
    }
    return win32_gfx.DefWindowProcW(hwnd, msg, wparam, lparam);
}
