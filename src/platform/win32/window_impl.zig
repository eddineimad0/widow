const std = @import("std");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const common = @import("common");
const utils = @import("utils.zig");
const monitor_impl = @import("monitor_impl.zig");
const icon = @import("icon.zig");
const WindowError = @import("errors.zig").WindowError;
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const win32_foundation = zigwin32.foundation;
const win32_gdi = zigwin32.graphics.gdi;
const DragAcceptFiles = zigwin32.ui.shell.DragAcceptFiles;
const SetFocus = zigwin32.ui.input.keyboard_and_mouse.SetFocus;
const WidowContext = @import("widow").WidowContext;
const Win32Context = @import("globals.zig").Win32Context;
const MonitorStore = @import("internals.zig").MonitorStore;
const Cursor = icon.Cursor;
const Icon = icon.Icon;
const WindowData = common.window_data.WindowData;
const FullScreenMode = common.window_data.FullScreenMode;

// Window Styles as defined by the SDL library.
// Basic : clip child and siblings windows when drawing to content.
const STYLE_BASIC: u32 = @enumToInt(win32_window_messaging.WS_CLIPCHILDREN) | @enumToInt(win32_window_messaging.WS_CLIPSIBLINGS);
// Fullscreen : just a popup window with monitor width and height.
const STYLE_FULLSCREEN: u32 = @enumToInt(win32_window_messaging.WS_POPUP);
const STYLE_BORDERLESS: u32 = @enumToInt(win32_window_messaging.WS_POPUP) | @enumToInt(win32_window_messaging.WS_MINIMIZEBOX);
// Resizable : can be resized using the widow border can also be maximazed.
const STYLE_RESIZABLE: u32 = @enumToInt(win32_window_messaging.WS_THICKFRAME) | @enumToInt(win32_window_messaging.WS_MAXIMIZEBOX);
// Normal: both a title bar and minimize button.
const STYLE_NORMAL: u32 = @enumToInt(win32_window_messaging.WS_OVERLAPPED) |
    @enumToInt(win32_window_messaging.WS_MINIMIZEBOX) |
    @enumToInt(win32_window_messaging.WS_SYSMENU) |
    @enumToInt(win32_window_messaging.WS_CAPTION);

pub fn windowStyles(data: *const WindowData) u32 {
    // Styles.
    var styles: u32 = 0;

    if (data.fullscreen_mode) |_| {
        styles |= STYLE_FULLSCREEN;
    } else {
        if (!data.flags.is_decorated) {
            styles |= STYLE_BORDERLESS;
        } else {
            styles |= STYLE_NORMAL;
        }

        if (data.flags.is_resizable) {
            styles |= STYLE_RESIZABLE;
        }

        if (data.flags.is_maximized) {
            styles |= @enumToInt(win32_window_messaging.WS_MAXIMIZE);
        }

        if (data.flags.is_minimized) {
            styles |= @enumToInt(win32_window_messaging.WS_MINIMIZE);
        }

        styles |= STYLE_BASIC;
    }

    return styles;
}

pub fn windowExStyles(data: *const WindowData) u32 {
    // Extended Styles.
    var ex_styles = @enumToInt(win32_window_messaging.WS_EX_WINDOWEDGE) | @enumToInt(win32_window_messaging.WS_EX_APPWINDOW);
    if (data.fullscreen_mode != null or data.flags.is_topmost) {
        // Should be placed above all non topmost windows.
        ex_styles |= @enumToInt(win32_window_messaging.WS_EX_TOPMOST);
    }
    return ex_styles;
}

/// Performs necessary adjustement for the rect structure.
/// this function modifies the rect so that it
/// describes a window rect which is the smallest rectangle
/// that encloses completely both client and non client(titlebar...)
/// areas
pub fn adjustWindowRect(
    rect: *win32.RECT,
    styles: u32,
    ex_styles: u32,
    dpi: u32,
) void {
    const win32_globl = Win32Context.singleton().?;
    if (win32_globl.functions.AdjustWindowRectExForDpi) |proc| {
        _ = proc(
            rect,
            styles,
            0,
            ex_styles,
            dpi,
        );
    } else {
        _ = win32_window_messaging.AdjustWindowRectEx(rect, @intToEnum(win32_window_messaging.WINDOW_STYLE, styles), 0, @intToEnum(win32_window_messaging.WINDOW_EX_STYLE, ex_styles));
    }
}

///# Note
/// If the doesn't have the WS_EX_TOOLWINDOW style then the coordinates
/// of the WINDOWPLACEMENT fields will be in workspace coordinates and not screen coordinates
fn windowPlacement(handle: win32.HWND, wp: *win32_window_messaging.WINDOWPLACEMENT) void {
    wp.length = @sizeOf(win32_window_messaging.WINDOWPLACEMENT);
    _ = win32_window_messaging.GetWindowPlacement(handle, wp);
}

/// Returns the client area's rectangle that specify it's coordinates.
/// # Note
/// the coordinate for the upperleft corner returned by this function
/// are always (0,0), and do not reflect it's actual position on the screen
/// pass the returned rect to client_to_screen function to get the true upperleft
/// coordinates.
inline fn clientRect(window_handle: win32.HWND, rect: *win32.RECT) void {
    _ = win32_window_messaging.GetClientRect(window_handle, rect);
}

