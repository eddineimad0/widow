const std = @import("std");
const libx11 = @import("x11/xlib.zig");
const common = @import("common");

const X11Driver = @import("driver.zig").X11Driver;

pub const IconError = error{
    NotFound, // requested icon resource was not found.
    BadIcon, // Couldn't create the icon.
    UnsupportedAction,
    OutOfMemory,
};

pub const CursorHints = struct {
    icon: libx11.Cursor,
    mode: common.cursor.CursorMode,
    // Track the cursor coordinates in respect to top left corner.
    pos: common.geometry.WidowPoint2D,
};

pub fn createX11Cursor(
    pixels: []const u8,
    width: i32,
    height: i32,
    xhot: u32,
    yhot: u32,
) IconError!libx11.Cursor {
    const drvr = X11Driver.singleton();
    if (drvr.handles.xcursor == null) {
        return IconError.UnsupportedAction;
    }

    var curs_img = drvr.extensions.xcursor.XcursorImageCreate(
        @intCast(width),
        @intCast(height),
    ) orelse return IconError.OutOfMemory;

    defer drvr.extensions.xcursor.XcursorImageDestroy(curs_img);

    curs_img.xhot = @intCast(xhot);
    curs_img.yhot = @intCast(yhot);

    const pixl_sz: usize = @intCast(width * height);
    for (0..pixl_sz) |i| {
        // accepted format is ARGB.
        curs_img.pixels[i] = ((@as(u32, pixels[(4 * i) + 3]) << 24) |
            (@as(u32, pixels[(4 * i) + 0]) << 16) |
            (@as(u32, pixels[(4 * i) + 1]) << 8) |
            @as(u32, pixels[(4 * i) + 2]));
    }

    return drvr.extensions.xcursor.XcursorImageLoadCursor(
        drvr.handles.xdisplay,
        curs_img,
    );
}

/// Returns a handle to a shared(standard) platform cursor.
pub fn createNativeCursor(
    shape: common.cursor.NativeCursorShape,
) IconError!CursorHints {
    const drvr = X11Driver.singleton();
    const CursorShape = common.cursor.NativeCursorShape;
    var cursor_handle: libx11.Cursor = 0;
    if (drvr.handles.xcursor) |_| {
        const theme = drvr.extensions.xcursor.XcursorGetTheme(
            drvr.handles.xdisplay,
        ) orelse "default";

        const cursor_name: [*:0]const u8 = switch (shape) {
            CursorShape.PointingHand => "pointer",
            CursorShape.Crosshair => "crosshair",
            CursorShape.Text => "text",
            CursorShape.BkgrndTask => "progress",
            CursorShape.Help => "help",
            CursorShape.Busy => "wait",
            CursorShape.Forbidden => "not-allowed",
            CursorShape.Move => "all-scroll",
            CursorShape.Default => "default",
        };
        const size = drvr.extensions.xcursor.XcursorGetDefaultSize(drvr.handles.xdisplay);
        const image = drvr.extensions.xcursor.XcursorLibraryLoadImage(cursor_name, theme, size);
        if (image) |img| {
            defer drvr.extensions.xcursor.XcursorImageDestroy(img);
            cursor_handle = drvr.extensions.xcursor.XcursorImageLoadCursor(
                drvr.handles.xdisplay,
                img,
            );
        }
    }

    if (cursor_handle == 0) {
        const cursor_shape: c_uint = switch (shape) {
            CursorShape.PointingHand => libx11.XC_hand1,
            CursorShape.Crosshair => libx11.XC_crosshair,
            CursorShape.Text => libx11.XC_xterm,
            CursorShape.BkgrndTask => libx11.XC_watch,
            CursorShape.Help => libx11.XC_question_arrow,
            CursorShape.Busy => libx11.XC_exchange,
            CursorShape.Forbidden => libx11.XC_X_cursor,
            CursorShape.Move => libx11.XC_fleur,
            CursorShape.Default => libx11.XC_left_ptr,
        };

        cursor_handle = libx11.XCreateFontCursor(
            drvr.handles.xdisplay,
            cursor_shape,
        );
    }

    if (cursor_handle == 0) {
        // We failed.
        return IconError.NotFound;
    }

    return CursorHints{
        .icon = cursor_handle,
        .mode = common.cursor.CursorMode.Normal,
        .pos = .{ .x = 0, .y = 0 },
    };
}

pub fn destroyCursorIcon(cursor: *CursorHints) void {
    const drvr = X11Driver.singleton();
    if (cursor.icon != 0) {
        _ = libx11.XFreeCursor(drvr.handles.xdisplay, cursor.icon);
        cursor.icon = 0;
    }
}

pub fn undoCursorHints(cursor: *CursorHints, window: libx11.Window) void {
    const drvr = X11Driver.singleton();

    switch (cursor.mode) {
        .Captured, .Hidden => {
            unCaptureCursor();
            _ = libx11.XUndefineCursor(drvr.handles.xdisplay, window);
        },
        else => {},
    }

    drvr.flushXRequests();
}

pub fn applyCursorHints(cursor: *CursorHints, window: libx11.Window) void {
    const drvr = X11Driver.singleton();

    switch (cursor.mode) {
        .Normal => unCaptureCursor(),
        else => captureCursor(window),
    }

    const cursor_icon = switch (cursor.mode) {
        .Hidden => drvr.handles.hidden_cursor,

        else => img: {
            break :img if (cursor.icon != 0)
                cursor.icon
            else
                libx11.None;
        },
    };

    _ = libx11.XDefineCursor(drvr.handles.xdisplay, window, cursor_icon);
    drvr.flushXRequests();
}

pub fn unCaptureCursor() void {
    const drvr = X11Driver.singleton();
    libx11.XUngrabPointer(
        drvr.handles.xdisplay,
        libx11.CurrentTime,
    );
}

pub fn captureCursor(w: libx11.Window) void {
    const drvr = X11Driver.singleton();
    const retv = libx11.XGrabPointer(
        drvr.handles.xdisplay,
        w,
        libx11.True,
        libx11.ButtonPressMask | libx11.ButtonReleaseMask | libx11.PointerMotionMask,
        libx11.GrabModeAsync,
        libx11.GrabModeAsync,
        w,
        libx11.None,
        libx11.CurrentTime,
    );
    std.debug.assert(retv == libx11.GrabSuccess);
}
