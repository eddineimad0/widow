const std = @import("std");
const zigwin32 = @import("zigwin32");
const common = @import("common");
const win32_window_messaging = zigwin32.ui.windows_and_messaging;
const win32_gdi = zigwin32.graphics.gdi;
const IconError = @import("errors.zig").IconError;
const TRUE = @import("win32_defs.zig").TRUE;
const FALSE = @import("win32_defs.zig").FALSE;
const BOOL = @import("win32_defs.zig").BOOL;

pub fn createIcon(
    pixels: []const u8,
    width: i32,
    height: i32,
    xhot: ?u32,
    yhot: ?u32,
) !win32_window_messaging.HICON {
    var bmp_header: win32_gdi.BITMAPV5HEADER = std.mem.zeroes(win32_gdi.BITMAPV5HEADER);
    bmp_header.bV5Size = @sizeOf(win32_gdi.BITMAPV5HEADER);
    bmp_header.bV5Width = width;
    //  If bV5Height value is negative, the bitmap is a top-down DIB
    //  and its origin is the upper-left corner.
    bmp_header.bV5Height = -height;
    bmp_header.bV5Planes = 1;
    bmp_header.bV5BitCount = 32; // 32 bits colors.
    // No compression and we will provide the color masks.
    bmp_header.bV5Compression = win32_gdi.BI_BITFIELDS;
    bmp_header.bV5AlphaMask = 0xFF000000;
    bmp_header.bV5BlueMask = 0x00FF0000;
    bmp_header.bV5GreenMask = 0x0000FF00;
    bmp_header.bV5RedMask = 0x000000FF;

    var dib: [*]u8 = undefined;
    const dc = win32_gdi.GetDC(null);
    defer _ = win32_gdi.ReleaseDC(null, dc);
    const color_mask = win32_gdi.CreateDIBSection(
        dc,
        @ptrCast(&bmp_header),
        win32_gdi.DIB_RGB_COLORS,
        @ptrCast(&dib),
        null,
        0,
    );
    if (color_mask == null) {
        return IconError.NullColorMask;
    }
    defer _ = win32_gdi.DeleteObject(color_mask);

    const monochrome_mask = win32_gdi.CreateBitmap(width, height, 1, 1, null);
    if (monochrome_mask == null) {
        return IconError.NullMonochromeMask;
    }
    defer _ = win32_gdi.DeleteObject(monochrome_mask);

    // TODO: What about ARM?
    @memcpy(dib, pixels);

    var xspot: u32 = undefined;
    var yspot: u32 = undefined;
    var icon_flag: BOOL = TRUE;
    if (xhot != null and yhot != null) {
        xspot = xhot.?;
        yspot = yhot.?;
        icon_flag = FALSE;
    }

    var icon_info = win32_window_messaging.ICONINFO{
        .fIcon = icon_flag, // A value of TRUE(1) specifies an icon, FALSE(0) specify a cursor.
        .xHotspot = xspot,
        .yHotspot = yspot,
        .hbmMask = monochrome_mask,
        .hbmColor = color_mask,
    };

    const icon_handle = win32_window_messaging.CreateIconIndirect(&icon_info);

    return icon_handle orelse return IconError.FailedToCreate;
}

pub const Cursor = struct {
    handle: ?win32_window_messaging.HCURSOR,
    shared: bool, // As to avoid deleting system owned cursors.
    mode: common.cursor.CursorMode,
};

pub fn destroyCursor(cursor: *Cursor) void {
    if (!cursor.shared and cursor.handle != null) {
        _ = win32_window_messaging.DestroyCursor(cursor.handle);
        cursor.handle = null;
    }
}

pub const Icon = struct {
    sm_handle: ?win32_window_messaging.HICON,
    bg_handle: ?win32_window_messaging.HICON,
};

pub fn destroyIcon(icon: *Icon) void {
    if (icon.sm_handle) |handle| {
        _ = win32_window_messaging.DestroyIcon(handle);
        icon.sm_handle = null;
    }

    if (icon.bg_handle) |handle| {
        _ = win32_window_messaging.DestroyIcon(handle);
        icon.bg_handle = null;
    }
}
