const std = @import("std");
const builtin = @import("builtin");
const dbg = builtin.mode == .Debug;
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const common = @import("common");
const utils = @import("utils.zig");
const icon = @import("icon.zig");
const intern = @import("internals.zig");
const monitor_impl = @import("monitor_impl.zig");
const WinGLContext = @import("wgl.zig").WinGLContext;
const window_msg = zigwin32.ui.windows_and_messaging;
const foundation = zigwin32.foundation;
const gdi = zigwin32.graphics.gdi;
const DragAcceptFiles = zigwin32.ui.shell.DragAcceptFiles;
const SetFocus = zigwin32.ui.input.keyboard_and_mouse.SetFocus;
const WindowError = @import("errors.zig").WindowError;
const Win32Context = @import("driver.zig").Win32Driver;
const Internals = intern.Internals;
const Cursor = icon.Cursor;
const Icon = icon.Icon;
const WindowData = common.window_data.WindowData;
const WindowFlags = common.window_data.WindowFlags;

// Window Styles as defined by the SDL library.
// Basic : clip child and siblings windows when drawing to content.
const STYLE_BASIC: u32 = @bitCast(window_msg.WINDOW_STYLE{
    .CLIPCHILDREN = 1,
    .CLIPSIBLINGS = 1,
});
// Fullscreen : just a popup window with monitor width and height.
const STYLE_FULLSCREEN: u32 = @bitCast(window_msg.WINDOW_STYLE{
    .POPUP = 1,
    .MINIMIZE = 1,
});
// Captionless: without a caption(title bar)
const STYLE_BORDERLESS: u32 = @bitCast(window_msg.WINDOW_STYLE{
    .POPUP = 1,
    .MINIMIZE = 1,
});
// Resizable : can be resized using the widow border can also be maximazed.
const STYLE_RESIZABLE: u32 = @bitCast(window_msg.WINDOW_STYLE{
    .THICKFRAME = 1,
    .MAXIMIZE = 1,
});
// Normal: both a title bar and minimize button.
const STYLE_NORMAL: u32 = @bitCast(window_msg.WINDOW_STYLE{
    .MINIMIZE = 1,
    .SYSMENU = 1,
    .DLGFRAME = 1,
    .BORDER = 1,
});

const STYLES_MASK: u32 = @bitCast(window_msg.WINDOW_STYLE{
    .TABSTOP = 1,
    .GROUP = 1,
    .THICKFRAME = 1,
    .SYSMENU = 1,
    .DLGFRAME = 1,
    .BORDER = 1,
    .POPUP = 1,
    .MAXIMIZE = 1,
    .CLIPSIBLINGS = 1,
    .CLIPCHILDREN = 1,
});

pub fn windowStyles(flags: *const WindowFlags) u32 {
    var styles: u32 = STYLE_BASIC;

    if (flags.is_fullscreen) {
        styles |= STYLE_FULLSCREEN;
    } else {
        if (!flags.is_decorated) {
            styles |= STYLE_BORDERLESS;
        } else {
            styles |= STYLE_NORMAL;
        }

        if (flags.is_resizable) {
            styles |= STYLE_RESIZABLE;
        }

        if (flags.is_maximized) {
            styles |= @bitCast(window_msg.WINDOW_STYLE{ .MAXIMIZE = 1 });
        }

        if (flags.is_minimized) {
            styles |= @bitCast(window_msg.WINDOW_STYLE{ .MINIMIZE = 1 });
        }
    }

    return styles;
}

pub fn windowExStyles(flags: *const WindowFlags) u32 {
    var ex_styles: u32 = 0;
    if (flags.is_fullscreen or flags.is_topmost) {
        // Should be placed above all non topmost windows.
        ex_styles |= @bitCast(window_msg.WS_EX_TOPMOST);
    }
    return ex_styles;
}

/// Performs necessary adjustement for the rect structure.
/// this function modifies the rect so that it
/// describes a window rectangle which is the smallest rectangle
/// that encloses completely both client and non client(titlebar...)
/// areas.
pub fn adjustWindowRect(
    rect: *win32.RECT,
    styles: u32,
    ex_styles: u32,
    dpi: ?u32,
) void {
    const win32_globl = Win32Context.singleton();
    if (dpi != null and win32_globl.functions.AdjustWindowRectExForDpi != null) {
        _ = win32_globl.functions.AdjustWindowRectExForDpi.?(
            rect,
            styles,
            0,
            ex_styles,
            dpi.?,
        );
    } else {
        _ = window_msg.AdjustWindowRectEx(
            rect,
            @bitCast(styles),
            0,
            @bitCast(ex_styles),
        );
    }
}