/// Converts client coordinate of a RECT structure to screen coordinate.
fn clientToScreen(window_handle: win32.HWND, rect: *win32.RECT) void {
    var upper_left = win32_foundation.POINT{
        .x = rect.left,
        .y = rect.top,
    };
    var lower_right = win32_foundation.POINT{
        .x = rect.right,
        .y = rect.bottom,
    };

    _ = win32_gdi.ClientToScreen(window_handle, &upper_left);
    _ = win32_gdi.ClientToScreen(window_handle, &lower_right);

    rect.* = win32.RECT{
        .left = upper_left.x,
        .top = upper_left.y,
        .right = lower_right.x,
        .bottom = lower_right.y,
    };
}

/// Returns the (width,height) of the window
/// thread safe.
pub fn windowSize(window_handle: win32.HWND) common.geometry.WidowSize {
    var rect: win32.RECT = undefined;
    // Calling GetWindowRect will have different behavior
    // depending on whether the window has ever been shown or not.
    // If the window has not been shown before,
    // GetWindowRect will not include the area of the drop shadow.
    _ = win32_window_messaging.GetWindowRect(window_handle, &rect);
    const size = common.geometry.WidowSize{
        .width = rect.right - rect.left,
        .height = rect.bottom - rect.top,
    };
    return size;
}

fn setWindowPositionIntern(window_handle: win32.HWND, top: ?win32.HWND, flags: u32, x: i32, y: i32, size: *const common.geometry.WidowSize) void {
    _ = win32_window_messaging.SetWindowPos(
        window_handle,
        top,
        x,
        y,
        size.width,
        size.height,
        @intToEnum(win32_window_messaging.SET_WINDOW_POS_FLAGS, flags),
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
        .right = data.video.width,
        .bottom = data.video.height,
    };

    // Calculates the required size of the window rectangle,
    // based on the desired client-rectangle size.
    _ = win32_window_messaging.AdjustWindowRectEx(
        &window_rect,
        @intToEnum(win32_window_messaging.WINDOW_STYLE, styles[0]),
        0,
        @intToEnum(win32_window_messaging.WINDOW_EX_STYLE, styles[1]),
    );

    var frame_x: i32 = undefined;
    var frame_y: i32 = undefined;

    if (data.position.x != win32_window_messaging.CW_USEDEFAULT and
        data.position.y != win32_window_messaging.CW_USEDEFAULT)
    {
        frame_x = data.position.x + window_rect.left;
        frame_y = data.position.y + window_rect.top;
    } else {
        frame_x = win32_window_messaging.CW_USEDEFAULT;
        frame_y = win32_window_messaging.CW_USEDEFAULT;
    }

    const frame = .{
        frame_x,
        frame_y,
        window_rect.right - window_rect.left,
        window_rect.bottom - window_rect.top,
    };

    const creation_lparm = data;
    const win32_globl = Win32Context.singleton().?;

    var buffer: [Win32Context.WINDOW_CLASS_NAME.len * 4]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const wide_class_name = utils.utf8ToWideZ(fba.allocator(), Win32Context.WINDOW_CLASS_NAME) catch unreachable;
    const window_title = try utils.utf8ToWideZ(allocator, title);
    defer allocator.free(window_title);
    const window_handle = win32_window_messaging.CreateWindowExW(
        @intToEnum(win32_window_messaging.WINDOW_EX_STYLE, styles[1]), // dwExStyles
        wide_class_name, // Window Class Name
        // utils.makeIntAtom(u16, internals.win32.handles.main_class),
        window_title, // Window Name
        @intToEnum(win32_window_messaging.WINDOW_STYLE, styles[0]), // dwStyles
        frame[0], // X
        frame[1], // Y
        frame[2], // width
        frame[3], // height
        null, // Parent Hwnd
        null, // hMenu
        win32_globl.handles.hinstance, // hInstance
        @ptrCast(?*anyopaque, @constCast(creation_lparm)), // CREATESTRUCT lparam
    ) orelse {
        return WindowError.FailedToCreate;
    };

    return window_handle;
}

/// Updates the cursor image.
pub fn updateCursorImage(cursor: *const Cursor) void {
    if (cursor.mode.is_disabled()) {
        _ = win32_window_messaging.SetCursor(null);
    } else {
        if (cursor.handle) |value| {
            _ = win32_window_messaging.SetCursor(value);
        } else {
            _ = win32_window_messaging.SetCursor(win32_window_messaging.LoadCursorW(null, win32_window_messaging.IDC_ARROW));
        }
    }
}

pub inline fn captureCursor(window_handle: win32.HWND) void {
    var clip_rect: win32.RECT = undefined;
    clientRect(window_handle, &clip_rect);
    // ClipCursor expects screen coordinates.
    clientToScreen(window_handle, &clip_rect);
    _ = win32_window_messaging.ClipCursor(&clip_rect);
}

pub inline fn releaseCursor() void {
    _ = win32_window_messaging.ClipCursor(null);
}

pub fn disableCursor(window_handle: win32.HWND, cursor: *const Cursor) void {
    captureCursor(window_handle);
    centerCursor(window_handle);
    updateCursorImage(cursor);
}

pub fn enableCursor(cursor: *const Cursor) void {
    updateCursorImage(cursor);
    releaseCursor();
}

// This function should only be called after capturing the cursor,
// otherwise the cursor will end up in an unkown position.
pub inline fn centerCursor(window_handle: win32.HWND) void {
    // The cursor is a shared resource.
    // A window should move the cursor only when the cursor
    // is in the window's client area.
    var rect: win32.RECT = undefined;
    clientRect(window_handle, &rect);
    _ = win32_window_messaging.SetCursorPos(@divExact(rect.right, 2), @divExact(rect.bottom, 2));
}

