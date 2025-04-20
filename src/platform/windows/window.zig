const std = @import("std");
const common = @import("common");
const gl = @import("gl");
const win32_gfx = @import("win32api/graphics.zig");
const win32_macros = @import("win32api/macros.zig");
const win32_input = @import("win32api/input.zig");
const shell32 = @import("win32api/shell32.zig");
const wgl = @import("wgl.zig");
const utils = @import("utils.zig");
const icon = @import("icon.zig");
const display = @import("display.zig");
const mem = std.mem;
const debug = std.debug;
const FBConfig = common.fb.FBConfig;
const win32 = std.os.windows;
const WindowData = common.window_data.WindowData;
const WindowFlags = common.window_data.WindowFlags;
const Win32Driver = @import("driver.zig").Win32Driver;
const WidowContext = @import("platform.zig").WidowContext;

pub const WindowError = error{
    CreateFailed,
    NoTitle,
    OutOfMemory,
    BadIcon,
    GLError,
};

/// We'll use this type to pass data to the `CreateWindowExW` function.
pub const CreationLparamTuple = std.meta.Tuple(&.{ *const WindowData, *const Win32Driver });

// Window Styles as defined by the SDL library.
// Basic : clip child and siblings windows when drawing to content.
const STYLE_BASIC: u32 = win32_gfx.WS_CLIPCHILDREN | win32_gfx.WS_CLIPSIBLINGS;
// Fullscreen : just a popup window with monitor width and height.
const STYLE_FULLSCREEN: u32 = win32_gfx.WS_POPUP;
// Captionless: without a caption(title bar)
const STYLE_BORDERLESS = STYLE_FULLSCREEN;
// Resizable : can be resized using the widow border can also be maximazed.
const STYLE_RESIZABLE: u32 = win32_gfx.WS_MAXIMIZEBOX | win32_gfx.WS_THICKFRAME;
// Normal: both a title bar and minimize button.
const STYLE_NORMAL: u32 = win32_gfx.WS_SYSMENU | win32_gfx.WS_MINIMIZEBOX;

const STYLES_MASK: u32 = STYLE_BASIC | STYLE_FULLSCREEN | STYLE_BORDERLESS |
    STYLE_RESIZABLE | STYLE_NORMAL | win32_gfx.WS_CAPTION;

const EX_STYLES_MASK: u32 = win32_gfx.WS_EX_TOPMOST | win32_gfx.WS_EX_APPWINDOW;

// Define our own message to report Window Procedure errors back
pub const WM_ERROR_REPORT: u32 = win32_gfx.WM_USER + 1;

// Define window property name
pub const WINDOW_REF_PROP = std.unicode.utf8ToUtf16LeStringLiteral("WINDOW_REF");

pub fn createHiddenWindow(
    title: [:0]const u16,
    driver: *const Win32Driver,
) WindowError!win32.HWND {
    const helper_window = win32_gfx.CreateWindowExW(
        @bitCast(@as(u32, 0)),
        win32_macros.MAKEINTATOM(driver.handles.helper_class),
        title,
        @bitCast(@as(u32, 0)),
        win32_gfx.CW_USEDEFAULT,
        win32_gfx.CW_USEDEFAULT,
        win32_gfx.CW_USEDEFAULT,
        win32_gfx.CW_USEDEFAULT,
        null,
        null,
        driver.handles.hinstance,
        null,
    ) orelse {
        return WindowError.CreateFailed;
    };

    _ = win32_gfx.ShowWindow(helper_window, win32_gfx.SW_HIDE);
    return helper_window;
}

pub fn windowStyles(flags: *const WindowFlags) u32 {
    var styles: u32 = STYLE_BASIC;

    if (flags.is_fullscreen) {
        styles |= STYLE_FULLSCREEN;
    } else {
        styles |= STYLE_NORMAL;
        if (!flags.is_decorated) {
            styles |= STYLE_BORDERLESS;
        } else {
            styles |= win32_gfx.WS_CAPTION;

            if (flags.is_resizable) {
                styles |= STYLE_RESIZABLE;
            }
        }

        if (flags.is_maximized) {
            styles |= win32_gfx.WS_MAXIMIZE;
        }

        if (flags.is_minimized) {
            styles |= win32_gfx.WS_MINIMIZE;
        }
    }

    return styles;
}

pub fn windowExStyles(flags: *const WindowFlags) u32 {
    var ex_styles: u32 = win32_gfx.WS_EX_APPWINDOW;
    if (flags.is_fullscreen or flags.is_topmost) {
        // Should be placed above all non topmost windows.
        ex_styles |= win32_gfx.WS_EX_TOPMOST;
    }
    return ex_styles;
}

/// Performs necessary adjustement for the rect structure.
/// this function modifies the rect so that it
/// describes a window rectangle which is the smallest rectangle
/// that encloses completely both client and non client(titlebar...)
/// areas.
/// if `dpi` is null it will use the default platform dpi (96)
pub fn adjustWindowRect(
    drvr: *const Win32Driver,
    rect: *win32.RECT,
    styles: u32,
    ex_styles: u32,
    dpi: ?u32,
) void {
    // HACK: AdjustWindowRectExForDpi computes a
    // wrong rectangle for non dpi aware windows (some pixels are lost in both width and height)
    // so don't use it
    if (dpi != null and drvr.opt_func.AdjustWindowRectExForDpi != null) {
        _ = drvr.opt_func.AdjustWindowRectExForDpi.?(
            rect,
            styles,
            0,
            ex_styles,
            dpi.?,
        );
    } else {
        _ = win32_gfx.AdjustWindowRectEx(
            rect,
            @bitCast(styles),
            0,
            @bitCast(ex_styles),
        );
    }
}