/// Converts client coordinate of a RECT structure to screen coordinate.
fn clientToScreen(window_handle: win32.HWND, rect: *win32.RECT) void {
    var upper_left = foundation.POINT{
        .x = rect.left,
        .y = rect.top,
    };
    var lower_right = foundation.POINT{
        .x = rect.right,
        .y = rect.bottom,
    };

    _ = gdi.ClientToScreen(window_handle, &upper_left);
    _ = gdi.ClientToScreen(window_handle, &lower_right);

    rect.* = win32.RECT{
        .left = upper_left.x,
        .top = upper_left.y,
        .right = lower_right.x,
        .bottom = lower_right.y,
    };
}

/// Returns the (width,height) of the entire window frame.
pub fn windowSize(window_handle: win32.HWND) common.geometry.WidowSize {
    var rect: win32.RECT = undefined;
    _ = window_msg.GetWindowRect(window_handle, &rect);
    const size = common.geometry.WidowSize{
        .width = rect.right - rect.left,
        .height = rect.bottom - rect.top,
    };
    return size;
}

/// Updates the cursor image.
pub fn updateCursorImage(cursor: *const icon.Cursor) void {
    if (cursor.mode.is_disabled()) {
        return;
    }

    if (cursor.handle) |value| {
        _ = window_msg.SetCursor(value);
    } else {
        _ = window_msg.SetCursor(
            window_msg.LoadCursorW(null, window_msg.IDC_ARROW),
        );
    }
}

/// Limits the cursor motion to the client rectangle.
pub inline fn captureCursor(window_handle: win32.HWND) void {
    var clip_rect: win32.RECT = undefined;
    _ = window_msg.GetClientRect(window_handle, &clip_rect);
    // ClipCursor expects screen coordinates.
    clientToScreen(window_handle, &clip_rect);
    _ = window_msg.ClipCursor(&clip_rect);
}

/// Removes cursor motion limitation.
pub inline fn releaseCursor() void {
    _ = window_msg.ClipCursor(null);
}

/// Captures and hide the cursor from the user.
pub fn disableCursor(window_handle: win32.HWND) void {
    captureCursor(window_handle);
    _ = window_msg.SetCursor(null);
}

/// Shows and release the cursor.
pub fn enableCursor(cursor: *const icon.Cursor) void {
    updateCursorImage(cursor);
    releaseCursor();
}

/// helper function for changing the window position,size and styles.
fn setWindowPositionIntern(
    window_handle: win32.HWND,
    top: ?win32.HWND,
    flags: u32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
) void {
    _ = window_msg.SetWindowPos(
        window_handle,
        top,
        x,
        y,
        width,
        height,
        @enumFromInt(flags),
    );
}

fn createPlatformWindow(
    allocator: std.mem.Allocator,
    title: []const u8,
    data: *const WindowData,
    styles: struct { u32, u32 },
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
    adjustWindowRect(&window_rect, styles[0], styles[1], null);

    // Decide the position(top left) of the client area
    var frame_x: i32 = undefined;
    var frame_y: i32 = undefined;
    if (data.client_area.top_left.x != window_msg.CW_USEDEFAULT and
        data.client_area.top_left.y != window_msg.CW_USEDEFAULT)
    {
        frame_x = data.client_area.top_left.x + window_rect.left;
        frame_y = data.client_area.top_left.y + window_rect.top;
    } else {
        frame_x = window_msg.CW_USEDEFAULT;
        frame_y = window_msg.CW_USEDEFAULT;
    }

    // Final window frame.
    const frame = .{
        frame_x,
        frame_y,
        window_rect.right - window_rect.left,
        window_rect.bottom - window_rect.top,
    };

    // Encode the title string in utf-16.
    const window_title = try utils.utf8ToWideZ(allocator, title);
    defer allocator.free(window_title);

    const creation_lparm = data;
    const win32_globl = Win32Context.singleton();

    // Create the window.
    const window_handle = win32.CreateWindowExW(
        styles[1], // dwExStyles
        utils.MAKEINTATOM(win32_globl.handles.wnd_class),
        window_title, // Window Name
        styles[0], // dwStyles
        frame[0], // X
        frame[1], // Y
        frame[2], // width
        frame[3], // height
        null, // Parent Hwnd
        null, // hMenu
        win32_globl.handles.hinstance, // hInstance
        @ptrCast(@constCast(creation_lparm)), // CREATESTRUCT lparam
    ) orelse {
        return WindowError.FailedToCreate;
    };

    return window_handle;
}

/// Holds all the refrences we use to communitcate with the WidowContext.
pub const WidowProps = struct {
    internals: *Internals,
    events_queue: *common.event.EventQueue,
};