/// Returns the position of the top left corner of the client area.
/// in screen coordinates.
/// thread safe.
pub inline fn windowClientPosition(handle: win32.HWND) common.geometry.WidowPoint2D {
    // the client's top left acts as the origin in client
    // coordinates (0,0).
    var top_left = win32_foundation.POINT{ .x = 0, .y = 0 };
    _ = win32_gdi.ClientToScreen(handle, &top_left);
    return common.geometry.WidowPoint2D{
        .x = top_left.x,
        .y = top_left.y,
    };
}

/// Returns the Size of the window's client area
pub fn clientSize(handle: win32.HWND) common.geometry.WidowSize {
    // handle minimized case.
    var client: win32.RECT = undefined;
    clientRect(handle, &client);
    return common.geometry.WidowSize{
        .width = client.right,
        .height = client.bottom,
    };
}

pub const WidowProps = struct {
    monitors: *MonitorStore,
    events_queue: *common.event.EventQueue,
};

pub const WindowWin32Data = struct {
    icon: Icon,
    cursor: Cursor,
    keymenu: bool,
    frame_action: bool,
    width_cache: i32, // To store the width during resize events of the window.
    height_cache: i32, // To store the height during resize events of the window.
    high_surrogate: u16,
    dropped_files: std.ArrayList([]const u8),
    size_pos_update: u8, // we will use this to filter repeating size and postion events.
    pub const NO_SIZE_POSITION_UPDATE = @as(u8, 0x00);
    pub const SIZE_UPDATE = @as(u8, 0x01);
    pub const POSITON_UPDATE = @as(u8, 0x02);
    pub const SIZE_POSITION_UPDATE = @as(u8, 0x03);
};

