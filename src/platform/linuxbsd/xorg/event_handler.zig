const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const cursor = @import("cursor.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const utils = @import("utils.zig");
const keymaps = @import("keymaps.zig");
const wndw = @import("window.zig");
const opts = @import("build-options");

const kbd_mouse = common.keyboard_mouse;

const X11Driver = @import("driver.zig").X11Driver;
const WidowContext = @import("platform.zig").WidowContext;
const Window = wndw.Window;

inline fn handleButtonRelease(e: *const libx11.XButtonEvent, window: *Window) void {
    if (opts.LOG_PLATFORM_EVENTS) {
        std.log.info("window: #{} recieved ButtonRelease\n", .{window.data.id});
    }

    const button = switch (e.button) {
        libx11.Button1 => kbd_mouse.MouseButton.Left,
        libx11.Button2 => kbd_mouse.MouseButton.Middle,
        libx11.Button3 => kbd_mouse.MouseButton.Right,
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

    window.data.input.mouse_buttons[@intFromEnum(button)] = .Released;
    const ev = common.event.createMouseButtonEvent(
        window.data.id,
        button,
        kbd_mouse.MouseButtonState.Released,
        utils.decodeKeyMods(e.state),
    );
    window.sendEvent(&ev);
}

inline fn handleButtonPress(e: *const libx11.XButtonEvent, window: *Window) void {
    if (opts.LOG_PLATFORM_EVENTS) {
        std.log.info("window: #{} recieved ButtonPress\n", .{window.data.id});
    }

    const button_event = switch (e.button) {
        libx11.Button1 => ev: {
            window.data.input.mouse_buttons[@intFromEnum(kbd_mouse.MouseButton.Left)] = .Pressed;
            break :ev common.event.createMouseButtonEvent(
                window.data.id,
                kbd_mouse.MouseButton.Left,
                kbd_mouse.MouseButtonState.Pressed,
                utils.decodeKeyMods(e.state),
            );
        },
        libx11.Button2 => ev: {
            window.data.input.mouse_buttons[@intFromEnum(kbd_mouse.MouseButton.Middle)] = .Pressed;
            break :ev common.event.createMouseButtonEvent(
                window.data.id,
                kbd_mouse.MouseButton.Middle,
                kbd_mouse.MouseButtonState.Pressed,
                utils.decodeKeyMods(e.state),
            );
        },
        libx11.Button3 => ev: {
            window.data.input.mouse_buttons[@intFromEnum(kbd_mouse.MouseButton.Right)] = .Pressed;
            break :ev common.event.createMouseButtonEvent(
                window.data.id,
                kbd_mouse.MouseButton.Right,
                kbd_mouse.MouseButtonState.Pressed,
                utils.decodeKeyMods(e.state),
            );
        },
        // INFO:
        // [https://github.com/libsdl-org/SDL/blob/main/src/video/x11/SDL_x11events.c#L185C5-L187C80]
        // according to the xlib docs, no specific mouse wheel events exist.
        // However, the defacto standard is that the vertical wheel is X buttons
        // 4 (up) and 5 (down) and a horizontal wheel is 6 (left) and 7 (right).
        libx11.Button4 => common.event.createScrollEvent(
            window.data.id,
            0.0,
            1.0,
        ),
        libx11.Button5 => common.event.createScrollEvent(
            window.data.id,
            0.0,
            -1.0,
        ),
        libx11.Button6 => common.event.createScrollEvent(
            window.data.id,
            1.0,
            0.0,
        ),
        libx11.Button7 => common.event.createScrollEvent(
            window.data.id,
            -1.0,
            0.0,
        ),
        else => return,
    };
    window.sendEvent(&button_event);
}

/// handles ICCCM messages.
inline fn handleClientMessage(e: *const libx11.XClientMessageEvent, w: *Window) void {
    const drvr = w.ctx.driver;
    if (e.message_type == drvr.ewmh.WM_PROTOCOLS) {
        if (@as(libx11.Atom, @intCast(e.data.l[0])) == drvr.ewmh.WM_DELETE_WINDOW) {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved ClientMessage:WM_DELETE_WINDOW\n",
                    .{w.data.id},
                );
            }
            const event = common.event.createCloseEvent(w.data.id);
            w.sendEvent(&event);
        }
        if (@as(libx11.Atom, @intCast(e.data.l[0])) == drvr.ewmh._NET_WM_PING) {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved ClientMessage:_NET_WM_PING\n",
                    .{w.data.id},
                );
            }
            // ping from the wm to ensure application responsivity.
            // we just need to keep sending ping until the communication
            // is over.
            var reply = libx11.XEvent{ .xclient = e.* };
            reply.xclient.window = drvr.windowManagerId();
            drvr.sendXEvent(&reply, drvr.windowManagerId());
        }
    } else if (e.message_type == drvr.ewmh.XdndEnter) {
        if (opts.LOG_PLATFORM_EVENTS) {
            std.log.info(
                "window: #{} recieved ClientMessage:XdndEnter\n",
                .{w.data.id},
            );
        }
        w.x11.xdnd_req.src = e.data.l[0];
        w.x11.xdnd_req.version = e.data.l[1] >> 24;
        w.x11.xdnd_req.format = libx11.None;
        const support_extra_types = e.data.l[1] & 1;

        var extra_types_count: u32 = 0;
        var extra_types: [*]const libx11.Atom = undefined;
        if (support_extra_types != 0) {
            extra_types_count = utils.x11WindowProperty(
                drvr.handles.xdisplay,
                @bitCast(w.x11.xdnd_req.src),
                drvr.ewmh.XdndTypeList,
                libx11.XA_ATOM,
                @ptrCast(&extra_types),
            ) catch err: {
                extra_types = @ptrCast(&e.data.l[2]);
                break :err 3;
            };
        } else {
            extra_types_count = 3;
            extra_types = @ptrCast(&e.data.l[2]);
        }

        std.debug.assert(extra_types_count != 0);

        for (0..extra_types_count) |i| {
            if (extra_types[i] == drvr.ewmh.text_uri_list) {
                w.x11.xdnd_req.format = @intCast(drvr.ewmh.text_uri_list);
                break;
            }
        }

        if (support_extra_types != 0 and
            @intFromPtr(extra_types) != @intFromPtr(&e.data.l[2]))
        {
            _ = libx11.XFree(@constCast(extra_types));
            if (w.x11.xdnd_req.format == libx11.None) {
                // check the request atoms.
                extra_types_count = 3;
                extra_types = @ptrCast(&e.data.l[2]);
                for (0..extra_types_count) |i| {
                    if (extra_types[i] == drvr.ewmh.text_uri_list) {
                        w.x11.xdnd_req.format = @intCast(drvr.ewmh.text_uri_list);
                        break;
                    }
                }
            }
        }
    } else if (e.message_type == drvr.ewmh.XdndPosition) {
        if (opts.LOG_PLATFORM_EVENTS) {
            std.log.info(
                "window: #{} recieved ClientMessage:XdndPosition\n",
                .{w.data.id},
            );
        }

        std.debug.assert(w.x11.xdnd_req.src == e.data.l[0]);
        var reply = libx11.XEvent{
            .xclient = libx11.XClientMessageEvent{
                .type = libx11.ClientMessage,
                .display = drvr.handles.xdisplay,
                .window = @intCast(e.data.l[0]),
                .message_type = drvr.ewmh.XdndStatus,
                .format = 32,
                .serial = 0,
                .send_event = 0,
                .data = .{ .l = [5]c_long{
                    @intCast(w.handle),
                    if (w.x11.xdnd_req.format != libx11.None) 1 else 0,
                    0,
                    0,
                    @intCast(drvr.ewmh.XdndActionCopy),
                } },
            },
        };
        _ = libx11.XSendEvent(
            drvr.handles.xdisplay,
            @intCast(e.data.l[0]),
            libx11.False,
            libx11.NoEventMask,
            &reply,
        );
        drvr.flushXRequests();

        const x_root, const y_root = .{ (e.data.l[2] >> 16), e.data.l[2] & 0xffff };
        var x: c_int, var y: c_int = .{ 0, 0 };
        var child: libx11.Window = 0;

        _ = libx11.XTranslateCoordinates(
            drvr.handles.xdisplay,
            drvr.windowManagerId(),
            w.handle,
            @intCast(x_root),
            @intCast(y_root),
            &x,
            &y,
            &child,
        );
        const event = common.event.createMoveEvent(
            w.data.id,
            @intCast(x),
            @intCast(y),
            true,
        );
        w.sendEvent(&event);
    } else if (e.message_type == drvr.ewmh.XdndDrop) {
        if (opts.LOG_PLATFORM_EVENTS) {
            std.log.info(
                "window: #{} recieved ClientMessage:XdndDrop\n",
                .{w.data.id},
            );
        }
        std.debug.assert(w.x11.xdnd_req.src == e.data.l[0]);
        if (w.x11.xdnd_req.format != libx11.None) {
            libx11.XConvertSelection(
                drvr.handles.xdisplay,
                drvr.ewmh.XdndSelection,
                @intCast(w.x11.xdnd_req.format),
                drvr.ewmh.XdndSelection,
                w.handle,
                if (w.x11.xdnd_req.version >= 1) @intCast(e.data.l[2]) else libx11.CurrentTime,
            );
        } else {
            // no uri list finish the drop
            var event = libx11.XEvent{
                .xclient = libx11.XClientMessageEvent{
                    .type = libx11.ClientMessage,
                    .display = drvr.handles.xdisplay,
                    .window = @intCast(e.data.l[0]),
                    .message_type = drvr.ewmh.XdndFinished,
                    .format = 32,
                    .serial = 0,
                    .send_event = 0,
                    .data = .{ .l = [5]c_long{
                        @intCast(w.handle),
                        0,
                        0,
                        0,
                        0,
                    } },
                },
            };
            drvr.sendXEvent(&event, @intCast(w.x11.xdnd_req.src));
            drvr.flushXRequests();
        }
    }
}