/// Win32 specific data.
pub const WindowWin32Data = struct {
    icon: Icon,
    cursor: Cursor,
    restore_frame: ?common.geometry.WidowArea, // Used when going fullscreen to save restore coords.
    dropped_files: std.ArrayList([]const u8),
    high_surrogate: u16,
    frame_action: bool,
    position_update: bool,
};

pub const WindowImpl = struct {
    data: WindowData,
    widow: WidowProps,
    win32: WindowWin32Data,
    handle: foundation.HWND,
    pub const WINDOW_DEFAULT_POSITION = common.geometry.WidowPoint2D{
        .x = window_msg.CW_USEDEFAULT,
        .y = window_msg.CW_USEDEFAULT,
    };
    const Self = @This();

    pub fn create(
        allocator: std.mem.Allocator,
        window_title: []const u8,
        data: *WindowData,
        events_queue: *common.event.EventQueue,
        internals: *Internals,
    ) !*Self {
        var self = try allocator.create(Self);
        errdefer allocator.destroy(self);
        self.widow = WidowProps{
            .events_queue = events_queue,
            .internals = internals,
        };
        self.data = data.*;
        const styles = .{ windowStyles(&data.flags), windowExStyles(&data.flags) };
        self.handle = try createPlatformWindow(allocator, window_title, data, styles);

        // Finish setting up the window.
        self.win32 = WindowWin32Data{
            .cursor = Cursor{
                .handle = null,
                .mode = common.cursor.CursorMode.Normal,
                .shared = false,
            },
            .icon = Icon{
                .sm_handle = null,
                .bg_handle = null,
            },
            .high_surrogate = 0,
            .frame_action = false,
            .position_update = false,
            .dropped_files = std.ArrayList([]const u8).init(allocator),
            .restore_frame = null,
        };

        // Process inital events.
        // these events aren't reported.
        self.processEvents();

        _ = window_msg.SetWindowLongPtrW(
            self.handle,
            window_msg.GWLP_USERDATA,
            @intCast(@intFromPtr(self)),
        );

        // Now we can handle DPI adjustments.
        if (self.data.flags.is_dpi_aware) {
            var client_rect = win32.RECT{
                .left = 0,
                .top = 0,
                .right = self.data.client_area.size.width,
                .bottom = self.data.client_area.size.height,
            };
            var dpi_scale: f64 = undefined;
            const dpi = self.scalingDPI(&dpi_scale);
            // the requested client width and height are scaled by the display scale factor.
            const fwidth: f64 = @floatFromInt(client_rect.right);
            const fheight: f64 = @floatFromInt(client_rect.bottom);
            client_rect.right = @intFromFloat(fwidth * dpi_scale);
            client_rect.bottom = @intFromFloat(fheight * dpi_scale);

            adjustWindowRect(
                &client_rect,
                styles[0],
                styles[1],
                dpi,
            );

            var window_rect: win32.RECT = undefined;
            // [MSDN]:If the window has not been shown before,
            // GetWindowRect will not include the area of the drop shadow.
            _ = window_msg.GetWindowRect(self.handle, &window_rect);
            // Offset and readjust the created window's frame.
            _ = gdi.OffsetRect(
                &client_rect,
                window_rect.left - client_rect.left,
                window_rect.top - client_rect.top,
            );

            const top = if (self.data.flags.is_topmost)
                window_msg.HWND_TOPMOST
            else
                window_msg.HWND_NOTOPMOST;
            const POSITION_FLAGS: u32 = comptime @intFromEnum(window_msg.SWP_NOZORDER) |
                @intFromEnum(window_msg.SWP_NOACTIVATE) |
                @intFromEnum(window_msg.SWP_NOOWNERZORDER);
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
        if (Win32Context.singleton().flags.is_win7_or_above) {
            // Sent when the user drops a file on the window [Windows XP minimum]
            _ = window_msg.ChangeWindowMessageFilterEx(
                self.handle,
                window_msg.WM_DROPFILES,
                window_msg.MSGFLT_ALLOW,
                null,
            );
            _ = window_msg.ChangeWindowMessageFilterEx(
                self.handle,
                window_msg.WM_COPYDATA,
                window_msg.MSGFLT_ALLOW,
                null,
            );
            _ = window_msg.ChangeWindowMessageFilterEx(
                self.handle,
                win32.WM_COPYGLOBALDATA,
                window_msg.MSGFLT_ALLOW,
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
            try self.setFullscreen(true, null);
        }

        return self;
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        // Clean up code
        if (self.data.flags.is_fullscreen) {
            // release the currently occupied monitor
            self.setFullscreen(false, null) catch unreachable;
        }
        if (self.win32.cursor.mode.is_captured()) {
            releaseCursor();
        }
        if (self.win32.cursor.mode.is_disabled()) {
            enableCursor(&self.win32.cursor);
        }
        _ = window_msg.SetWindowLongPtrW(self.handle, window_msg.GWLP_USERDATA, 0);
        _ = window_msg.DestroyWindow(self.handle);
        self.freeDroppedFiles();
        self.deinitDrawingContext();
        allocator.destroy(self);
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        // Show without activating.
        _ = window_msg.ShowWindow(self.handle, window_msg.SW_SHOWNA);
        self.data.flags.is_visible = true;
    }

    pub fn focus(self: *Self) void {
        _ = window_msg.BringWindowToTop(self.handle);
        _ = window_msg.SetForegroundWindow(self.handle);
        _ = SetFocus(self.handle);
    }

    pub fn scalingDPI(self: *const Self, scaler: ?*f64) u32 {
        const win32_globl = Win32Context.singleton();
        var dpi: u32 = win32.USER_DEFAULT_SCREEN_DPI;
        err_exit: {
            if (win32_globl.functions.GetDpiForWindow) |proc| {
                dpi = proc(self.handle);
            } else {
                // let's query the monitor's dpi.
                const monitor_handle = gdi.MonitorFromWindow(self.handle, gdi.MONITOR_DEFAULTTONEAREST) orelse break :err_exit;
                dpi = monitor_impl.monitorDPI(monitor_handle);
            }
        }
        if (scaler) |ptr| {
            const fdpi: f64 = @floatFromInt(dpi);
            ptr.* = (fdpi / win32.USER_DEFAULT_SCREEN_DPI_F);
        }
        return dpi;
    }

    /// the window should belong to the thread calling this function.
    pub fn processEvents(self: *Self) void {
        var msg: window_msg.MSG = undefined;
        while (window_msg.PeekMessageW(&msg, self.handle, 0, 0, window_msg.PM_REMOVE) != 0) {
            _ = window_msg.TranslateMessage(&msg);
            _ = window_msg.DispatchMessageW(&msg);
        }
        // Emit key up for released modifers keys.
        utils.clearStickyKeys(self);
    }

    /// Add an event to the events queue.
    pub fn sendEvent(self: *Self, event: *const common.event.Event) void {
        self.widow.events_queue.queueEvent(event);
    }

    /// the window should belong to the thread calling this function.
    pub fn waitEvent(self: *Self) void {
        _ = window_msg.WaitMessage();
        self.processEvents();
    }

    /// the window should belong to the thread calling this function.
    /// Waits for an input event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) bool {
        if (window_msg.MsgWaitForMultipleObjects(
            0,
            null,
            0,
            timeout,
            window_msg.QS_ALLINPUT,
        ) == win32.WAIT_TIMEOUT) {
            // Timeout period elapsed.
            return false;
        }
        self.processEvents();
        return true;
    }

    /// Updates the registered window styles to match the current window config.
    fn updateStyles(self: *Self) void {
        const EX_STYLES_MASK: u32 = @intFromEnum(window_msg.WS_EX_TOPMOST);
        const POSITION_FLAGS: u32 = comptime @intFromEnum(window_msg.SWP_FRAMECHANGED) |
            @intFromEnum(window_msg.SWP_NOACTIVATE) |
            @intFromEnum(window_msg.SWP_NOZORDER);

        var reg_styles: usize = @bitCast(window_msg.GetWindowLongPtrW(
            self.handle,
            window_msg.GWL_STYLE,
        ));
        var reg_ex_styles: usize = @bitCast(window_msg.GetWindowLongPtrW(
            self.handle,
            window_msg.GWL_EXSTYLE,
        ));
        reg_styles &= ~STYLES_MASK;
        reg_ex_styles &= ~EX_STYLES_MASK;
        reg_styles |= windowStyles(&self.data.flags);
        reg_ex_styles |= windowExStyles(&self.data.flags);

        _ = window_msg.SetWindowLongPtrW(
            self.handle,
            window_msg.GWL_STYLE,
            @bitCast(reg_styles),
        );

        _ = window_msg.SetWindowLongPtrW(
            self.handle,
            window_msg.GWL_EXSTYLE,
            @bitCast(reg_ex_styles),
        );

        var rect: win32.RECT = undefined;

        if (self.win32.restore_frame) |*frame| {
            // we're exiting fullscreen mode use the saved size.
            rect.left = frame.top_left.x;
            rect.top = frame.top_left.y;
            rect.right = frame.size.width + frame.top_left.x;
            rect.bottom = frame.size.height + frame.top_left.y;
        } else {
            // we're simply changing some styles.
            rect.left = self.data.client_area.top_left.x;
            rect.top = self.data.client_area.top_left.y;
            rect.right = self.data.client_area.size.width + rect.left;
            rect.bottom = self.data.client_area.size.height + rect.top;
        }

        var dpi: ?u32 = null;

        if (self.data.flags.is_dpi_aware) {
            dpi = self.scalingDPI(null);
        }

        adjustWindowRect(
            &rect,
            @truncate(reg_styles),
            @truncate(reg_ex_styles),
            dpi,
        );

        const top = if (self.data.flags.is_topmost)
            window_msg.HWND_TOPMOST
        else
            window_msg.HWND_NOTOPMOST;

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

    pub fn cursorPositon(self: *const Self) common.geometry.WidowPoint2D {
        var cursor_pos: foundation.POINT = undefined;
        _ = window_msg.GetCursorPos(&cursor_pos);
        _ = gdi.ScreenToClient(self.handle, &cursor_pos);
        // the cursor_pos is relative to the upper left corner of the window.
        return common.geometry.WidowPoint2D{ .x = cursor_pos.x, .y = cursor_pos.y };
    }

    pub fn setCursorPosition(self: *const Self, x: i32, y: i32) void {
        var point = foundation.POINT{
            .x = x,
            .y = y,
        };
        _ = gdi.ClientToScreen(self.handle, &point);
        _ = window_msg.SetCursorPos(point.x, point.y);
    }

    pub fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
        if (self.win32.cursor.mode == mode) {
            return;
        }
        self.win32.cursor.mode = mode;
        enableCursor(&self.win32.cursor);
        switch (mode) {
            common.cursor.CursorMode.Captured => captureCursor(self.handle),
            common.cursor.CursorMode.Disabled => disableCursor(self.handle),
            else => {},
        }
    }

    /// Notify and flash the taskbar.
    pub fn flash(self: *const Self) void {
        var flash_info = window_msg.FLASHWINFO{
            .cbSize = @sizeOf(window_msg.FLASHWINFO),
            .hwnd = self.handle,
            .dwFlags = window_msg.FLASHW_ALL,
            .uCount = 3,
            .dwTimeout = 0,
        };
        _ = window_msg.FlashWindowEx(&flash_info);
    }

    /// Returns the position of the top left corner of the client area.
    pub fn clientPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.data.client_area.top_left;
    }

    /// Moves the client's top left corner
    /// to the specified screen coordinates.
    pub fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        // Don't use SWP_NOSIZE to allow dpi change.
        const POSITION_FLAGS: u32 = comptime @intFromEnum(window_msg.SWP_NOZORDER) |
            @intFromEnum(window_msg.SWP_NOACTIVATE) |
            @intFromEnum(window_msg.SWP_NOREPOSITION);

        if (self.data.flags.is_maximized) {
            // Moving a maximized window should restore it to it's orignal size
            self.restore();
        }

        var rect: win32.RECT = win32.RECT{
            .left = 0,
            .top = 0,
            .right = self.data.client_area.size.width,
            .bottom = self.data.client_area.size.height,
        };

        var dpi: ?u32 = null;

        if (self.data.flags.is_dpi_aware) {
            dpi = self.scalingDPI(null);
        }

        adjustWindowRect(
            &rect,
            windowStyles(&self.data.flags),
            windowExStyles(&self.data.flags),
            dpi,
        );

        rect.left += x;
        rect.top += y;

        const top = if (self.data.flags.is_topmost)
            window_msg.HWND_TOPMOST
        else
            window_msg.HWND_NOTOPMOST;

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

    /// Returns the Physical size of the window's client area
    pub fn clientPixelSize(self: *const Self) common.geometry.WidowSize {
        return common.geometry.WidowSize{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
    }

    /// Returns the logical size of the window's client area
    pub fn clientSize(self: *const Self) common.geometry.WidowSize {
        var client_size = common.geometry.WidowSize{
            .width = self.data.client_area.size.width,
            .height = self.data.client_area.size.height,
        };
        if (self.data.flags.is_dpi_aware and !self.data.flags.is_fullscreen) {
            const dpi: f64 = @floatFromInt(self.scalingDPI(null));
            const r_scaler = (win32.USER_DEFAULT_SCREEN_DPI_F / dpi);
            client_size.scaleBy(r_scaler);
        }
        return client_size;
    }

    /// Sets the new (width,height) of the window's client area
    pub fn setClientSize(self: *Self, size: *common.geometry.WidowSize) void {
        if (!self.data.flags.is_fullscreen) {
            var dpi: ?u32 = null;
            if (self.data.flags.is_dpi_aware) {
                var scaler: f64 = undefined;
                dpi = self.scalingDPI(&scaler);
                size.scaleBy(scaler);
            }

            var new_client_rect = foundation.RECT{
                .left = 0,
                .top = 0,
                .right = size.width,
                .bottom = size.height,
            };

            adjustWindowRect(
                &new_client_rect,
                windowStyles(&self.data.flags),
                windowExStyles(&self.data.flags),
                dpi,
            );
            if (self.data.flags.is_maximized) {
                // un-maximize the window
                self.restore();
            }

            const POSITION_FLAGS: u32 = comptime @intFromEnum(window_msg.SWP_NOACTIVATE) |
                @intFromEnum(window_msg.SWP_NOREPOSITION) |
                @intFromEnum(window_msg.SWP_NOZORDER) |
                @intFromEnum(window_msg.SWP_NOMOVE);

            const top = if (self.data.flags.is_topmost)
                window_msg.HWND_TOPMOST
            else
                window_msg.HWND_NOTOPMOST;

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

    pub fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
        if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
            // No need to do anything.
            return;
        }

        if (min_size != null) {
            var size = min_size.?;
            // min size shouldn't be negative.
            std.debug.assert(size.width > 0);
            std.debug.assert(size.height > 0);

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
                _ = self.scalingDPI(&scaler);
                size.scaleBy(scaler);
            }

            self.data.min_size = size;
        } else {
            self.data.min_size = null;
        }

        const POSITION_FLAGS: u32 = comptime @intFromEnum(window_msg.SWP_NOACTIVATE) |
            @intFromEnum(window_msg.SWP_NOREPOSITION) |
            @intFromEnum(window_msg.SWP_NOZORDER) |
            @intFromEnum(window_msg.SWP_NOMOVE);

        const size = windowSize(self.handle);

        const top = if (self.data.flags.is_topmost)
            window_msg.HWND_TOPMOST
        else
            window_msg.HWND_NOTOPMOST;
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

    pub fn setMaxSize(self: *Self, max_size: ?common.geometry.WidowSize) void {
        if (self.data.flags.is_fullscreen or !self.data.flags.is_resizable) {
            // No need to do anything.
            return;
        }

        if (max_size != null) {
            var size = max_size.?;
            // max size shouldn't be negative.
            std.debug.assert(size.width > 0);
            std.debug.assert(size.height > 0);
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
                _ = self.scalingDPI(&scaler);
                size.scaleBy(scaler);
            }
            self.data.max_size = size;
        } else {
            self.data.max_size = null;
        }

        const POSITION_FLAGS: u32 = comptime @intFromEnum(window_msg.SWP_NOACTIVATE) |
            @intFromEnum(window_msg.SWP_NOREPOSITION) |
            @intFromEnum(window_msg.SWP_NOZORDER) |
            @intFromEnum(window_msg.SWP_NOMOVE);

        const size = windowSize(self.handle);

        const top = if (self.data.flags.is_topmost)
            window_msg.HWND_TOPMOST
        else
            window_msg.HWND_NOTOPMOST;
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
        _ = window_msg.ShowWindow(self.handle, window_msg.SW_HIDE);
        self.data.flags.is_visible = false;
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setResizable(self: *Self, value: bool) void {
        self.data.flags.is_resizable = value;
        self.updateStyles();
    }

    /// Toggles window resizablitity on(true) or off(false).
    pub fn setDecorated(self: *Self, value: bool) void {
        self.data.flags.is_decorated = value;
        self.updateStyles();
    }

    /// Maximize the window.
    pub fn maximize(self: *const Self) void {
        _ = window_msg.ShowWindow(self.handle, window_msg.SW_MAXIMIZE);
    }

    /// Minimizes the window.
    pub fn minimize(self: *const Self) void {
        _ = window_msg.ShowWindow(self.handle, window_msg.SW_MINIMIZE);
    }

    /// Restores the minimized or maximized window to a normal window.
    pub fn restore(self: *const Self) void {
        _ = window_msg.ShowWindow(self.handle, window_msg.SW_RESTORE);
    }

    /// Changes the title of the window.
    pub fn setTitle(self: *Self, allocator: std.mem.Allocator, new_title: []const u8) !void {
        const wide_title = try utils.utf8ToWideZ(allocator, new_title);
        defer allocator.free(wide_title);
        _ = window_msg.SetWindowTextW(self.handle, wide_title);
    }

    /// Returns the title of the window.
    pub inline fn title(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        // This length doesn't take into account the null character so add it when allocating.
        const wide_title_len = window_msg.GetWindowTextLengthW(self.handle);
        if (wide_title_len > 0) {
            const uwide_title_len: usize = @intCast(wide_title_len);
            const wide_slice = try allocator.allocSentinel(u16, uwide_title_len + 1, 0);
            defer allocator.free(wide_slice);
            // to get the full title we must specify the full buffer length or we will be 1 character short.
            _ = window_msg.GetWindowTextW(self.handle, wide_slice.ptr, wide_title_len + 1);
            const slice = try utils.wideZToUtf8(allocator, wide_slice);
            return slice;
        }
        return WindowError.FailedToCopyTitle;
    }

    /// Returns the window's current opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn opacity(self: *const Self) f32 {
        const ex_styles = window_msg.GetWindowLongPtrW(self.handle, window_msg.GWL_EXSTYLE);
        if ((ex_styles & @intFromEnum(window_msg.WS_EX_LAYERED)) != 0) {
            var alpha: u8 = undefined;
            var flags: window_msg.LAYERED_WINDOW_ATTRIBUTES_FLAGS = undefined;
            _ = window_msg.GetLayeredWindowAttributes(self.handle, null, &alpha, &flags);
            if ((@intFromEnum(flags) & @intFromEnum(window_msg.LWA_ALPHA)) != 0) {
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
        var ex_styles: usize = @bitCast(window_msg.GetWindowLongPtrW(
            self.handle,
            window_msg.GWL_EXSTYLE,
        ));

        if (value == @as(f32, 1.0)) {
            ex_styles &= ~@intFromEnum(window_msg.WS_EX_LAYERED);
        } else {
            const alpha: u32 = @intFromFloat(value * 255.0);

            if ((ex_styles & @intFromEnum(window_msg.WS_EX_LAYERED)) == 0) {
                ex_styles |= @intFromEnum(window_msg.WS_EX_LAYERED);
            }

            _ = window_msg.SetLayeredWindowAttributes(
                self.handle,
                0,
                @truncate(alpha),
                window_msg.LWA_ALPHA,
            );
        }
        _ = window_msg.SetWindowLongPtrW(
            self.handle,
            window_msg.GWL_EXSTYLE,
            @bitCast(ex_styles),
        );
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
        // shamlessly copied from GLFW library.
        self.data.aspect_ratio = ratio;
        if (ratio != null) {
            var rect: win32.RECT = undefined;
            _ = window_msg.GetWindowRect(self.handle, &rect);
            self.applyAspectRatio(&rect, window_msg.WMSZ_BOTTOMLEFT);
            _ = window_msg.MoveWindow(
                self.handle,
                rect.left,
                rect.top,
                rect.right - rect.left,
                rect.bottom - rect.top,
                win32.TRUE,
            );
        }
    }

    pub fn applyAspectRatio(self: *const Self, client: *foundation.RECT, edge: u32) void {
        const faspect_x: f64 = @floatFromInt(self.data.aspect_ratio.?.x);
        const faspect_y: f64 = @floatFromInt(self.data.aspect_ratio.?.y);
        const ratio: f64 = faspect_x / faspect_y;

        var rect = foundation.RECT{
            .left = 0,
            .top = 0,
            .right = 0,
            .bottom = 0,
        };

        adjustWindowRect(
            &rect,
            windowStyles(&self.data.flags),
            windowExStyles(&self.data.flags),
            self.scalingDPI(null),
        );

        switch (edge) {
            window_msg.WMSZ_LEFT, window_msg.WMSZ_RIGHT, window_msg.WMSZ_BOTTOMLEFT, window_msg.WMSZ_BOTTOMRIGHT => {
                client.bottom = client.top + (rect.bottom - rect.top);
                const fborder_width: f64 = @floatFromInt((client.right - client.left) - (rect.right - rect.left));
                client.bottom += @intFromFloat(fborder_width / ratio);
            },
            window_msg.WMSZ_TOPLEFT, window_msg.WMSZ_TOPRIGHT => {
                client.top = client.bottom - (rect.bottom - rect.top);
                const fborder_width: f64 = @floatFromInt((client.right - client.left) - (rect.right - rect.left));
                client.top -= @intFromFloat(fborder_width / ratio);
            },
            window_msg.WMSZ_TOP, window_msg.WMSZ_BOTTOM => {
                client.right = client.left + (rect.right - rect.left);
                const fborder_height: f64 = @floatFromInt((client.bottom - client.top) - (rect.bottom - rect.top));
                client.bottom += @intFromFloat(fborder_height * ratio);
            },
            else => unreachable,
        }
    }

    /// Switch the window to fullscreen mode and back;
    pub fn setFullscreen(self: *Self, value: bool, video_mode: ?*common.video_mode.VideoMode) !void {

        // The video mode switch should always be done first
        const monitor_handle = self.occupiedMonitor();
        try self.widow.internals.monitor_store.setMonitorVideoMode(monitor_handle, video_mode);

        if (self.data.flags.is_fullscreen != value) {
            if (value) {
                // save for when we exit the fullscreen mode
                self.win32.restore_frame = self.data.client_area;

                self.data.flags.is_fullscreen = true;
                self.updateStyles();
                try self.acquireMonitor(monitor_handle);
            } else {
                try self.releaseMonitor(monitor_handle);
                self.requestRestore();
            }
        }
    }

    pub fn requestRestore(self: *Self) void {
        self.data.flags.is_fullscreen = false;
        self.updateStyles();
        self.win32.restore_frame = null;
    }

    pub fn acquireMonitor(self: *Self, monitor_handle: win32.HMONITOR) !void {
        var mon_area: common.geometry.WidowArea = undefined;

        try self.widow.internals.monitor_store.setMonitorWindow(
            monitor_handle,
            self,
            &mon_area,
        );

        const POSITION_FLAGS: u32 = @intFromEnum(window_msg.SWP_NOZORDER) |
            @intFromEnum(window_msg.SWP_NOACTIVATE) |
            @intFromEnum(window_msg.SWP_NOCOPYBITS);

        const top = if (self.data.flags.is_topmost)
            window_msg.HWND_TOPMOST
        else
            window_msg.HWND_NOTOPMOST;

        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            mon_area.top_left.x,
            mon_area.top_left.y,
            mon_area.size.width,
            mon_area.size.height,
        );
    }

    /// Marks the monitor as not being occupied by any window.
    pub fn releaseMonitor(self: *const Self, monitor_handle: win32.HMONITOR) !void {
        try self.widow.internals.monitor_store.releaseMonitor(monitor_handle);
    }

    pub inline fn occupiedMonitor(self: *const Self) win32.HMONITOR {
        return gdi.MonitorFromWindow(self.handle, gdi.MONITOR_DEFAULTTONEAREST).?;
    }

    /// Returns a cached slice that contains the path(s) to the last dropped file(s).
    pub fn droppedFiles(self: *const Self) [][]const u8 {
        return self.win32.dropped_files.items;
    }

    pub inline fn setDragAndDrop(self: *Self, accepted: bool) void {
        const accept = if (accepted)
            win32.TRUE
        else blk: {
            self.freeDroppedFiles();
            break :blk win32.FALSE;
        };
        DragAcceptFiles(self.handle, accept);
    }

    /// Frees the allocated memory used to hold the file(s) path(s).
    pub fn freeDroppedFiles(self: *Self) void {
        // Avoid double free.
        if (self.win32.dropped_files.capacity == 0) {
            return;
        }
        const allocator = self.win32.dropped_files.allocator;
        for (self.win32.dropped_files.items) |item| {
            allocator.free(item);
        }
        self.win32.dropped_files.clearAndFree();
    }

    pub fn setIcon(self: *Self, pixels: ?[]const u8, width: i32, height: i32) !void {
        const new_icon = try intern.createIcon(pixels, width, height);
        const handles = if (new_icon.sm_handle != null and new_icon.bg_handle != null)
            .{ @intFromPtr(new_icon.bg_handle.?), @intFromPtr(new_icon.sm_handle.?) }
        else blk: {
            const bg_icon = window_msg.GetClassLongPtrW(self.handle, window_msg.GCLP_HICON);
            const sm_icon = window_msg.GetClassLongPtrW(self.handle, window_msg.GCLP_HICONSM);
            break :blk .{ bg_icon, sm_icon };
        };
        _ = window_msg.SendMessageW(
            self.handle,
            window_msg.WM_SETICON,
            window_msg.ICON_BIG,
            @bitCast(handles[0]),
        );
        _ = window_msg.SendMessageW(
            self.handle,
            window_msg.WM_SETICON,
            window_msg.ICON_SMALL,
            @bitCast(handles[1]),
        );
        icon.destroyIcon(&self.win32.icon);
        self.win32.icon = new_icon;
    }

    pub fn setCursor(self: *Self, pixels: ?[]const u8, width: i32, height: i32, xhot: u32, yhot: u32) !void {
        const new_cursor = try intern.createCursor(pixels, width, height, xhot, yhot);
        icon.destroyCursor(&self.win32.cursor);
        self.win32.cursor = new_cursor;
        if (self.data.flags.cursor_in_client) {
            updateCursorImage(&self.win32.cursor);
        }
    }

    pub fn setStandardCursor(self: *Self, cursor_shape: common.cursor.StandardCursorShape) !void {
        const new_cursor = try intern.createStandardCursor(cursor_shape);
        icon.destroyCursor(&self.win32.cursor);
        self.win32.cursor = new_cursor;
        if (self.data.flags.cursor_in_client) {
            updateCursorImage(&self.win32.cursor);
        }
    }

    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (dbg) {
            std.debug.print("0==========================0\n", .{});
            if (size) {
                std.debug.print("\nWindow #{}\n", .{self.data.id});
                const cs = self.clientSize();
                std.debug.print(
                    "physical client Size (w:{},h:{}) | logical client size (w:{},h:{})\n",
                    .{
                        self.data.client_area.size.width,
                        self.data.client_area.size.height,
                        cs.width,
                        cs.height,
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