pub const WindowImpl = struct {
    data: WindowData,
    widow: WidowProps,
    win32: WindowWin32Data,
    handle: win32_foundation.HWND,
    pub const WINDOW_DEFAULT_POSITION = common.geometry.WidowPoint2D{
        .x = win32_window_messaging.CW_USEDEFAULT,
        .y = win32_window_messaging.CW_USEDEFAULT,
    };
    const Self = @This();

    pub fn create(allocator: std.mem.Allocator, window_title: []const u8, props: WidowProps, data: *const WindowData) !*Self {
        var self = try allocator.create(WindowImpl);
        errdefer allocator.destroy(self);
        // get the window handle
        self.widow = props;
        self.data = data.*;
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
            .keymenu = false,
            .frame_action = false,
            .dropped_files = std.ArrayList([]const u8).init(allocator),
            .width_cache = 0,
            .height_cache = 0,
            .size_pos_update = WindowWin32Data.NO_SIZE_POSITION_UPDATE,
        };

        const styles = .{ windowStyles(data), windowExStyles(data) };
        self.handle = try createPlatformWindow(allocator, window_title, data, styles);

        _ = win32_window_messaging.SetWindowLongPtrW(
            self.handle,
            win32_window_messaging.GWLP_USERDATA,
            @intCast(isize, @ptrToInt(self)),
        );

        var window_rect: win32.RECT = undefined;
        clientRect(self.handle, &window_rect);
        var dpi_scale: f64 = undefined;
        const dpi = self.scalingDPI(&dpi_scale);
        window_rect.right = @floatToInt(i32, @intToFloat(f64, window_rect.right) * dpi_scale);
        window_rect.bottom = @floatToInt(i32, @intToFloat(f64, window_rect.bottom) * dpi_scale);

        adjustWindowRect(
            &window_rect,
            styles[0],
            styles[1],
            dpi,
        );

        var window_placement: win32_window_messaging.WINDOWPLACEMENT = undefined;
        windowPlacement(self.handle, &window_placement);

        _ = win32_gdi.OffsetRect(
            &window_rect,
            window_placement.rcNormalPosition.left - window_rect.left,
            window_placement.rcNormalPosition.top - window_rect.top,
        );

        window_placement.rcNormalPosition = window_rect;
        window_placement.showCmd = win32_window_messaging.SW_HIDE;

        _ = win32_window_messaging.SetWindowPlacement(
            self.handle,
            &window_placement,
        );

        // Allow Drag & Drop messages.
        if (Win32Context.singleton().?.flags.is_win7_or_above) {
            // Sent when the user drops a file on the window [Windows XP minimum]
            _ = win32_window_messaging.ChangeWindowMessageFilterEx(
                self.handle,
                win32_window_messaging.WM_DROPFILES,
                win32_window_messaging.MSGFLT_ALLOW,
                null,
            );
            _ = win32_window_messaging.ChangeWindowMessageFilterEx(
                self.handle,
                win32_window_messaging.WM_COPYDATA,
                win32_window_messaging.MSGFLT_ALLOW,
                null,
            );
            _ = win32_window_messaging.ChangeWindowMessageFilterEx(
                self.handle,
                win32.WM_COPYGLOBALDATA,
                win32_window_messaging.MSGFLT_ALLOW,
                null,
            );
        }
        DragAcceptFiles(self.handle, 1);

        if (self.data.flags.is_visible) {
            self.show();
            if (self.data.flags.is_focused) {
                self.focus();
            }
        }

        // Fullscreen
        if (self.data.fullscreen_mode != null) {
            try self.acquireMonitor();
        }

        return self;
    }

    pub fn close(self: *Self) void {
        // Clean up code
        if (self.data.fullscreen_mode != null) {
            // release the currently occupied monitor
            self.releaseMonitor() catch {};
        }
        if (self.win32.cursor.mode.is_captured()) {
            releaseCursor();
        }
        if (self.win32.cursor.mode.is_disabled()) {
            enableCursor(&self.win32.cursor);
        }
        // Get rid of the pointer to the window.
        _ = win32_window_messaging.SetWindowLongPtrW(self.handle, win32_window_messaging.GWLP_USERDATA, 0);
        _ = win32_window_messaging.DestroyWindow(self.handle);
        self.freeDroppedFiles();
    }

    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        self.close();
        allocator.destroy(self);
    }

    /// Shows the hidden window.
    pub fn show(self: *Self) void {
        // Show without activating.
        _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_SHOWNA);
        self.data.flags.is_visible = true;
    }

    pub fn focus(self: *Self) void {
        _ = win32_window_messaging.BringWindowToTop(self.handle);
        _ = win32_window_messaging.SetForegroundWindow(self.handle);
        _ = SetFocus(self.handle);
    }

    pub fn scalingDPI(self: *const Self, scaler: ?*f64) u32 {
        const win32_globl = Win32Context.singleton().?;
        var dpi: u32 = win32.USER_DEFAULT_SCREEN_DPI;
        if (self.data.flags.allow_dpi_scaling) err_exit: {
            if (win32_globl.functions.GetDpiForWindow) |proc| {
                dpi = proc(self.handle);
            } else {
                const monitor_handle = win32_gdi.MonitorFromWindow(self.handle, win32_gdi.MONITOR_DEFAULTTONEAREST) orelse break :err_exit;
                dpi = monitor_impl.monitorDPI(monitor_handle);
            }
        }
        if (scaler) |ptr| {
            ptr.* = (@intToFloat(f64, dpi) / @intToFloat(f64, win32.USER_DEFAULT_SCREEN_DPI));
        }
        return dpi;
    }

    /// Not ThreadSafe
    /// the window should belong to the thread calling this function.
    pub fn processEvents(self: *Self) void {
        var msg: win32_window_messaging.MSG = undefined;
        while (win32_window_messaging.PeekMessageW(&msg, self.handle, 0, 0, win32_window_messaging.PM_REMOVE) != 0) {
            _ = win32_window_messaging.TranslateMessage(&msg);
            _ = win32_window_messaging.DispatchMessageW(&msg);
        }
        // Emit key up for released modifers keys.
        utils.clearStickyKeys(self);
    }

    /// Not ThreadSafe
    /// the window should belong to the thread calling this function.
    pub fn waitEvent(self: *Self) void {
        _ = win32_window_messaging.WaitMessage();
        self.processEvents();
    }

    /// Not ThreadSafe
    /// the window should belong to the thread calling this function.
    /// Waits for an input event or the timeout interval elapses.
    pub fn waitEventTimeout(self: *Self, timeout: u32) bool {
        if (win32_window_messaging.MsgWaitForMultipleObjects(
            0,
            null,
            0,
            timeout,
            win32_window_messaging.QS_ALLINPUT,
        ) == win32.WAIT_TIMEOUT) {
            // Timeout period elapsed.
            return false;
        }
        self.processEvents();
        return true;
    }

    /// Updates the registered window styles to match the current window config.
    fn updateStyles(self: *Self) void {
        const STYLES_MASK: u32 = comptime @enumToInt(win32_window_messaging.WS_OVERLAPPEDWINDOW) | @enumToInt(win32_window_messaging.WS_POPUP) | @enumToInt(win32_window_messaging.WS_MAXIMIZE);
        const EX_STYLES_MASK: u32 = comptime @enumToInt(win32_window_messaging.WS_EX_WINDOWEDGE) | @enumToInt(win32_window_messaging.WS_EX_APPWINDOW) | @enumToInt(win32_window_messaging.WS_EX_TOPMOST);
        const POSITION_FLAGS: u32 = comptime @enumToInt(win32_window_messaging.SWP_FRAMECHANGED) | @enumToInt(win32_window_messaging.SWP_NOACTIVATE) | @enumToInt(win32_window_messaging.SWP_NOZORDER);

        const styles = windowStyles(&self.data);
        const ex_styles = windowExStyles(&self.data);
        var reg_styles = @bitCast(usize, win32_window_messaging.GetWindowLongPtrW(self.handle, win32_window_messaging.GWL_STYLE));
        var reg_ex_styles = @bitCast(usize, win32_window_messaging.GetWindowLongPtrW(self.handle, win32_window_messaging.GWL_EXSTYLE));
        reg_styles &= ~STYLES_MASK;
        reg_ex_styles &= ~EX_STYLES_MASK;
        reg_styles |= styles;
        reg_ex_styles |= ex_styles;

        _ = win32_window_messaging.SetWindowLongPtrW(self.handle, win32_window_messaging.GWL_STYLE, @bitCast(isize, reg_styles));
        _ = win32_window_messaging.SetWindowLongPtrW(self.handle, win32_window_messaging.GWL_EXSTYLE, @bitCast(isize, reg_ex_styles));
        var scaler: f64 = undefined;
        const dpi = self.scalingDPI(&scaler);
        var rect = win32_foundation.RECT{
            .left = 0,
            .top = 0,
            .right = @floatToInt(i32, @intToFloat(f64, self.data.video.width) * scaler),
            .bottom = @floatToInt(i32, @intToFloat(f64, self.data.video.height) * scaler),
        };
        adjustWindowRect(
            &rect,
            @truncate(u32, reg_styles),
            @truncate(u32, reg_ex_styles),
            dpi,
        );
        const new_size = common.geometry.WidowSize{ .width = (rect.right - rect.left), .height = (rect.bottom - rect.top) };
        const top = if (self.data.flags.is_topmost) win32_window_messaging.HWND_TOPMOST else win32_window_messaging.HWND_NOTOPMOST;
        if (self.data.restore_point) |*point| {
            setWindowPositionIntern(self.handle, top, POSITION_FLAGS, point.x, point.y, &new_size);
        } else {
            clientToScreen(self.handle, &rect);
            setWindowPositionIntern(self.handle, top, POSITION_FLAGS, rect.left, rect.top, &new_size);
        }
    }

    pub fn cursorPositon(self: *const Self) common.geometry.WidowPoint2D {
        var cursor_pos: win32_foundation.POINT = undefined;
        _ = win32_window_messaging.GetCursorPos(&cursor_pos);
        _ = win32_gdi.ScreenToClient(self.handle, &cursor_pos);
        // the cursor_pos is relative to the upper left corner of the window.
        return common.geometry.WidowPoint2D{ .x = cursor_pos.x, .y = cursor_pos.y };
    }

    pub fn setCursorPosition(self: *const Self, x: i32, y: i32) void {
        var point = win32_foundation.POINT{
            .x = x,
            .y = y,
        };
        _ = win32_gdi.ClientToScreen(self.handle, &point);
        _ = win32_window_messaging.SetCursorPos(point.x, point.y);
    }

    pub fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
        if (self.win32.cursor.mode == mode) {
            return;
        }
        self.win32.cursor.mode = mode;
        enableCursor(&self.win32.cursor);
        switch (mode) {
            common.cursor.CursorMode.Captured => captureCursor(self.handle),
            common.cursor.CursorMode.Disabled => disableCursor(self.handle, &self.win32.cursor),
            else => {},
        }
    }

    /// Notify and flash the taskbar.
    pub fn flash(self: *const Self) void {
        var flash_info = win32_window_messaging.FLASHWINFO{
            .cbSize = @sizeOf(win32_window_messaging.FLASHWINFO),
            .hwnd = self.handle,
            .dwFlags = win32_window_messaging.FLASHW_ALL,
            .uCount = 3,
            .dwTimeout = 0,
        };
        _ = win32_window_messaging.FlashWindowEx(&flash_info);
    }

    /// Add an event to the events queue.
    pub fn queueEvent(self: *Self, event: *const common.event.Event) void {
        self.widow.events_queue.sendEvent(event);
    }

    /// Returns the position of the top left corner.
    /// # Note
    /// in case of the window being hidden or minimized
    /// the returned value is the last known position of the window.
    /// Could add thread safety with RWlock.
    pub fn position(self: *const Self) common.geometry.WidowPoint2D {
        return self.data.position;
    }

    /// Moves the window's top left corner
    /// to the specified screen coordinates.
    pub fn setPosition(self: *const Self, x: i32, y: i32) void {
        // Don't use SWP_NOSIZE to allow dpi change.
        const POSITION_FLAGS: u32 = comptime @enumToInt(win32_window_messaging.SWP_NOZORDER) | @enumToInt(win32_window_messaging.SWP_NOACTIVATE) | @enumToInt(win32_window_messaging.SWP_NOREPOSITION);

        if (self.data.flags.is_maximized) {
            // Moving a maximized window should restore it to it's orignal size
            self.restore();
        }
        var rect = win32_foundation.RECT{
            .left = x,
            .top = y,
            .right = x,
            .bottom = y,
        };
        adjustWindowRect(
            &rect,
            windowStyles(&self.data),
            windowExStyles(&self.data),
            self.scalingDPI(null),
        );
        const top = if (self.data.flags.is_topmost) win32_window_messaging.HWND_TOPMOST else win32_window_messaging.HWND_NOTOPMOST;
        const size = windowSize(self.handle);

        setWindowPositionIntern(self.handle, top, POSITION_FLAGS, x, y, &size);
    }

    /// Sets the new (width,height) of the window's client area
    pub fn setClientSize(self: *Self, size: *common.geometry.WidowSize) void {
        self.data.video.width = size.width;
        self.data.video.height = size.height;
        if (self.data.fullscreen_mode != null) {
            // Borderless is still unhandled.
            self.acquireMonitor() catch {
                std.debug.print("Failed To switch video Mode\n", .{});
                self.requestRestore();
            };
        } else {
            var scaler: f64 = undefined;
            const dpi = self.scalingDPI(&scaler);
            size.scaleBy(scaler);
            var new_client_rect = win32_foundation.RECT{
                .left = 0,
                .top = 0,
                .right = size.width,
                .bottom = size.height,
            };
            adjustWindowRect(
                &new_client_rect,
                windowStyles(&self.data),
                windowExStyles(&self.data),
                dpi,
            );
            if (self.data.flags.is_maximized) {
                // un-maximize the window
                self.restore();
            }
            const POSITION_FLAGS: u32 = comptime @enumToInt(win32_window_messaging.SWP_NOACTIVATE) | @enumToInt(win32_window_messaging.SWP_NOREPOSITION) | @enumToInt(win32_window_messaging.SWP_NOZORDER) | @enumToInt(win32_window_messaging.SWP_NOMOVE);

            const top = if (self.data.flags.is_topmost) win32_window_messaging.HWND_TOPMOST else win32_window_messaging.HWND_NOTOPMOST;
            setWindowPositionIntern(
                self.handle,
                top,
                POSITION_FLAGS,
                0,
                0,
                &common.geometry.WidowSize{ .width = new_client_rect.right - new_client_rect.left, .height = new_client_rect.bottom - new_client_rect.top },
            );
        }
    }

    pub fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
        if (min_size != null) {
            var size = min_size.?;
            // min size shouldn't be negative.
            if (size.width > 0 and size.height > 0) {
                if (self.data.max_size) |*max_size| {
                    // the min size shouldn't be superior to the max size.
                    if (max_size.width >= size.width and max_size.height >= size.height) {
                        var scaler: f64 = undefined;
                        _ = self.scalingDPI(&scaler);
                        size.scaleBy(scaler);
                        self.data.min_size = size;
                    }
                } else {
                    var scaler: f64 = undefined;
                    _ = self.scalingDPI(&scaler);
                    size.scaleBy(scaler);
                    self.data.min_size = size;
                }
            }
        } else {
            self.data.min_size = null;
        }

        if (self.data.fullscreen_mode != null or !self.data.flags.is_resizable) {
            // No need to do anything now.
            return;
        }
        const pos = self.position();
        const size = windowSize(self.handle);
        // We need the system to post a WM_MINMAXINFO.
        // in order for the new size limits to be applied,
        // we will cause that by calling MoveWindow().
        _ = win32_window_messaging.MoveWindow(
            self.handle,
            pos.x,
            pos.y,
            size.width,
            size.height,
            win32.TRUE,
        );
    }

    pub fn setMaxSize(self: *Self, max_size: ?common.geometry.WidowSize) void {
        if (max_size != null) {
            var size = max_size.?;
            // max size shouldn't be negative.
            if (size.width > 0 and size.height > 0) {
                if (self.data.min_size) |*min_size| {
                    // the max size should be superior or equal to the min size.
                    if (size.width >= min_size.width or size.height >= min_size.height) {
                        var scaler: f64 = undefined;
                        _ = self.scalingDPI(&scaler);
                        size.scaleBy(scaler);
                        self.data.max_size = size;
                    }
                } else {
                    var scaler: f64 = undefined;
                    _ = self.scalingDPI(&scaler);
                    size.scaleBy(scaler);
                    self.data.max_size = size;
                }
            }
        } else {
            self.data.max_size = null;
        }

        if (self.data.fullscreen_mode != null or !self.data.flags.is_resizable) {
            // No need to do anything now.
            return;
        }
        const pos = self.position();
        const size = windowSize(self.handle);
        // We need the system to post a WM_MINMAXINFO.
        // in order for the new size limits to be applied,
        // we will cause that by calling MoveWindow().
        _ = win32_window_messaging.MoveWindow(
            self.handle,
            pos.x,
            pos.y,
            size.width,
            size.height,
            win32.TRUE,
        );
    }

    /// Hides the window, this is different from minimizing it.
    pub fn hide(self: *Self) void {
        _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_HIDE);
        self.data.flags.is_visible = false;
    }

    /// toggles window resizablitity on(true) or off(false).
    pub fn setResizable(self: *Self, value: bool) void {
        self.data.flags.is_resizable = value;
        self.updateStyles();
    }

    /// toggles window resizablitity on(true) or off(false).
    pub fn setDecorated(self: *Self, value: bool) void {
        self.data.flags.is_decorated = value;
        self.updateStyles();
    }

    /// Returns true if the window is active(has keyboard focus).
    pub fn isfocused(self: *const Self) bool {
        return self.data.flags.is_focused;
    }

    /// Returns true if the window is currently maximized.
    pub fn is_maximized(self: *const Self) bool {
        return self.data.flags.is_maximized;
    }

    /// Maximize the window.
    pub fn maximize(self: *const Self) void {
        _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_MAXIMIZE);
    }

    /// Minimizes the window.
    pub fn minimize(self: *const Self) void {
        _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_MINIMIZE);
    }

    /// Restores the minimized or maximized window to a normal window.
    pub fn restore(self: *const Self) void {
        _ = win32_window_messaging.ShowWindow(self.handle, win32_window_messaging.SW_RESTORE);
    }

    /// Returns true if the cursor is inside the client area.
    pub fn is_hovered(self: *const Self) bool {
        return self.data.flags.cursor_in_client;
    }

    /// Changes the title of the window.
    pub fn setTitle(self: *Self, allocator: std.mem.Allocator, new_title: []const u8) !void {
        const wide_title = try utils.utf8ToWideZ(allocator, new_title);
        defer allocator.free(wide_title);
        _ = win32_window_messaging.SetWindowTextW(self.handle, wide_title);
    }

    /// returns the title of the window.
    pub inline fn title(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        // This length doesn't take into account the null character so add it when allocating.
        const wide_title_len = win32_window_messaging.GetWindowTextLengthW(self.handle);
        if (wide_title_len > 0) {
            var wide_slice = try allocator.allocSentinel(u16, @intCast(usize, wide_title_len) + 1, 0);
            defer allocator.free(wide_slice);
            // to get the full title we must specify the full buffer length or we will be on character short.
            _ = win32_window_messaging.GetWindowTextW(self.handle, wide_slice.ptr, wide_title_len + 1);
            const slice = try utils.wideZToUtf8(allocator, wide_slice);
            return slice;
        }
        // TODO: why can't i use WindowError set instead of the global error set?
        return error.FailedToCopyTitle;
    }

    /// Returns the window's current opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn opacity(self: *const Self) f32 {
        const ex_styles = win32_window_messaging.GetWindowLongPtrW(self.handle, win32_window_messaging.GWL_EXSTYLE);
        if ((ex_styles & @enumToInt(win32_window_messaging.WS_EX_LAYERED)) != 0) {
            var alpha: u8 = undefined;
            var flags: win32_window_messaging.LAYERED_WINDOW_ATTRIBUTES_FLAGS = undefined;
            _ = win32_window_messaging.GetLayeredWindowAttributes(self.handle, null, &alpha, &flags);
            if ((@enumToInt(flags) & @enumToInt(win32_window_messaging.LWA_ALPHA)) != 0) {
                return (@intToFloat(f32, alpha) / 255.0);
            }
        }
        return 1.0;
    }

    /// set the window's opacity
    /// # Note
    /// The value is between 1.0 and 0.0
    /// with 1 being opaque and 0 being full transparent.
    pub fn setOpacity(self: *Self, value: f32) void {
        var ex_styles = @bitCast(usize, win32_window_messaging.GetWindowLongPtrW(self.handle, win32_window_messaging.GWL_EXSTYLE));

        if (value == @as(f32, 1.0)) {
            ex_styles &= ~@enumToInt(win32_window_messaging.WS_EX_LAYERED);
        } else {
            const alpha = @truncate(u8, @floatToInt(u32, value * 255.0));

            if ((ex_styles & @enumToInt(win32_window_messaging.WS_EX_LAYERED)) == 0) {
                ex_styles |= @enumToInt(win32_window_messaging.WS_EX_LAYERED);
            }

            _ = win32_window_messaging.SetLayeredWindowAttributes(self.handle, 0, alpha, win32_window_messaging.LWA_ALPHA);
        }
        _ = win32_window_messaging.SetWindowLongPtrW(self.handle, win32_window_messaging.GWL_EXSTYLE, @bitCast(isize, ex_styles));
    }

    pub fn setAspectRatio(self: *Self, ratio: ?common.window_data.AspectRatio) void {
        // shamlessly copied from GLFW library.
        self.data.aspect_ratio = ratio;
        if (ratio != null) {
            var rect: win32.RECT = undefined;
            _ = win32_window_messaging.GetWindowRect(self.handle, &rect);
            self.applyAspectRatio(&rect, win32_window_messaging.WMSZ_BOTTOMLEFT);
            _ = win32_window_messaging.MoveWindow(
                self.handle,
                rect.left,
                rect.top,
                rect.right - rect.left,
                rect.bottom - rect.top,
                win32.TRUE,
            );
        }
    }

    pub fn applyAspectRatio(self: *const Self, client: *win32_foundation.RECT, edge: u32) void {
        const ratio = @intToFloat(f64, self.data.aspect_ratio.?.x) / @intToFloat(f64, self.data.aspect_ratio.?.y);

        var rect = win32_foundation.RECT{
            .left = 0,
            .top = 0,
            .right = 0,
            .bottom = 0,
        };

        adjustWindowRect(
            &rect,
            windowStyles(&self.data),
            windowExStyles(&self.data),
            self.scalingDPI(null),
        );

        switch (edge) {
            win32_window_messaging.WMSZ_LEFT, win32_window_messaging.WMSZ_RIGHT, win32_window_messaging.WMSZ_BOTTOMLEFT, win32_window_messaging.WMSZ_BOTTOMRIGHT => {
                client.bottom = client.top + (rect.bottom - rect.top) + @floatToInt(i32, @intToFloat(f64, (client.right - client.left) - (rect.right - rect.left)) / ratio);
            },
            win32_window_messaging.WMSZ_TOPLEFT, win32_window_messaging.WMSZ_TOPRIGHT => {
                client.top = client.bottom - (rect.bottom - rect.top) - @floatToInt(i32, @intToFloat(f64, (client.right - client.left) - (rect.right - rect.left)) / ratio);
            },
            win32_window_messaging.WMSZ_TOP, win32_window_messaging.WMSZ_BOTTOM => {
                client.right = client.left + (rect.right - rect.left) + @floatToInt(i32, @intToFloat(f64, (client.bottom - client.top) - (rect.bottom - rect.top)) * ratio);
            },
            else => unreachable,
        }
    }

    /// Returns the fullscreen mode of the window;
    pub fn setFullscreen(self: *Self, fullscreen_mode: ?FullScreenMode) !void {
        if (self.data.fullscreen_mode != fullscreen_mode) {
            if (fullscreen_mode) |mode| {
                self.data.fullscreen_mode = mode;
                if (self.data.restore_point == null) {
                    self.data.restore_point = self.data.position;
                }
                self.updateStyles();
                try self.acquireMonitor();
            } else {
                try self.releaseMonitor();
                self.requestRestore();
            }
        }
    }

    pub fn requestRestore(self: *Self) void {
        self.data.fullscreen_mode = null;
        self.updateStyles();
        self.data.restore_point = null;
    }

    pub fn acquireMonitor(self: *Self) !void {
        const monitor_handle = win32_gdi.MonitorFromWindow(self.handle, win32_gdi.MONITOR_DEFAULTTONEAREST) orelse {
            return WindowError.NullMonitorHandle;
        };
        const mode = if (self.data.fullscreen_mode.? == FullScreenMode.Exclusive) &self.data.video else null;
        var mon_area: common.geometry.WidowArea = undefined;
        try self.widow.monitors.setMonitorWindow(
            monitor_handle,
            self,
            mode,
            &mon_area,
        );
        const POSITION_FLAGS: u32 = @enumToInt(win32_window_messaging.SWP_NOZORDER) |
            @enumToInt(win32_window_messaging.SWP_NOACTIVATE) |
            @enumToInt(win32_window_messaging.SWP_NOCOPYBITS);
        const top = if (self.data.flags.is_topmost) win32_window_messaging.HWND_TOPMOST else win32_window_messaging.HWND_NOTOPMOST;
        setWindowPositionIntern(
            self.handle,
            top,
            POSITION_FLAGS,
            mon_area.top_left.x,
            mon_area.top_left.y,
            &mon_area.size,
        );
    }

    pub fn releaseMonitor(self: *const Self) !void {
        const monitor_handle = win32_gdi.MonitorFromWindow(self.handle, win32_gdi.MONITOR_DEFAULTTONEAREST) orelse {
            std.debug.print("Null Monitor handle \n", .{});
            return;
        };
        try self.widow.monitors.restoreMonitor(monitor_handle);
    }

    pub fn setCursorShape(self: *Self, new_cursor: *const Cursor) void {
        icon.destroyCursor(&self.win32.cursor);
        self.win32.cursor = new_cursor.*;
        if (self.data.flags.cursor_in_client) {
            updateCursorImage(&self.win32.cursor);
        }
    }

    pub fn setIcon(self: *Self, new_icon: *const Icon) void {
        const handles = if (new_icon.sm_handle != null and new_icon.bg_handle != null) .{ @ptrToInt(new_icon.bg_handle.?), @ptrToInt(new_icon.sm_handle.?) } else blk: {
            const bg_icon = win32_window_messaging.GetClassLongPtrW(self.handle, win32_window_messaging.GCLP_HICON);
            const sm_icon = win32_window_messaging.GetClassLongPtrW(self.handle, win32_window_messaging.GCLP_HICONSM);
            break :blk .{ bg_icon, sm_icon };
        };
        _ = win32_window_messaging.SendMessageW(self.handle, win32_window_messaging.WM_SETICON, win32_window_messaging.ICON_BIG, @bitCast(isize, handles[0]));
        _ = win32_window_messaging.SendMessageW(self.handle, win32_window_messaging.WM_SETICON, win32_window_messaging.ICON_SMALL, @bitCast(isize, handles[1]));
        icon.destroyIcon(&self.win32.icon);
        self.win32.icon = new_icon.*;
    }

    /// Returns a cached slice that contains the path(s) to the last dropped file(s).
    pub fn droppedFiles(self: *const Self) [][]const u8 {
        return self.win32.dropped_files.items;
    }

    /// Frees the allocated memory used to hold the file(s) path(s).
    pub fn freeDroppedFiles(self: *Self) void {
        const allocator = self.win32.dropped_files.allocator;
        for (self.win32.dropped_files.items) |item| {
            allocator.free(item);
        }
        self.win32.dropped_files.clearAndFree();
    }

    // DEBUG ONLY
    pub fn debugInfos(self: *const Self) void {
        std.debug.print("0==========================0\n", .{});
        std.debug.print("Video Mode: {}\n", .{self.data.video});
        std.debug.print("Flags Mode: {}\n", .{self.data.flags});
        std.debug.print("Top Left Position: {}\n", .{self.data.position});
        if (self.data.min_size) |*value| {
            std.debug.print("Min Size: {}\n", .{value.*});
        }
        if (self.data.max_size) |*value| {
            std.debug.print("Max Size: {}\n", .{value.*});
        }
        if (self.data.aspect_ratio) |*value| {
            std.debug.print("Aspect Ratio: {}/{}\n", .{ value.x, value.y });
        }
        if (self.data.fullscreen_mode) |*value| {
            std.debug.print("Screen Mode: {}\n", .{value.*});
        }
    }
};

