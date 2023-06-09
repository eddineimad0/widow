const std = @import("std");
const windows = @import("std").os.windows;
const winapi = @import("win32");
const utils = @import("./utils.zig");
const common = @import("common");
const win32_window_messaging = winapi.ui.windows_and_messaging;
const win32_keyboard_mouse = winapi.ui.input.keyboard_and_mouse;
const win32_shell = winapi.ui.shell;
const Win32Context = @import("./internals.zig").Win32Context;
const window_impl = @import("./window_impl.zig");

const winabi = windows.WINAPI;
const HRESULT = windows.HRESULT;
const NTSTATUS = winapi.foundation.NTSTATUS;
const BOOL = winapi.foundation.BOOL;
const HWND = winapi.foundation.HWND;
const RECT = winapi.foundation.RECT;
const LPARAM = winapi.foundation.LPARAM;
const WPARAM = winapi.foundation.WPARAM;
const OSVERSIONINFOEXW = winapi.system.system_information.OSVERSIONINFOEXW;
const HMONITOR = winapi.graphics.gdi.HMONITOR;
const PROCESS_DPI_AWARENESS = winapi.ui.hi_dpi.PROCESS_DPI_AWARENESS;
const DPI_AWARENESS_CONTEXT = winapi.ui.hi_dpi.DPI_AWARENESS_CONTEXT;
const MONITOR_DPI_TYPE = winapi.ui.hi_dpi.MONITOR_DPI_TYPE;
const SC_SCREENSAVE = winapi.graphics.gdi.SC_SCREENSAVE;
const TRUE = 1;
const FALSE = 0;
const WM_UNICHAR = @as(u32, 0x0109);

pub const proc_SetProcessDPIAware = *const fn () callconv(winabi) BOOL;

pub const proc_RtlVerifyVersionInfo = *const fn (*OSVERSIONINFOEXW, u32, u64) callconv(winabi) NTSTATUS;

pub const proc_SetProcessDpiAwareness = *const fn (PROCESS_DPI_AWARENESS) callconv(winabi) HRESULT;

pub const proc_SetProcessDpiAwarenessContext = *const fn (DPI_AWARENESS_CONTEXT) callconv(winabi) HRESULT;

pub const proc_EnableNonClientDpiScaling = *const fn (HWND) callconv(winabi) BOOL;

pub const proc_GetDpiForWindow = *const fn (HWND) callconv(winabi) u32;

pub const proc_GetDpiForMonitor = *const fn (
    HMONITOR,
    MONITOR_DPI_TYPE,
    *u32,
    *u32,
) callconv(winabi) HRESULT;

pub const proc_AdjustWindowRectExForDpi = *const fn (
    *RECT,
    u32,
    i32,
    u32,
    u32,
) callconv(winabi) BOOL;

/// The procedure function for the helper window
pub fn helperWindowProc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) callconv(winabi) isize {
    const user_data = win32_window_messaging.GetWindowLongPtrW(hwnd, win32_window_messaging.GWLP_USERDATA);
    if (user_data != 0) {
        var devices = @intToPtr(*Win32Context, @intCast(usize, user_data));
        switch (msg) {
            win32_window_messaging.WM_DISPLAYCHANGE => {
                // Monitor the win32_window_messaging.WM_DISPLAYCHANGE notification
                // to detect when settings change or when a
                // display is added or removed.
                if (!devices.expected_video_change) {
                    devices.updateMonitors() catch {
                        std.debug.print("Failed to update monitors\n", .{});
                    };
                }
            },
            win32_window_messaging.WM_DRAWCLIPBOARD => {
                // Sent When The clipboard content gets updated.
                devices.clipboard_change = true;
                std.debug.print("Clipboard got drawn\n", .{});
                if (devices.next_clipboard_viewer) |viewer| {
                    std.debug.print("Forwarding msg to next viewer\n", .{});
                    _ = win32_window_messaging.SendMessage(viewer, msg, wparam, lparam);
                }
            },
            win32_window_messaging.WM_CHANGECBCHAIN => {
                // Sent When one of the clipboard viewers is getting removed.
                if (devices.next_clipboard_viewer) |viewer| {
                    if (wparam == @ptrToInt(viewer)) {
                        devices.next_clipboard_viewer = @intToPtr(?HWND, @bitCast(usize, lparam));
                    } else {
                        _ = win32_window_messaging.SendMessage(devices.next_clipboard_viewer, msg, wparam, lparam);
                    }
                }
                // last in the chain.
                return 0;
            },
            // win32_window_messaging.WM_DEVICECHANGE => {
            //     // I/O hardware
            // }
            else => {},
        }
    }
    return win32_window_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
}