/// Converts client coordinate of `rect` to screen coordinate.
fn clientToScreen(window_handle: win32.HWND, rect: *win32.RECT) void {
    var upper_left = win32.POINT{
        .x = rect.left,
        .y = rect.top,
    };
    var lower_right = win32.POINT{
        .x = rect.right,
        .y = rect.bottom,
    };

    _ = win32_gfx.ClientToScreen(window_handle, &upper_left);
    _ = win32_gfx.ClientToScreen(window_handle, &lower_right);

    rect.* = win32.RECT{
        .left = upper_left.x,
        .top = upper_left.y,
        .right = lower_right.x,
        .bottom = lower_right.y,
    };
}

/// Returns the (width,height) of the entire window frame.
pub fn windowSize(window_handle: win32.HWND) common.geometry.RectSize {
    var rect: win32.RECT = undefined;
    _ = win32_gfx.GetWindowRect(window_handle, &rect);
    const size = common.geometry.RectSize{
        .width = rect.right - rect.left,
        .height = rect.bottom - rect.top,
    };
    return size;
}

pub fn applyCursorHints(hints: *icon.CursorHints, window: win32.HWND) void {
    switch (hints.mode) {
        .Normal => unCaptureCursor(),
        else => captureCursor(window),
    }

    const cursor_icon = switch (hints.mode) {
        .Hidden => null,
        else => img: {
            break :img if (hints.icon) |h|
                h
            else
                win32_gfx.LoadCursorW(null, win32_gfx.IDC_ARROW);
        },
    };

    _ = win32_gfx.SetCursor(cursor_icon);
}

pub fn restoreCursor(hints: *icon.CursorHints) void {
    switch (hints.mode) {
        .Captured, .Hidden => unCaptureCursor(),
        else => {},
    }
    _ = win32_gfx.SetCursor(win32_gfx.LoadCursorW(null, win32_gfx.IDC_ARROW));
}

/// Limits the cursor motion to the client rectangle.
inline fn captureCursor(window_handle: win32.HWND) void {
    var clip_rect: win32.RECT = undefined;
    _ = win32_gfx.GetClientRect(window_handle, &clip_rect);
    // ClipCursor expects screen coordinates.
    clientToScreen(window_handle, &clip_rect);
    _ = win32_gfx.ClipCursor(&clip_rect);
}

/// Removes cursor motion limitation.
inline fn unCaptureCursor() void {
    _ = win32_gfx.ClipCursor(null);
}

/// helper function for changing the window position,size and styles.
fn setWindowPositionIntern(
    window_handle: win32.HWND,
    top: ?win32.HWND,
    flags: win32_gfx.SET_WINDOW_POS_FLAGS,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
) void {
    _ = win32_gfx.SetWindowPos(
        window_handle,
        top,
        x,
        y,
        width,
        height,
        flags,
    );
}

fn createPlatformWindow(
    ctx: *const WidowContext,
    title: []const u8,
    data: *const WindowData,
    style: u32,
    ex_style: u32,
) !win32.HWND {
    var window_rect = win32.RECT{
        .left = 0,
        .top = 0,
        .right = data.client_area.size.width,
        .bottom = data.client_area.size.height,
    };

    // Calculates the required size of the window rectangle,
    // based on the desired client-rectangle size.
    // Note: for the dpi adjustements we can either
    // query the system for the targted monitor(the one that intersect
    // the window frame rectangle)'s dpi value and adjust for it now
    // or do it after window creation, we will leave it for after creation.
    adjustWindowRect(ctx.driver, &window_rect, style, ex_style, null);

    // Decide the position(top left) of the client area
    var frame_x: i32 = win32_gfx.CW_USEDEFAULT;
    var frame_y: i32 = win32_gfx.CW_USEDEFAULT;
    if (data.client_area.top_left.x != win32_gfx.CW_USEDEFAULT and
        data.client_area.top_left.y != win32_gfx.CW_USEDEFAULT)
    {
        frame_x = data.client_area.top_left.x + window_rect.left;
        frame_y = data.client_area.top_left.y + window_rect.top;
    }

    // Final window frame.
    const frame = .{
        frame_x,
        frame_y,
        window_rect.right - window_rect.left,
        window_rect.bottom - window_rect.top,
    };

    // Encode the title string in utf-16.
    const window_title = try utils.utf8ToWideZ(ctx.allocator, title);
    defer ctx.allocator.free(window_title);

    const creation_lparm: CreationLparamTuple = .{ data, ctx.driver };

    // Create the window.
    const window_handle = win32_gfx.CreateWindowExW(
        @bitCast(ex_style), // dwExStyles
        win32_macros.MAKEINTATOM(ctx.driver.handles.wnd_class),
        window_title, // Window Name
        @bitCast(style), // dwStyles
        frame[0], // X
        frame[1], // Y
        frame[2], // width
        frame[3], // height
        null, // Parent Hwnd
        null, // hMenu
        ctx.driver.handles.hinstance, // hInstance
        @ptrCast(@constCast(&creation_lparm)), // CREATESTRUCT lparam
    ) orelse {
        return WindowError.CreateFailed;
    };

    return window_handle;
}

/// Win32 specific data.
pub const WindowWin32Data = struct {
    icon: icon.Icon,
    dropped_files: std.ArrayListUnmanaged([]const u8),
    cursor: icon.CursorHints,
    prev_frame: common.geometry.Rect, // Used when going fullscreen to save restore coords.
    high_surrogate: u16,
    frame_action: bool,
    position_update: bool,
    allow_drag_n_drop: bool,
};