test "Window title" {
    const testing = std.testing;
    var eq = common.event.EventQueue.init(testing.allocator);
    defer eq.deinit();
    var ms = try MonitorStore.init(testing.allocator);
    defer ms.deinit();
    var data =
        common.window_data.WindowData{
        .id = 0,
        .video = common.video_mode.VideoMode{
            .width = 800,
            .height = 600,
            .color_depth = 32,
            .frequency = 60,
        },
        .position = WindowImpl.WINDOW_DEFAULT_POSITION,
        .restore_point = null,
        .min_size = null,
        .max_size = null,
        .aspect_ratio = null,
        .fullscreen_mode = null,
        .flags = common.window_data.WindowFlags{
            .is_visible = true,
            .is_maximized = false,
            .is_minimized = false,
            .is_resizable = false,
            .is_decorated = true,
            .is_topmost = false,
            .is_focused = false,
            .cursor_in_client = false,
            .accepts_raw_input = false,
            .allow_dpi_scaling = true,
        },
        .input = common.keyboard_and_mouse.InputState.init(),
    };
    const window = try WindowImpl.create(
        testing.allocator,
        "Title test",
        WidowProps{
            .events_queue = &eq,
            .monitors = &ms,
        },
        &data,
    );
    defer window.destroy(testing.allocator);
    const title = try window.title(testing.allocator);
    defer testing.allocator.free(title);
    try testing.expectEqualStrings("Title test", title);
    try window.setTitle(testing.allocator, "Hello World");
    const new_title = try window.title(testing.allocator);
    defer testing.allocator.free(new_title);
    try testing.expectEqualStrings("Hello World", new_title);
}