const message_handler = @import("./message_handler.zig");
/// The Window Procedure function.
pub fn windowProc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) callconv(winabi) isize {

    // Get a mutable refrence to the corresponding WindowImpl Structure.
    const window_data = win32_window_messaging.GetWindowLongPtrW(hwnd, win32_window_messaging.GWLP_USERDATA);
    var window = @intToPtr(?*window_impl.WindowImpl, @bitCast(usize, window_data)) orelse {
        if (msg == win32_window_messaging.WM_NCCREATE) {
            // [Win32api Docs]
            // On Windows 10 1607 or above, PMv1 applications may also call
            // EnableNonClientDpiScaling during win32_window_messaging.WM_NCCREATE to request
            // that Windows correctly scale the window's non-client area.
            const creation_struct_ptr: *win32_window_messaging.CREATESTRUCTW = @intToPtr(*win32_window_messaging.CREATESTRUCTW, @bitCast(usize, lparam));
            var proc = @ptrCast(?proc_EnableNonClientDpiScaling, creation_struct_ptr.*.lpCreateParams);
            if (proc) |EnableNonClientDpiScaling| {
                _ = EnableNonClientDpiScaling(hwnd);
            }
            // remove the internals pointer;
            creation_struct_ptr.*.lpCreateParams = null;
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

        win32_window_messaging.WM_MOUSEACTIVATE => {
            // Sent when the cursor is in an inactive window and
            // the user presses a mouse button. The parent window receives
            // this message only if the child window passes it to the DefWindowProc function.
            if (utils.hiWord(@bitCast(usize, lparam)) == win32_window_messaging.WM_LBUTTONDOWN and utils.loWord(@bitCast(usize, lparam)) != win32_window_messaging.HTCLIENT) {
                // use this flag to postpone disabling cursor until it enters,
                // the client area.
                window.win32.frame_action = true;
            }
        },

        win32_window_messaging.WM_CAPTURECHANGED => {
            // Sent to the window that is losing the mouse capture.
            // A window receives this message through its WindowProc function.
            if (window.win32.frame_action and lparam == 0) {
                // the frame action is done treat the cursor
                // acording to the mode.
                if (window.win32.cursor.mode.is_captured()) {
                    window_impl.captureCursor(window.handle);
                } else if (window.win32.cursor.mode.is_disabled()) {
                    window_impl.disableCursor(window.handle, &window.win32.cursor);
                }
                window.win32.frame_action = false;
            }
        },

        win32_window_messaging.WM_NCPAINT => {
            // An application can intercept the win32_window_messaging.WM_NCPAINT message
            // and paint its own custom window frame
            if (!window.data.flags.is_decorated) {
                // no need to paint the frame for non decorated windows;
                return 0;
            }
        },

        win32_window_messaging.WM_MOUSELEAVE => {
            // Posted to a window when the cursor leaves the client area
            // of the window specified in a prior call to TrackMouseEvent.
            window.data.flags.cursor_in_client = false;
            const event = common.event.createMouseLeftEvent();
            window.queueEvent(&event);
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
                return TRUE;
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
                return TRUE;
            }
            return 0;
        },

        win32_window_messaging.WM_MOUSEMOVE => {
            // Posted to a window when the cursor moves.
            // If the mouse is not captured,
            // the message is posted to the window that contains the cursor.
            // Otherwise, the message is posted to the window that has captured the mouse.
            if (!window.data.flags.cursor_in_client) {
                // Calling TrackMouseEvent in order to receive mouse leave events.
                var tme = win32_keyboard_mouse.TRACKMOUSEEVENT{
                    .cbSize = @sizeOf(win32_keyboard_mouse.TRACKMOUSEEVENT),
                    .dwFlags = win32_keyboard_mouse.TME_LEAVE,
                    .hwndTrack = window.handle,
                    .dwHoverTime = 0,
                };
                _ = win32_keyboard_mouse.TrackMouseEvent(&tme);
                const event = common.event.createMouseEnterEvent();
                window.queueEvent(&event);
                window.data.flags.cursor_in_client = true;
            }
            const new_pos = utils.getMousePosition(lparam);
            // if (window.data.flags.accepts_raw_input and window.data.cursor.is_disabled()) {
            //     // send raw delta.
            //     new_pos.x -= window.data.platform_data.last_raw_pos.x;
            //     new_pos.y -= window.data.platform_data.last_raw_pos.y;
            // }
            const event = common.event.createMouseMoveEvent(new_pos, false);
            window.queueEvent(&event);
            // window.data.platform_data.last_raw_pos = new_pos;
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
            return TRUE;
        },

        win32_window_messaging.WM_GETDPISCALEDSIZE => {
            // This message before a win32_window_messaging.WM_DPICHANGED for PMv2 awareness, and allows
            // the window to compute its desired size for the pending DPI change.
            // this is only useful in scenarios where the window wants to scale non-linearly.
            if (message_handler.dpiScaledSizeHandler(window, wparam, lparam)) {
                return TRUE;
            }
            return FALSE;
        },

        win32_window_messaging.WM_DPICHANGED => {
            // Sent when the effective dots per inch (dpi) for a window has changed.
            if (window.data.fullscreen_mode == null and window.internals.win32.flags.is_win10b1703_or_above) {
                const rect_ref: *RECT = @intToPtr(*RECT, @bitCast(usize, lparam));
                const flags = @enumToInt(win32_window_messaging.SWP_NOACTIVATE) |
                    @enumToInt(win32_window_messaging.SWP_NOZORDER) |
                    @enumToInt(win32_window_messaging.SWP_NOREPOSITION);
                const top = if (window.data.flags.is_topmost) win32_window_messaging.HWND_TOPMOST else win32_window_messaging.HWND_NOTOPMOST;
                _ = win32_window_messaging.SetWindowPos(
                    window.handle,
                    top,
                    rect_ref.left,
                    rect_ref.top,
                    rect_ref.right - rect_ref.left,
                    rect_ref.bottom - rect_ref.top,
                    @intToEnum(win32_window_messaging.SET_WINDOW_POS_FLAGS, flags),
                );
            }
            const new_dpi = utils.loWord(wparam);
            const scale = @intToFloat(f64, new_dpi) / @intToFloat(f64, win32_window_messaging.USER_DEFAULT_SCREEN_DPI);
            const event = common.event.createDPIEvent(new_dpi, scale);
            window.queueEvent(&event);
        },

        win32_window_messaging.WM_GETMINMAXINFO => {
            // Sent to a window when the size or position of the window is about to change.
            // An application can use this message to override the window's default
            // maximized size and position, or its default minimum or maximum tracking size.
            if (window.data.fullscreen_mode == null) {
                message_handler.minMaxInfoHandler(window, lparam);
            }
            return 0;
        },

        win32_window_messaging.WM_SIZING => {
            // Sent to a window that the user is resizing.
            if (window.data.aspect_ratio != null) {
                const drag_rect_ptr = @intToPtr(*RECT, @bitCast(usize, lparam));
                window.applyAspectRatio(drag_rect_ptr, @truncate(u32, wparam));
            }
            return TRUE;
        },

        win32_window_messaging.WM_SIZE => {
            // Sent to a window after its size has changed.
            const maximized = (wparam == win32_window_messaging.SIZE_MAXIMIZED or (window.data.flags.is_maximized and wparam != win32_window_messaging.SIZE_RESTORED));
            if (window.data.flags.is_maximized != maximized and maximized) {
                const event = common.event.createMaximizeEvent();
                window.queueEvent(&event);
            }

            const minimized = (wparam == win32_window_messaging.SIZE_MINIMIZED);
            if (window.data.flags.is_minimized != minimized and minimized) {
                const event = common.event.createMinimizeEvent();
                window.queueEvent(&event);
            }

            const new_width = utils.loWord(@bitCast(usize, lparam));
            const new_height = utils.hiWord(@bitCast(usize, lparam));

            const event = common.event.createResizeEvent(@intCast(i32, new_width), @intCast(i32, new_height));
            window.queueEvent(&event);

            if (window.data.fullscreen_mode != null and window.data.flags.is_minimized != minimized) {
                if (minimized) {
                    window.releaseMonitor() catch {
                        std.debug.print("Failed To release monitor.", .{});
                        window.requestRestore();
                    };
                }
                window.acquireMonitor() catch {
                    std.debug.print("Failed To Switch video mode", .{});
                    window.requestRestore();
                };
            }
            window.data.flags.is_maximized = maximized;
            window.data.flags.is_minimized = minimized;
            return 0;
        },

        win32_window_messaging.WM_WINDOWPOSCHANGED => {
            const window_pos = @intToPtr(*const win32_window_messaging.WINDOWPOS, @bitCast(usize, lparam));
            const event = common.event.createMoveEvent(window_pos.x, window_pos.y);
            window.queueEvent(&event);
            window.data.position = common.geometry.WidowPoint2D{ .x = window_pos.x, .y = window_pos.y };
            // Let DefineWindowProc handle the rest.
        },

        win32_window_messaging.WM_SETCURSOR => {
            // Sent to a window if the mouse causes the cursor
            // to move within a window and mouse input is not captured.
            if (utils.loWord(@bitCast(usize, lparam)) == win32_window_messaging.HTCLIENT) {
                // the mouse just moved into the client area
                // update the cursor image acording to the current mode;
                window_impl.updateCursor(&window.win32.cursor);
                return TRUE;
            }
        },

        win32_window_messaging.WM_SETFOCUS => {
            // Sent to a window after it has gained the keyboard focus.
            const event = common.event.createFocusEvent(true);
            window.queueEvent(&event);
            if (!window.win32.frame_action) {
                // Don't disable or capture the cursor.
                // until the frame action is done.
                if (window.win32.cursor.mode.is_captured()) {
                    window_impl.captureCursor(window.handle);
                } else if (window.win32.cursor.mode.is_disabled()) {
                    window_impl.disableCursor(window.handle, &window.win32.cursor);
                }
            }
            window.data.flags.is_focused = true;
            return 0;
        },

        win32_window_messaging.WM_KILLFOCUS => {
            // Sent to a window immediately before it loses the keyboard focus.
            if (window.win32.cursor.mode.is_captured()) {
                window_impl.releaseCursor();
                window.win32.cursor.mode = common.cursor.CursorMode.Normal;
            } else if (window.win32.cursor.mode.is_disabled()) {
                window_impl.enableCursor(&window.win32.cursor);
            }

            const event = common.event.createFocusEvent(false);
            window.queueEvent(&event);
            window.data.flags.is_focused = false;
            return 0;
        },

        win32_window_messaging.WM_SYSCOMMAND => {
            // In win32_window_messaging.WM_SYSCOMMAND messages, the four low-order bits of the wParam
            // parameter are used internally by the system.
            switch (wparam & 0xFFF0) {
                SC_SCREENSAVE, win32_window_messaging.SC_MONITORPOWER => {
                    if (window.data.fullscreen_mode != null) {
                        // No screen saver for fullscreen mode
                        return 0;
                    }
                },

                win32_window_messaging.SC_KEYMENU => {
                    // User pressed alt to access the window's keymenu
                    if (!window.win32.keymenu) {
                        return 0;
                    }
                },

                else => {
                    // Let DefWindowProcW handle it;
                },
            }
        },

        WM_UNICHAR => {
            // The win32_window_messaging.WM_UNICHAR message can be used by an application
            // to post input to other windows.
            // (Test whether a target app can process win32_window_messaging.WM_UNICHAR messages
            // by sending the message with wParam set to UNICODE_NOCHAR.)
            if (wparam == win32_window_messaging.UNICODE_NOCHAR) {
                // If wParam is UNICODE_NOCHAR and the application support this message,
                return TRUE;
            }
            // The win32_window_messaging.WM_UNICHAR message is similar to WM_CHAR,
            // but it uses Unicode Transformation Format (UTF)-32
            const event = common.event.createCharEvent(@truncate(u32, wparam), utils.getKeyModifiers());
            window.queueEvent(&event);
            return 0;
        },

        win32_window_messaging.WM_SYSCHAR, win32_window_messaging.WM_CHAR => {
            // Posted to the window with the keyboard focus when a win32_window_messaging.WM_SYSKEYDOWN | WM_KEYDOWN
            // message is translated by the TranslateMessage function.
            // WM_CHAR | WM_SYSCHAR message uses UTF-16
            // code units in its wParam if the Unicode version of the RegisterClass function was used
            message_handler.charEventHandler(window, wparam);
            if (msg != win32_window_messaging.WM_SYSCHAR or !window.win32.keymenu) {
                return 0;
            }
        },
        //
        win32_window_messaging.WM_ENTERSIZEMOVE, win32_window_messaging.WM_ENTERMENULOOP => {
            // Sent one time to a window after it enters the moving or sizing or menu modal loop,
            // The window enters the moving or sizing or the menu modal
            // loop when the user clicks the window's title bar or sizing border
            // or interact with the menu.
            if (!window.win32.frame_action) {
                // Enable the cursor while resizing or using the menu.
                if (window.win32.cursor.mode.is_disabled()) {
                    window_impl.enableCursor(&window.win32.cursor);
                } else if (window.win32.cursor.mode.is_captured()) {
                    window_impl.releaseCursor();
                }
            }
        },

        win32_window_messaging.WM_EXITSIZEMOVE | win32_window_messaging.WM_EXITMENULOOP => {
            // Sent on exit of the moving or sizing or menu modal loop,
            if (!window.win32.frame_action) {
                // When done return the cursor to it's previous state.
                if (window.win32.cursor.mode.is_disabled()) {
                    window_impl.disableCursor(window.handle, &window.win32.cursor);
                } else if (window.win32.cursor.mode.is_captured()) {
                    window_impl.captureCursor(window.handle);
                }
            }
        },

        win32_window_messaging.WM_DROPFILES => {
            // can we use a different allocator for better performance?
            // free old files
            const allocator = window.win32.dropped_files.allocator;
            for (window.win32.dropped_files.items) |file| {
                allocator.free(file);
            }

            var wide_slice: []u16 = undefined;
            wide_slice.len = 0;
            window.win32.dropped_files.clearRetainingCapacity();
            const drop_handle = @intToPtr(win32_shell.HDROP, wparam);
            const count = win32_shell.DragQueryFileW(drop_handle, 0xFFFFFFFF, null, 0);
            if (count != 0) err_exit: {
                if (window.win32.dropped_files.capacity < count) {
                    window.win32.dropped_files.ensureTotalCapacity(count) catch {
                        std.log.err("Failed to retrieve Dropped Files.\n", .{});
                        break :err_exit;
                    };
                }
                for (0..count) |index| {
                    const buffer_len = win32_shell.DragQueryFileW(drop_handle, @truncate(u32, index), null, 0);
                    if (buffer_len != 0) {
                        // the returned length doesn't account for the null terminator,
                        // however DragQueryFile will always write the null terminator even
                        // at the cost of no copying the entire data. so it's necessary to add 1
                        const buffer_lenz = buffer_len + 1;
                        if (wide_slice.len == 0) {
                            wide_slice = allocator.alloc(u16, buffer_lenz) catch {
                                std.log.err("Failed to retrieve Dropped Files.\n", .{});
                                break :err_exit;
                            };
                        } else if (wide_slice.len < buffer_lenz) {
                            wide_slice = allocator.realloc(wide_slice, buffer_lenz) catch {
                                std.log.err("Failed to retrieve Dropped Files.\n", .{});
                                continue;
                            };
                        }
                        _ = win32_shell.DragQueryFileW(drop_handle, @truncate(u32, index), @ptrCast([*:0]u16, wide_slice.ptr), buffer_lenz);
                        const file_path = utils.wideToUtf8(allocator, wide_slice.ptr[0..buffer_len]) catch {
                            std.log.err("Failed to retrieve Dropped Files.\n", .{});
                            continue;
                        };
                        window.win32.dropped_files.append(file_path) catch {
                            std.log.err("Failed to retrieve Dropped Files.\n", .{});
                            allocator.free(file_path);
                            continue;
                        };
                    }
                }
                // std.debug.print("dropped_files {?}\n", .{window.win32.dropped_files});
                const event = common.event.createDropFileEvent(window.win32.dropped_files);
                window.queueEvent(&event);
                allocator.free(wide_slice);
            }
            win32_shell.DragFinish(drop_handle);
            return 0;
        },
        //     win32_window_messaging.WM_INPUT => {
        //         if window.data.flags.accepts_raw_input && window.data.cursor.is_disabled() {
        //             const RAW_HEADER_SIZE: u32 = std::mem::size_of::<RAWINPUTHEADER>() as u32;
        //             let mut data_size: u32 = 0;
        //             GetRawInputData(
        //                 lparam as HRAWINPUT,
        //                 RID_INPUT,
        //                 std::ptr::null_mut(),
        //                 &mut data_size,
        //                 RAW_HEADER_SIZE,
        //             );
        //             let mut input_buffer: Vec<u8> = vec![0; data_size as usize];
        //             if GetRawInputData(
        //                 lparam as HRAWINPUT,
        //                 RID_INPUT,
        //                 input_buffer.as_mut_ptr() as *mut _,
        //                 &mut data_size,
        //                 RAW_HEADER_SIZE,
        //             ) != data_size
        //             {
        //                 debug_println!("Error copying RAWINPUT data");
        //                 return 0;
        //             }
        //             let data_ptr: *const RAWINPUT = input_buffer.as_ptr() as _;
        //             let (pos_x, pos_y) = if ((*data_ptr).data.mouse.usFlags
        //                 & MOUSE_MOVE_ABSOLUTE as u16)
        //                 != 0
        //             {
        //                 // For games we need the raw delta offset from the last position.
        //                 (
        //                     (*data_ptr).data.mouse.lLastX - window.data.platform_data.last_raw_pos.x,
        //                     (*data_ptr).data.mouse.lLastY - window.data.platform_data.last_raw_pos.y,
        //                 )
        //             } else {
        //                 // The movement is already relative.
        //                 ((*data_ptr).data.mouse.lLastX, (*data_ptr).data.mouse.lLastY)
        //             };
        //             window.data.platform_data.last_raw_pos.x += pos_x;
        //             window.data.platform_data.last_raw_pos.y += pos_y;
        //             let event = Event::create_raw_mouse_event(pos_x, pos_y);
        //             window.queueEvent(event);
        //         }
        //     }
        else => {},
    }
    return win32_window_messaging.DefWindowProcW(hwnd, msg, wparam, lparam);
}