pub const Window = struct {
    ctx: *WidowContext,
    ev_queue: ?*common.event.EventQueue,
    handle: win32.HWND,
    data: WindowData,
    win32: WindowWin32Data,
    fb_cfg: FBConfig,

    pub const WINDOW_DEFAULT_POSITION = common.geometry.Point2D{
        .x = win32_gfx.CW_USEDEFAULT,
        .y = win32_gfx.CW_USEDEFAULT,
    };
    const Self = @This();

    pub fn init(
        ctx: *WidowContext,
        id: ?usize,
        window_title: []const u8,
        data: *WindowData,
        fb_cfg: *FBConfig,
    ) !*Self {
        var self = try ctx.allocator.create(Self);
        errdefer ctx.allocator.destroy(self);

        self.ctx = ctx;
        self.ev_queue = null;
        self.data = data.*;
        self.fb_cfg = fb_cfg.*;

        const style, const ex_style = .{
            windowStyles(&data.flags),
            windowExStyles(&data.flags),
        };

        self.handle = try createPlatformWindow(
            ctx,
            window_title,
            data,
            style,
            ex_style,
        );
        errdefer _ = win32_gfx.DestroyWindow(self.handle);

        // Finish setting up the window.
        self.data.id = if (id) |ident| ident else @intFromPtr(self.handle);

        self.win32 = WindowWin32Data{
            .cursor = icon.CursorHints{
                .icon = null, // uses the default system image
                .mode = common.cursor.CursorMode.Normal,
                .sys_owned = false,
                .pos = .{ .x = 0, .y = 0 },
                .accum_pos = .{ .x = 0, .y = 0 },
            },
            .icon = icon.Icon{
                .sm_handle = null,
                .bg_handle = null,
            },
            .high_surrogate = 0,
            .frame_action = false,
            .position_update = false,
            .dropped_files = .empty,
            .allow_drag_n_drop = false,
            .prev_frame = .{
                .size = .{ .width = 0, .height = 0 },
                .top_left = .{ .x = 0, .y = 0 },
            },
        };

        // Process inital events.
        // these events aren't reported.
        self.processEvents() catch unreachable;

        _ = win32_gfx.SetPropW(
            self.handle,
            WINDOW_REF_PROP,
            @ptrCast(self),
        );
        errdefer _ = win32_gfx.SetPropW(
            self.handle,
            WINDOW_REF_PROP,
            null,
        );

        // handle DPI adjustments.
        if (self.data.flags.is_dpi_aware) {
            var client_rect = win32.RECT{
                .left = 0,
                .top = 0,
                .right = self.data.client_area.size.width,
                .bottom = self.data.client_area.size.height,
            };
            var dpi_scale: f64 = undefined;
            const dpi = self.getScalingDPI(&dpi_scale);
            // the requested client width and height are scaled by the display scale factor.
            const fwidth: f64 = @floatFromInt(client_rect.right);
            const fheight: f64 = @floatFromInt(client_rect.bottom);
            client_rect.right = @intFromFloat(fwidth * dpi_scale);
            client_rect.bottom = @intFromFloat(fheight * dpi_scale);

            adjustWindowRect(
                self.ctx.driver,
                &client_rect,
                style,
                ex_style,
                dpi,
            );

            var window_rect: win32.RECT = undefined;
            // [MSDN]:If the window has not been shown before,
            // GetWindowRect will not include the area of the drop shadow.
            _ = win32_gfx.GetWindowRect(self.handle, &window_rect);
            // Offset and readjust the created window's frame.
            _ = win32_gfx.OffsetRect(
                &client_rect,
                window_rect.left - client_rect.left,
                window_rect.top - client_rect.top,
            );

            const top = if (self.data.flags.is_topmost)
                win32_gfx.HWND_TOPMOST
            else
                win32_gfx.HWND_NOTOPMOST;
            const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
                .NOZORDER = 1,
                .NOACTIVATE = 1,
                .NOOWNERZORDER = 1,
            };

            setWindowPositionIntern(
                self.handle,
                top,
                POSITION_FLAGS,
                client_rect.left,
                client_rect.top,
                client_rect.right - client_rect.left,
                client_rect.bottom - client_rect.top,
            );
        }

        // Allow Drag & Drop messages.
        if (self.ctx.driver.hints.is_win7_or_above) {
            // Sent when the user drops a file on the window [Windows XP minimum]
            _ = win32_gfx.ChangeWindowMessageFilterEx(
                self.handle,
                win32_gfx.WM_DROPFILES,
                win32_gfx.MSGFLT_ALLOW,
                null,
            );
            _ = win32_gfx.ChangeWindowMessageFilterEx(
                self.handle,
                win32_gfx.WM_COPYDATA,
                win32_gfx.MSGFLT_ALLOW,
                null,
            );
            _ = win32_gfx.ChangeWindowMessageFilterEx(
                self.handle,
                win32_gfx.WM_COPYGLOBALDATA,
                win32_gfx.MSGFLT_ALLOW,
                null,
            );
        }

        if (self.data.flags.is_visible) {
            self.show();
            if (self.data.flags.is_focused) {
                self.focus();
            }
        }

        // Fullscreen
        if (self.data.flags.is_fullscreen) {
            self.data.flags.is_fullscreen = false;
            // this functions can only switch to fullscreen mode
            // if the flag is already false.
            if (!self.setFullscreen(true)) {
                return WindowError.CreateFailed;
            }
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.ev_queue = null;
        // Clean up code
        if (self.data.flags.is_fullscreen) {
            // release the currently occupied monitor
            _ = self.setFullscreen(false);
        }
        self.win32.cursor.mode = .Normal;
        applyCursorHints(&self.win32.cursor, self.handle);

        _ = win32_gfx.SetPropW(self.handle, WINDOW_REF_PROP, null);
        _ = win32_gfx.DestroyWindow(self.handle);
        self.freeDroppedFiles();
        const ctx = self.ctx;
        ctx.allocator.destroy(self);
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        // Show without activating.
        _ = win32_gfx.ShowWindow(self.handle, win32_gfx.SW_SHOWNA);
        self.data.flags.is_visible = true;
    }

    pub fn focus(self: *Self) void {
        _ = win32_gfx.BringWindowToTop(self.handle);
        _ = win32_gfx.SetForegroundWindow(self.handle);
        _ = win32_input.SetFocus(self.handle);
    }

    pub fn getScalingDPI(self: *const Self, scaler: ?*f64) u32 {
        var dpi: u32 = win32_gfx.USER_DEFAULT_SCREEN_DPI;
        null_exit: {
            if (self.ctx.driver.opt_func.GetDpiForWindow) |func| {
                dpi = func(self.handle);
            } else {
                const disp = self.ctx.display_mgr.findWindowDisplay(self) catch break :null_exit;
                dpi = disp.displayDPI(self.ctx.driver);
            }
        }
        if (scaler) |s| {
            const fdpi: f64 = @floatFromInt(dpi);
            s.* = (fdpi / win32_gfx.USER_DEFAULT_SCREEN_DPI_F);
        }
        return dpi;
    }

    /// the window should belong to the thread calling this function.
    pub fn processEvents(self: *Self) WindowError!void {
        var msg: win32_gfx.MSG = undefined;
        while (win32_gfx.PeekMessageW(&msg, self.handle, 0, 0, win32_gfx.PM_REMOVE) != 0) {
            if (msg.message == WM_ERROR_REPORT) {
                // our custom error message
                return @as(
                    WindowError,
                    @errorCast(@errorFromInt(@as(
                        std.meta.Int(.unsigned, @bitSizeOf(anyerror)),
                        @truncate(msg.wParam),
                    ))),
                );
            }
            _ = win32_gfx.TranslateMessage(&msg);
            _ = win32_gfx.DispatchMessageW(&msg);
        }
        // Emit key up for released modifers keys.
        utils.clearStickyKeys(self);
        // Recenter hidden cursor.
        if (self.win32.cursor.mode == .Hidden) {
            const half_w = @divExact(self.data.client_area.size.width, 2);
            const half_y = @divExact(self.data.client_area.size.height, 2);
            if (self.win32.cursor.pos.x != half_w or
                self.win32.cursor.pos.y != half_y)
            {
                self.setCursorPosition(half_w, half_y);
            }
        }
    }

    pub inline fn getEventQueue(self: *Self) ?*common.event.EventQueue {
        return self.ev_queue;
    }

    pub inline fn setEventQueue(
        self: *Self,
        q: ?*common.event.EventQueue,
    ) ?*common.event.EventQueue {
        const ret = self.ev_queue;
        self.ev_queue = q;
        return ret;
    }

    /// Add an event to the events queue.
    pub fn sendEvent(self: *Self, event: *const common.event.Event) void {
        if (self.ev_queue) |q| {
            q.queueEvent(event) catch |err| {
                utils.postWindowErrorMsg(err, self.handle);
            };
        }
    }

    pub fn waitEvent(self: *Self) WindowError!void {
        _ = win32_gfx.WaitMessage();
        try self.processEvents();
    }

    /// the window should belong to the thread calling this function.
    /// Waits for an input event or the timeout interval elapses.
    /// if an event is received before timout it returns true,
    /// false otherwise.
    pub fn waitEventTimeout(self: *Self, timeout: u32) WindowError!bool {
        if (win32_gfx.MsgWaitForMultipleObjects(
            0,
            null,
            0,
            timeout,
            win32_gfx.QS_ALLINPUT,
        ) == win32.WAIT_TIMEOUT) {
            // Timeout period elapsed.
            return false;
        }
        try self.processEvents();
        return true;
    }

    /// Updates the registered window styles to match the current window config.
    fn updateStyles(
        self: *Self,
        new_area: *const common.geometry.Rect,
    ) void {
        const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
            .DRAWFRAME = 1,
            .NOACTIVATE = 1,
            .NOZORDER = 1,
        };

        var reg_styles: usize = @bitCast(win32_gfx.GetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_STYLE,
        ));
        var reg_ex_styles: usize = @bitCast(win32_gfx.GetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_EXSTYLE,
        ));

        reg_styles &= ~STYLES_MASK;
        reg_ex_styles &= ~EX_STYLES_MASK;
        reg_styles |= windowStyles(&self.data.flags);
        reg_ex_styles |= windowExStyles(&self.data.flags);

        _ = win32_gfx.SetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_STYLE,
            @bitCast(reg_styles),
        );

        _ = win32_gfx.SetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_EXSTYLE,
            @bitCast(reg_ex_styles),
        );

        var rect: win32.RECT = undefined;
        rect.left = new_area.top_left.x;
        rect.top = new_area.top_left.y;
        rect.right = new_area.size.width + rect.left;
        rect.bottom = new_area.size.height + rect.top;

        const dpi: ?u32 = if (self.data.flags.is_dpi_aware)
            self.getScalingDPI(null)
        else
            null;

        adjustWindowRect(
            self.ctx.driver,
            &rect,
            @truncate(reg_styles),
            @truncate(reg_ex_styles),
            dpi,
        );

        const top = if (self.data.flags.is_topmost)
            win32_gfx.HWND_TOPMOST
        else
            win32_gfx.HWND_NOTOPMOST;

        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            rect.left,
            rect.top,
            (rect.right - rect.left),
            (rect.bottom - rect.top),
        );
    }

    pub fn getCursorPosition(self: *const Self) common.geometry.Point2D {
        var cursor_pos: win32.POINT = undefined;
        _ = win32_gfx.GetCursorPos(&cursor_pos);
        _ = win32_gfx.ScreenToClient(self.handle, &cursor_pos);
        // the cursor pos is relative to the upper left corner of the window.
        return common.geometry.Point2D{ .x = cursor_pos.x, .y = cursor_pos.y };
    }

    pub fn setCursorPosition(self: *Self, x: i32, y: i32) void {
        var point = win32.POINT{
            .x = x,
            .y = y,
        };
        // no event will be reported.
        self.win32.cursor.pos.x = point.x;
        self.win32.cursor.pos.y = point.y;
        _ = win32_gfx.ClientToScreen(self.handle, &point);
        _ = win32_gfx.SetCursorPos(point.x, point.y);
    }

    pub fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
        self.win32.cursor.mode = mode;
        applyCursorHints(&self.win32.cursor, self.handle);
        if (self.data.flags.has_raw_mouse) {
            if (mode == .Hidden) {
                _ = enableRawMouseMotion(self.handle);
            } else {
                _ = disableRawMouseMotion();
            }
        }
    }

    /// Notify and flash the taskbar.
    pub fn flash(self: *const Self) void {
        var flash_info = win32_gfx.FLASHWINFO{
            .cbSize = @sizeOf(win32_gfx.FLASHWINFO),
            .hwnd = self.handle,
            .dwFlags = win32_gfx.FLASHW_ALL,
            .uCount = 3,
            .dwTimeout = 0,
        };
        _ = win32_gfx.FlashWindowEx(&flash_info);
    }

    /// Returns the position of the top left corner of the client area.
    pub inline fn getClientPosition(self: *const Self) common.geometry.Point2D {
        return self.data.client_area.top_left;
    }

    /// Moves the client's top left corner
    /// to the specified screen coordinates.
    pub fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        // Don't use SWP_NOSIZE to allow dpi change.
        const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
            .NOZORDER = 1,
            .NOACTIVATE = 1,
            .NOOWNERZORDER = 1,
        };

        if (self.data.flags.is_maximized) {
            // Moving a maximized window should restore it
            // to it's orignal size
            self.restore();
        }

        var rect: win32.RECT = win32.RECT{
            .left = 0,
            .top = 0,
            .right = self.data.client_area.size.width,
            .bottom = self.data.client_area.size.height,
        };

        const dpi: ?u32 = if (self.data.flags.is_dpi_aware) self.getScalingDPI(null) else null;

        adjustWindowRect(
            self.ctx.driver,
            &rect,
            windowStyles(&self.data.flags),
            windowExStyles(&self.data.flags),
            dpi,
        );

        rect.left += x;
        rect.top += y;

        const top = if (self.data.flags.is_topmost)
            win32_gfx.HWND_TOPMOST
        else
            win32_gfx.HWND_NOTOPMOST;

        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            rect.left,
            rect.top,
            rect.right - rect.left,
            rect.bottom - rect.top,
        );
    }

    /// Returns the Pixel size of the window's client area
    pub inline fn getClientPixelSize(self: *const Self) common.geometry.RectSize {
        return common.geometry.RectSize{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
    }

    /// Returns the logical size of the window's client area
    pub fn getClientSize(self: *const Self) common.geometry.RectSize {
        var client_size = common.geometry.RectSize{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
        if (self.data.flags.is_dpi_aware and !self.data.flags.is_fullscreen) {
            const dpi: f64 = @floatFromInt(self.getScalingDPI(null));
            const r_scaler = (win32_gfx.USER_DEFAULT_SCREEN_DPI_F / dpi);
            client_size.scaleBy(r_scaler);
        }
        return client_size;
    }

    /// Sets the new (width,height) of the window's client area
    pub fn setClientSize(self: *Self, size: *common.geometry.RectSize) void {
        if (!self.data.flags.is_fullscreen) {
            var dpi: ?u32 = null;
            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                dpi = self.getScalingDPI(&scaler);
                size.scaleBy(scaler);
            }

            var new_client_rect = win32.RECT{
                .left = 0,
                .top = 0,
                .right = size.width,
                .bottom = size.height,
            };

            adjustWindowRect(
                self.ctx.driver,
                &new_client_rect,
                windowStyles(&self.data.flags),
                windowExStyles(&self.data.flags),
                dpi,
            );
            if (self.data.flags.is_maximized) {
                // un-maximize the window
                self.restore();
            }

            const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
                .NOACTIVATE = 1,
                .NOZORDER = 1,
                .NOOWNERZORDER = 1,
                .NOMOVE = 1,
            };

            const top = if (self.data.flags.is_topmost)
                win32_gfx.HWND_TOPMOST
            else
                win32_gfx.HWND_NOTOPMOST;

            setWindowPositionIntern(
                self.handle,
                top,
                POSITION_FLAGS,
                0,
                0,
                new_client_rect.right - new_client_rect.left,
                new_client_rect.bottom - new_client_rect.top,
            );
        }
    }

    pub fn setMinSize(self: *Self, min_size: ?common.geometry.RectSize) void {
        if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
            // No need to do anything.
            return;
        }

        if (min_size != null) {
            var size = min_size.?;
            // min size shouldn't be negative.
            debug.assert(size.width > 0);
            debug.assert(size.height > 0);

            if (self.data.max_size) |*max_size| {
                // the min size shouldn't be superior to the max size.
                if (max_size.width < size.width or max_size.height < size.height) {
                    std.log.err(
                        "[Window] Specified minimum size(w:{},h:{}) is less than the maximum size(w:{},h:{})\n",
                        .{ size.width, size.height, max_size.width, max_size.height },
                    );
                    return;
                }
            }

            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                _ = self.getScalingDPI(&scaler);
                size.scaleBy(scaler);
            }

            self.data.min_size = size;
        } else {
            self.data.min_size = null;
        }

        const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
            .NOACTIVATE = 1,
            .NOZORDER = 1,
            .NOOWNERZORDER = 1,
            .NOMOVE = 1,
        };

        const size = windowSize(self.handle);

        const top = if (self.data.flags.is_topmost)
            win32_gfx.HWND_TOPMOST
        else
            win32_gfx.HWND_NOTOPMOST;
        // We need the system to post a WM_MINMAXINFO.
        // in order for the new size limits to be applied,
        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            0,
            0,
            size.width,
            size.height,
        );
    }

    pub fn setMaxSize(self: *Self, max_size: ?common.geometry.RectSize) void {
        if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
            // No need to do anything.
            return;
        }

        if (max_size != null) {
            var size = max_size.?;
            // max size shouldn't be negative.
            debug.assert(size.width > 0);
            debug.assert(size.height > 0);
            if (self.data.min_size) |*min_size| {
                // the max size should be superior or equal to the min size.
                if (size.width < min_size.width or size.height < min_size.height) {
                    std.log.err(
                        "[Window] Specified maximum size(w:{},h:{}) is less than the minimum size(w:{},h:{})\n",
                        .{ size.width, size.height, min_size.width, min_size.height },
                    );
                    return;
                }
            }
            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                _ = self.getScalingDPI(&scaler);
                size.scaleBy(scaler);
            }
            self.data.max_size = size;
        } else {
            self.data.max_size = null;
        }

        const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
            .NOACTIVATE = 1,
            .NOZORDER = 1,
            .NOOWNERZORDER = 1,
            .NOMOVE = 1,
        };

        const size = windowSize(self.handle);

        const top = if (self.data.flags.is_topmost)
            win32_gfx.HWND_TOPMOST
        else
            win32_gfx.HWND_NOTOPMOST;
        // We need the system to post a WM_MINMAXINFO.
        // in order for the new size limits to be applied,
        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            0,
            0,
            size.width,
            size.height,
        );
    }

    /// Hides the window, this is different from minimizing it.
    pub fn hide(self: *Self) void {
        _ = win32_gfx.ShowWindow(self.handle, win32_gfx.SW_HIDE);
        self.data.flags.is_visible = false;
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setResizable(self: *Self, value: bool) void {
        self.data.flags.is_resizable = value;
        self.updateStyles(&self.data.client_area);
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setDecorated(self: *Self, value: bool) void {
        self.data.flags.is_decorated = value;
        self.updateStyles(&self.data.client_area);
    }

    /// Maximize the window.
    pub fn maximize(self: *const Self) void {
        _ = win32_gfx.ShowWindow(self.handle, win32_gfx.SW_MAXIMIZE);
    }

    /// Minimizes the window.
    pub fn minimize(self: *const Self) void {
        _ = win32_gfx.ShowWindow(self.handle, win32_gfx.SW_MINIMIZE);
    }

    /// Restores the minimized or maximized window to a normal window.
    pub fn restore(self: *const Self) void {
        _ = win32_gfx.ShowWindow(self.handle, win32_gfx.SW_RESTORE);
    }

    /// Changes the title of the window.
    pub fn setTitle(
        self: *const Self,
        new_title: []const u8,
    )   error{OutOfMemory,InvalidUtf8}!void {
        const wide_title = try utils.utf8ToWideZ(self.ctx.allocator, new_title);
        defer self.ctx.allocator.free(wide_title);
        _ = win32_gfx.SetWindowTextW(self.handle, wide_title);
    }

    /// Returns the title of the window.
    pub inline fn getTitle(
        self: *const Self,
        allocator: mem.Allocator,
    ) (WindowError || mem.Allocator.Error)![]u8 {
        // This length doesn't take into account the null character
        // so add it when allocating.
        const wide_title_len = win32_gfx.GetWindowTextLengthW(self.handle);
        if (wide_title_len > 0) {
            const uwide_title_len: usize = @intCast(wide_title_len);
            const wide_slice = try allocator.allocSentinel(
                u16,
                uwide_title_len + 1,
                0,
            );
            defer allocator.free(wide_slice);
            // to get the full title we must specify the full
            // buffer length or we will be 1 character short.
            _ = win32_gfx.GetWindowTextW(
                self.handle,
                wide_slice.ptr,
                wide_title_len + 1,
            );
            const slice = utils.wideZToUtf8(allocator, wide_slice) catch {
                return mem.Allocator.Error.OutOfMemory;
            };
            return slice;
        }
        return WindowError.NoTitle;
    }

    /// Returns the window's current opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn getOpacity(self: *const Self) f32 {
        const ex_styles = win32_gfx.GetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_EXSTYLE,
        );
        if ((ex_styles & @as(isize, win32_gfx.WS_EX_LAYERED)) != 0) {
            var alpha: u8 = undefined;
            var flags: win32_gfx.LAYERED_WINDOW_ATTRIBUTES_FLAGS = undefined;
            _ = win32_gfx.GetLayeredWindowAttributes(
                self.handle,
                null,
                &alpha,
                &flags,
            );
            if ((@as(u32, @bitCast(flags)) & @as(u32, @bitCast(win32_gfx.LWA_ALPHA))) != 0) {
                const falpha: f32 = @floatFromInt(alpha);
                return (falpha / 255.0);
            }
        }
        return 1.0;
    }

    /// Sets the window's opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn setOpacity(self: *Self, value: f32) void {
        var ex_styles: usize = @bitCast(win32_gfx.GetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_EXSTYLE,
        ));

        if (value == @as(f32, 1.0)) {
            ex_styles &= ~@as(u32, win32_gfx.WS_EX_LAYERED);
        } else {
            const alpha: u32 = @intFromFloat(value * 255.0);

            if ((ex_styles & @as(u32, win32_gfx.WS_EX_LAYERED)) == 0) {
                ex_styles |= @as(u32, win32_gfx.WS_EX_LAYERED);
            }

            _ = win32_gfx.SetLayeredWindowAttributes(
                self.handle,
                0,
                @truncate(alpha),
                win32_gfx.LWA_ALPHA,
            );
        }
        _ = win32_gfx.SetWindowLongPtrW(
            self.handle,
            win32_gfx.GWL_EXSTYLE,
            @bitCast(ex_styles),
        );
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
        // shamlessly copied from GLFW library.
        self.data.aspect_ratio = ratio;
        if (ratio != null) {
            var rect: win32.RECT = undefined;
            _ = win32_gfx.GetWindowRect(self.handle, &rect);
            self.applyAspectRatio(&rect, win32_gfx.WMSZ_BOTTOMLEFT);
            _ = win32_gfx.MoveWindow(
                self.handle,
                rect.left,
                rect.top,
                rect.right - rect.left,
                rect.bottom - rect.top,
                win32.TRUE,
            );
        }
    }

    pub fn applyAspectRatio(self: *const Self, client: *win32.RECT, edge: u32) void {
        const faspect_x: f64 = @floatFromInt(self.data.aspect_ratio.?.x);
        const faspect_y: f64 = @floatFromInt(self.data.aspect_ratio.?.y);
        const ratio: f64 = faspect_x / faspect_y;

        var rect = win32.RECT{
            .left = 0,
            .top = 0,
            .right = 0,
            .bottom = 0,
        };

        adjustWindowRect(
            self.ctx.driver,
            &rect,
            windowStyles(&self.data.flags),
            windowExStyles(&self.data.flags),
            self.getScalingDPI(null),
        );

        switch (edge) {
            win32_gfx.WMSZ_LEFT,
            win32_gfx.WMSZ_RIGHT,
            win32_gfx.WMSZ_BOTTOMLEFT,
            win32_gfx.WMSZ_BOTTOMRIGHT,
            => {
                client.bottom = client.top + (rect.bottom - rect.top);
                const fborder_width: f64 = @floatFromInt((client.right - client.left) -
                    (rect.right - rect.left));
                client.bottom += @intFromFloat(fborder_width / ratio);
            },
            win32_gfx.WMSZ_TOPLEFT, win32_gfx.WMSZ_TOPRIGHT => {
                client.top = client.bottom - (rect.bottom - rect.top);
                const fborder_width: f64 = @floatFromInt((client.right - client.left) -
                    (rect.right - rect.left));
                client.top -= @intFromFloat(fborder_width / ratio);
            },
            win32_gfx.WMSZ_TOP, win32_gfx.WMSZ_BOTTOM => {
                client.right = client.left + (rect.right - rect.left);
                const fborder_height: f64 = @floatFromInt((client.bottom - client.top) -
                    (rect.bottom - rect.top));
                client.bottom += @intFromFloat(fborder_height * ratio);
            },
            else => unreachable,
        }
    }

    /// Switch the window to fullscreen mode and back;
    pub fn setFullscreen(
        self: *Self,
        value: bool,
    ) bool {
        if (self.data.flags.is_fullscreen != value) {
            const d = self.ctx.display_mgr.findWindowDisplay(self) catch {
                self.data.flags.is_fullscreen = !value;
                return false;
            };
            if (value) {
                // For non resizalble window we change
                // monitor resoultion
                if (!self.data.flags.is_resizable) {

                    const size = self.getClientSize();
                    self.ctx.display_mgr.setDisplayVideoMode(d, &.{
                        .width = size.width,
                        .height = size.height,
                        // INFO: These 2 are hardcoded for now
                        .frequency = 60,
                        .color_depth = 32,
                    }) catch return {
                        self.data.flags.is_fullscreen = !value;
                        return false;
                    };
                }
                // WARN: the fullscreen flag should be updated before updating
                // the window style or the visuals will be buggy
                // and after getting the clientSize
                self.data.flags.is_fullscreen = value;
                self.win32.prev_frame = self.data.client_area;
                self.updateStyles(&self.data.client_area);
                self.acquireDisplay(d);
                self.ctx.display_mgr.setScreenSaver(false);
            } else {
                self.data.flags.is_fullscreen = value;
                self.ctx.display_mgr.setDisplayVideoMode(d, null) catch unreachable;
                self.updateStyles(&self.win32.prev_frame);
                self.ctx.display_mgr.setScreenSaver(true);
            }
        }
        return true;
    }

    pub fn acquireDisplay(self: *Self, d: *display.Display) void {
        var area: common.geometry.Rect = undefined;

        d.getFullArea(&area);

        const POSITION_FLAGS = win32_gfx.SET_WINDOW_POS_FLAGS{
            .NOZORDER = 1,
            .NOACTIVATE = 1,
            .NOCOPYBITS = 1,
        };

        const top = if (self.data.flags.is_topmost)
            win32_gfx.HWND_TOPMOST
        else
            win32_gfx.HWND_NOTOPMOST;

        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            area.top_left.x,
            area.top_left.y,
            area.size.width,
            area.size.height,
        );
    }

    /// Returns a cached slice that contains the path(s) to the last dropped file(s).
    pub fn getDroppedFiles(self: *const Self) [][]const u8 {
        return self.win32.dropped_files.items;
    }

    pub inline fn setDragAndDrop(
        self: *Self,
        accepted: bool,
    ) void {
        if (accepted == self.win32.allow_drag_n_drop) {
            return;
        }
        self.win32.allow_drag_n_drop = accepted;
        if (accepted) {
            debug.assert(self.win32.dropped_files.items.len == 0 and self.win32.dropped_files.capacity == 0);
            shell32.DragAcceptFiles(self.handle, win32.TRUE);
        } else {
            shell32.DragAcceptFiles(self.handle, win32.FALSE);
            self.freeDroppedFiles();
        }
    }

    /// Frees the allocated memory used to hold the file(s) path(s).
    pub inline fn freeDroppedFiles(self: *Self) void {
        // Avoid double free, important since the client can call this directly.
        if (self.win32.dropped_files.capacity == 0) {
            return;
        }
        for (self.win32.dropped_files.items) |item| {
            self.ctx.allocator.free(item);
        }
        self.win32.dropped_files.clearAndFree(self.ctx.allocator);
    }

    pub fn setIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        _: anytype, // unused
    ) WindowError!void {
        const new_icon = icon.createIcon(pixels, width, height) catch |err| {
            return switch (err) {
                icon.IconError.BadIcon => WindowError.BadIcon,
                else => WindowError.OutOfMemory,
            };
        };

        const bg_handle, const sm_handle = if (new_icon.sm_handle != null and
            new_icon.bg_handle != null)
            .{
                @intFromPtr(new_icon.bg_handle.?),
                @intFromPtr(new_icon.sm_handle.?),
            }
        else blk: {
            const bg_icon = win32_gfx.GetClassLongPtrW(
                self.handle,
                win32_gfx.GCLP_HICON,
            );
            const sm_icon = win32_gfx.GetClassLongPtrW(
                self.handle,
                win32_gfx.GCLP_HICONSM,
            );
            break :blk .{ bg_icon, sm_icon };
        };
        _ = win32_gfx.SendMessageW(
            self.handle,
            win32_gfx.WM_SETICON,
            win32_gfx.ICON_BIG,
            @bitCast(bg_handle),
        );
        _ = win32_gfx.SendMessageW(
            self.handle,
            win32_gfx.WM_SETICON,
            win32_gfx.ICON_SMALL,
            @bitCast(sm_handle),
        );
        icon.destroyIcon(&self.win32.icon);
        self.win32.icon = new_icon;
    }

    pub fn setCursorIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        xhot: u32,
        yhot: u32,
    ) WindowError!void {
        const new_cursor = icon.createCursor(
            pixels,
            width,
            height,
            xhot,
            yhot,
        ) catch |err| {
            return switch (err) {
                icon.IconError.BadIcon => WindowError.BadIcon,
                else => WindowError.OutOfMemory,
            };
        };
        icon.destroyCursorIcon(&self.win32.cursor);
        self.win32.cursor = new_cursor;
        if (self.data.flags.cursor_in_client) {
            applyCursorHints(&self.win32.cursor, self.handle);
        }
    }

    pub fn setNativeCursorIcon(
        self: *Self,
        cursor_shape: common.cursor.NativeCursorShape,
    ) WindowError!void {
        const new_cursor = icon.createNativeCursor(cursor_shape) catch |err| {
            return switch (err) {
                icon.IconError.BadIcon => WindowError.BadIcon,
                else => WindowError.OutOfMemory,
            };
        };
        icon.destroyCursorIcon(&self.win32.cursor);
        self.win32.cursor = new_cursor;
        if (self.data.flags.cursor_in_client) {
            applyCursorHints(&self.win32.cursor, self.handle);
        }
    }

    pub fn setRawMouseMotion(self: *Self, active: bool) bool {
        if (self.data.flags.has_raw_mouse == active) {
            return true;
        }

        self.data.flags.has_raw_mouse = active;
        if (active) {
            return enableRawMouseMotion(self.handle);
        } else {
            return disableRawMouseMotion();
        }
    }

    pub fn getGLContext(self: *const Self) WindowError!wgl.GLContext {
        switch (self.fb_cfg.accel) {
            .opengl => return wgl.GLContext.init(self.handle, self.ctx.driver, &self.fb_cfg) catch {
                return WindowError.GLError;
            },
            else => return WindowError.GLError,
        }
    }

    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (common.IS_DEBUG_BUILD) {
            std.debug.print("0==========================0\n", .{});
            if (size) {
                std.debug.print("\nWindow #{}\n", .{self.data.id});
                const ls = self.getClientSize();
                const ps = self.getClientPixelSize();
                std.debug.print(
                    "size with dpi scaling (w:{},h:{}) | size without dpi scaling (w:{},h:{})\n",
                    .{
                        ps.width,
                        ps.height,
                        ls.width,
                        ls.height,
                    },
                );
                const ws = windowSize(self.handle);
                std.debug.print("Window Size (w:{},h:{})\n", .{ ws.width, ws.height });
                if (self.data.min_size) |*value| {
                    std.debug.print("Min Size: {}\n", .{value.*});
                } else {
                    std.debug.print("No Min Size:\n", .{});
                }
                if (self.data.max_size) |*value| {
                    std.debug.print("Max Size: {}\n", .{value.*});
                } else {
                    std.debug.print("No Max Size:\n", .{});
                }
                if (self.data.aspect_ratio) |*value| {
                    std.debug.print("Aspect Ratio: {}/{}\n", .{ value.x, value.y });
                } else {
                    std.debug.print("No Aspect Ratio:\n", .{});
                }
            }
            if (flags) {
                std.debug.print("Flags Mode: {}\n", .{self.data.flags});
            }
        }
    }
};

pub inline fn enableRawMouseMotion(window: win32.HWND) bool {
    var rid = win32_input.RAWINPUTDEVICE{
        .usUsagePage = 0x1,
        .usUsage = 0x2,
        .dwFlags = win32_input.RAWINPUTDEVICE_FLAGS{},
        .hwndTarget = window,
    };
    const ret = win32_input.RegisterRawInputDevices(@ptrCast(&rid), 1, @sizeOf(@TypeOf(rid)));
    return ret == win32.TRUE;
}

pub inline fn disableRawMouseMotion() bool {
    var rid = win32_input.RAWINPUTDEVICE{
        .usUsagePage = 0x1,
        .usUsage = 0x2,
        .dwFlags = win32_input.RIDEV_REMOVE,
        .hwndTarget = null,
    };
    const ret = win32_input.RegisterRawInputDevices(@ptrCast(&rid), 1, @sizeOf(@TypeOf(rid)));
    return ret == win32.TRUE;
}