inline fn handleKeyPress(ev: *const libx11.XKeyEvent, window: *Window) void {
    const km = window.ctx.key_map;
    switch (ev.type) {
        libx11.KeyPress => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved KeyPress:code {}\n",
                    .{ window.data.id, ev.keycode },
                );
            }
            const keycode = km.lookupKeyCode(@intCast(ev.keycode));
            const scancode = keymaps.keycodeToScancode(@intCast(ev.keycode));
            var mods = utils.decodeKeyMods(ev.state);
            utils.fixKeyMods(&mods, keycode, kbd_mouse.KeyState.Pressed);
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
            if (km.lookupKeyCharacter(keysym)) |codepoint| {
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
            const driver = window.ctx.driver;
            if (!driver.extensions.xkb.is_auto_repeat_detectable) {
                // INFO:
                // hack from glfw
                // if if we couldn't enable key autorepeat through Xkeyboard
                // extension we can simulate it by reading ahead in the event queue
                // and setting an autorepeat threshold for wich we can ignore key release
                // events.
                if (libx11.XEventsQueued(
                    driver.handles.xdisplay,
                    libx11.QueuedAfterReading,
                ) != 0) {
                    var next_xevent: libx11.XEvent = undefined;
                    _ = libx11.XPeekEvent(driver.handles.xdisplay, &next_xevent);
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
            const keycode = km.lookupKeyCode(@intCast(ev.keycode));
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

inline fn handleXSelection(e: *const libx11.XSelectionEvent, window: *Window) void {
    if (opts.LOG_PLATFORM_EVENTS) {
        std.log.info(
            "window: #{} recieved SelectionNotify\n",
            .{window.data.id},
        );
    }

    const drvr = window.ctx.driver;
    if (e.property != drvr.ewmh.XdndSelection) {
        return;
    }

    var success: c_long = 0;

    var dropped_data: ?[*]u8 = null;
    const ret = utils.x11WindowProperty(
        drvr.handles.xdisplay,
        // e.requestor,
        window.handle,
        e.property,
        // e.target,
        drvr.ewmh.text_uri_list,
        @ptrCast(&dropped_data),
    ) catch 0;

    if (dropped_data) |data| {
        if (window.x11.xdnd_req.raw_data) |rd| {
            // free old file URI list.
            _ = libx11.XFree(@constCast(rd));
        }
        window.x11.xdnd_req.raw_data = data;

        if (ret != 0) {
            success = 1;
        }
        window.x11.xdnd_req.paths.clearRetainingCapacity();
        const data_len = utils.strZLen(@ptrCast(data));
        var data_slice: [:0]const u8 = undefined;
        data_slice.ptr = @ptrCast(data);
        data_slice.len = data_len;
        utils.parseDroppedFilesURI(window.ctx.allocator, data_slice, &window.x11.xdnd_req.paths) catch |err| {
            var ev: libx11.XEvent = undefined;
            ev.type = libx11.ClientMessage;
            ev.xclient.window = window.handle;
            ev.xclient.message_type = X11Driver.CUSTOM_CLIENT_ERR;
            ev.xclient.format = 32;
            ev.xclient.data.l[0] = @intFromError(err);
            std.debug.assert(ev.xclient.message_type != 0);
            drvr.sendXEvent(&ev, window.handle);
        };
    }

    var event = libx11.XEvent{
        .xclient = libx11.XClientMessageEvent{
            .type = libx11.ClientMessage,
            .display = drvr.handles.xdisplay,
            .window = @intCast(window.x11.xdnd_req.src),
            .message_type = drvr.ewmh.XdndFinished,
            .format = 32,
            .serial = 0,
            .send_event = 0,
            .data = .{
                .l = [5]c_long{
                    @intCast(window.handle),
                    success,
                    // @intCast(drvr.ewmh.XdndActionCopy),
                    0,
                    0,
                    0,
                },
            },
        },
    };

    drvr.sendXEvent(&event, @intCast(window.x11.xdnd_req.src));
    drvr.flushXRequests();

    if (success == 1) {
        const drop_event = common.event.createDropFileEvent(
            window.data.id,
        );
        window.sendEvent(&drop_event);
    }
}

inline fn handlePropertyNotify(e: *const libx11.XPropertyEvent, window: *Window) void {
    if (opts.LOG_PLATFORM_EVENTS) {
        std.log.info(
            "window: #{} recieved PropertyNotify\n",
            .{window.data.id},
        );
    }
    const drvr = window.ctx.driver;
    if (e.state != libx11.PropertyNewValue) {
        return;
    }

    if (e.atom == drvr.ewmh.WM_STATE) {
        var state: ?*extern struct {
            state: u32,
            icon: libx11.Window,
        } = null;

        _ = utils.x11WindowProperty(
            drvr.handles.xdisplay,
            window.handle,
            drvr.ewmh.WM_STATE,
            drvr.ewmh.WM_STATE,
            @ptrCast(&state),
        ) catch return;

        if (state) |s| {
            defer _ = libx11.XFree(@ptrCast(state));
            window.data.flags.is_minimized = s.state == libx11.IconicState;
        }
        const event = common.event.createMinimizeEvent(window.data.id);
        window.sendEvent(&event);
    } else if (e.atom == drvr.ewmh._NET_WM_STATE) {
        var state: ?[*]libx11.Atom = null;
        const count = utils.x11WindowProperty(
            drvr.handles.xdisplay,
            window.handle,
            drvr.ewmh._NET_WM_STATE,
            libx11.XA_ATOM,
            @ptrCast(&state),
        ) catch return;

        if (state) |s| {
            defer _ = libx11.XFree(@ptrCast(state));
            var maximized = false;
            for (0..count) |i| {
                if (s[i] == drvr.ewmh._NET_WM_STATE_MAXIMIZED_VERT or
                    s[i] == drvr.ewmh._NET_WM_STATE_MAXIMIZED_HORZ)
                {
                    maximized = true;
                    break;
                }
            }

            if (maximized) {
                window.data.flags.is_maximized = maximized;
                const event = common.event.createMaximizeEvent(window.data.id);
                window.sendEvent(&event);
            }
        }
    }
}

inline fn handleGenericEvent(ev: *libx11.XGenericEventCookie, ctx: *const WidowContext) void {
    if (ctx.driver.extensions.xi2.is_v2point0 and
        libx11.XGetEventData(ctx.driver.handles.xdisplay, ev) == libx11.True and
        ev.extension == ctx.driver.extensions.xi2.maj_opcode and
        ev.evtype == x11ext.XI_RawMotion)
    {
        defer libx11.XFreeEventData(ctx.driver.handles.xdisplay, ev);

        const raw_ev: *x11ext.XIRawEvent = @ptrCast(@alignCast(ev.data));
        if (raw_ev.valuators.mask_len != 0 and ctx.raw_mouse_motion_window != null) {
            var read_indx: u32 = 0;
            var dx: f64, var dy: f64 = .{ 0.0, 0.0 };
            if (x11ext.XIMaskIsSet(raw_ev.valuators.mask, 0)) {
                dx += raw_ev.raw_values[read_indx];
                read_indx += 1;
            }
            if (x11ext.XIMaskIsSet(raw_ev.valuators.mask, 1)) {
                dy += raw_ev.raw_values[read_indx];
            }

            const window = wndw.windowFromId(ctx.driver, ctx.raw_mouse_motion_window.?) orelse unreachable;
            std.debug.assert(window.data.flags.has_raw_mouse);
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved GenericEvent(RawMouseMotion)\n",
                    .{window.data.id},
                );
            }
            window.x11.cursor.accum_pos.x +%= @as(i32, @intFromFloat(dx));
            window.x11.cursor.accum_pos.y +%= @as(i32, @intFromFloat(dy));
            const event = common.event.createMoveEvent(
                window.data.id,
                window.x11.cursor.accum_pos.x,
                window.x11.cursor.accum_pos.y,
                true,
            );
            window.sendEvent(&event);
            window.x11.cursor.pos.x += @as(i32, @intFromFloat(dx));
            window.x11.cursor.pos.y += @as(i32, @intFromFloat(dy));
        }
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
// }

pub fn handleNonWindowEvent(ev: *libx11.XEvent, ctx: *const WidowContext) void {
    switch (ev.type) {
        libx11.GenericEvent => handleGenericEvent(&ev.xcookie, ctx),
        else => {},
    }
}

pub fn handleWindowEvent(ev: *libx11.XEvent, window: *Window) void {
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
            const x, const y = .{ ev.xcrossing.x, ev.xcrossing.y };
            window.x11.cursor.pos = .{ .x = x, .y = y };
            cursor.applyCursorHints(window.ctx.driver, &window.x11.cursor, window.handle);
            if (window.data.flags.has_raw_mouse and window.x11.cursor.mode == .Hidden) {
                _ = wndw.enableRawMouseMotion(window.ctx.driver);
            }
            const enter_event = common.event.createMouseEnterEvent(
                window.data.id,
            );
            window.sendEvent(&enter_event);
            window.data.flags.cursor_in_client = true;
            const pos_event = common.event.createMoveEvent(
                window.data.id,
                x,
                y,
                true,
            );
            window.sendEvent(&pos_event);
        },

        libx11.LeaveNotify => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved LeaveNotify\n",
                    .{window.data.id},
                );
            }
            window.data.flags.cursor_in_client = false;
            if (window.data.flags.has_raw_mouse and window.x11.cursor.mode == .Hidden) {
                _ = wndw.disableRawMouseMotion(window.ctx.driver);
            }
            const event = common.event.createMouseExitEvent(window.data.id);
            window.sendEvent(&event);
        },

        libx11.ClientMessage => handleClientMessage(&ev.xclient, window),

        libx11.FocusIn => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved FocusIn\n",
                    .{window.data.id},
                );
            }
            cursor.applyCursorHints(window.ctx.driver, &window.x11.cursor, window.handle);
            const event = common.event.createFocusEvent(window.data.id, true);
            window.sendEvent(&event);
        },

        libx11.FocusOut => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved FocusOut\n",
                    .{window.data.id},
                );
            }
            cursor.undoCursorHints(window.ctx.driver, &window.x11.cursor, window.handle);
            const event = common.event.createFocusEvent(window.data.id, false);
            window.sendEvent(&event);
        },

        libx11.MotionNotify => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved MotionNotify\n",
                    .{window.data.id},
                );
            }
            const x, const y = .{ ev.xmotion.x, ev.xmotion.y };
            const dx = x - window.x11.cursor.pos.x;
            const dy = y - window.x11.cursor.pos.y;
            if (dx != 0 or dy != 0) {
                if (window.x11.cursor.mode == .Hidden) {
                    if (window.data.flags.has_raw_mouse) {
                        return;
                    }
                    window.x11.cursor.accum_pos.x +%= dx;
                    window.x11.cursor.accum_pos.y +%= dy;
                } else {
                    window.x11.cursor.accum_pos = .{ .x = x, .y = y };
                }
                const event = common.event.createMoveEvent(
                    window.data.id,
                    window.x11.cursor.accum_pos.x,
                    window.x11.cursor.accum_pos.y,
                    true,
                );
                window.sendEvent(&event);
                window.x11.cursor.pos = .{ .x = x, .y = y };
            }
        },

        libx11.ConfigureNotify => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved ConfigureNotify\n",
                    .{window.data.id},
                );
            }

            if (ev.xconfigure.width != window.data.client_area.size.width or
                ev.xconfigure.height != window.data.client_area.size.height)
            {
                window.data.client_area.size.width = ev.xconfigure.width;
                window.data.client_area.size.height = ev.xconfigure.height;

                const event = common.event.createResizeEvent(
                    window.data.id,
                    ev.xconfigure.width,
                    ev.xconfigure.height,
                );
                window.sendEvent(&event);
            }

            const wndw_pos_x, const wndw_pos_y = .{ ev.xconfigure.x, ev.xconfigure.y };

            if (wndw_pos_x != window.data.client_area.top_left.x or
                wndw_pos_y != window.data.client_area.top_left.y)
            {
                window.data.client_area.top_left.x = wndw_pos_x;
                window.data.client_area.top_left.y = wndw_pos_y;

                const event = common.event.createMoveEvent(
                    window.data.id,
                    wndw_pos_x,
                    wndw_pos_y,
                    false,
                );
                window.sendEvent(&event);
            }
        },

        libx11.Expose => {
            if (opts.LOG_PLATFORM_EVENTS) {
                std.log.info(
                    "window: #{} recieved Expose\n",
                    .{window.data.id},
                );
            }
            const event = common.event.createRedrawEvent(window.data.id);
            window.sendEvent(&event);
        },

        libx11.PropertyNotify => handlePropertyNotify(&ev.xproperty, window),

        libx11.SelectionNotify => handleXSelection(&ev.xselection, window),

        else => {},
    }
}
