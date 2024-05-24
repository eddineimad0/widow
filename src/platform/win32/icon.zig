const std = @import("std");
const zigwin32 = @import("zigwin32");
const common = @import("common");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const mem = std.mem;
const window_msg = zigwin32.ui.windows_and_messaging;
const gdi = zigwin32.graphics.gdi;

pub const IconError = error{
    BadIcon, // Couldn't create the icon.
    NullColorMask, // Couldn't create the DIB color mask
    NullMonochromeMask, // Couldn't create The DIB monocrhome mask
};

/// Creates a bitmap icon or cursor image
/// the xhot and yhot params are only considered if
/// is_cursor is true.
fn createWin32Icon(
    pixels: []const u8,
    width: i32,
    height: i32,
    xhot: u32,
    yhot: u32,
    is_cursor: bool,
) IconError!window_msg.HICON {
    var bmp_header: gdi.BITMAPV5HEADER = mem.zeroes(gdi.BITMAPV5HEADER);
    bmp_header.bV5Size = @sizeOf(gdi.BITMAPV5HEADER);
    bmp_header.bV5Width = width;
    //  If bV5Height value is negative, the bitmap is a top-down DIB
    //  and its origin is the upper-left corner.
    bmp_header.bV5Height = -height;
    bmp_header.bV5Planes = 1;
    bmp_header.bV5BitCount = 32; // 32 bits colors.
    // No compression and we will provide the color masks.
    bmp_header.bV5Compression = gdi.BI_BITFIELDS;
    bmp_header.bV5AlphaMask = 0xFF000000;
    bmp_header.bV5BlueMask = 0x00FF0000;
    bmp_header.bV5GreenMask = 0x0000FF00;
    bmp_header.bV5RedMask = 0x000000FF;

    var dib: [*]u8 = undefined;
    const dc = gdi.GetDC(null);
    defer _ = gdi.ReleaseDC(null, dc);
    const color_mask = gdi.CreateDIBSection(
        dc,
        @ptrCast(&bmp_header),
        gdi.DIB_RGB_COLORS,
        @ptrCast(&dib),
        null,
        0,
    );
    if (color_mask == null) {
        return IconError.NullColorMask;
    }
    defer _ = gdi.DeleteObject(color_mask);

    const monochrome_mask = gdi.CreateBitmap(width, height, 1, 1, null);
    if (monochrome_mask == null) {
        return IconError.NullMonochromeMask;
    }
    defer _ = gdi.DeleteObject(monochrome_mask);

    @memcpy(dib, pixels);

    var icon_info = window_msg.ICONINFO{
        .fIcon = @intFromBool(!is_cursor), // A value of TRUE(1) specifies an icon, FALSE(0) specify a cursor.
        .xHotspot = xhot,
        .yHotspot = yhot,
        .hbmMask = monochrome_mask,
        .hbmColor = color_mask,
    };

    const icon_handle = window_msg.CreateIconIndirect(&icon_info);

    return icon_handle orelse return IconError.FailedToCreate;
}

pub const CursorHints = struct {
    image: ?window_msg.HCURSOR,
    img_shared: bool, // As to avoid deleting system owned cursor images.
    mode: common.cursor.CursorMode,
};

pub fn destroyCursorImage(cursor: *CursorHints) void {
    if (!cursor.img_shared and cursor.image != null) {
        _ = window_msg.DestroyCursor(cursor.image);
        cursor.image = null;
    }
}

pub const Icon = struct {
    sm_handle: ?window_msg.HICON,
    bg_handle: ?window_msg.HICON,
};

pub fn destroyIcon(icon: *Icon) void {
    if (icon.sm_handle) |handle| {
        _ = window_msg.DestroyIcon(handle);
        icon.sm_handle = null;
    }

    if (icon.bg_handle) |handle| {
        _ = window_msg.DestroyIcon(handle);
        icon.bg_handle = null;
    }
}

/// create a platform icon.
pub fn createIcon(
    pixels: ?[]const u8,
    width: i32,
    height: i32,
) IconError!Icon {
    if (pixels) |slice| {
        const sm_handle = try createWin32Icon(slice, width, height, null, null);
        const bg_handle = try createWin32Icon(slice, width, height, null, null);
        return Icon{ .sm_handle = sm_handle, .bg_handle = bg_handle };
    } else {
        return Icon{ .sm_handle = null, .bg_handle = null };
    }
}

/// Creates a platform cursor.
pub fn createCursor(
    pixels: ?[]const u8,
    width: i32,
    height: i32,
    xhot: u32,
    yhot: u32,
) IconError!CursorHints {
    if (pixels) |slice| {
        const handle = try createWin32Icon(slice, width, height, xhot, yhot);
        return CursorHints{
            .image = handle,
            .shared = false,
            .mode = common.cursor.CursorMode.Normal,
        };
    } else {
        return CursorHints{
            .handle = null,
            .shared = false,
            .mode = common.cursor.CursorMode.Normal,
        };
    }
}

/// Returns a handle to a shared(standard) platform cursor.
pub fn createStandardCursor(
    shape: common.cursor.StandardCursorShape,
) IconError!CursorHints {
    const CursorShape = common.cursor.StandardCursorShape;

    const cursor_id = switch (shape) {
        CursorShape.PointingHand => win32.IDC_HAND,
        CursorShape.Crosshair => win32.IDC_CROSS,
        CursorShape.Text => win32.IDC_IBEAM,
        CursorShape.BkgrndTask => win32.IDC_APPSTARTING,
        CursorShape.Help => win32.IDC_HELP,
        CursorShape.Busy => win32.IDC_WAIT,
        CursorShape.Forbidden => win32.IDC_NO,
        CursorShape.Move => win32.IDC_SIZEALL,
        CursorShape.Default => win32.IDC_ARROW,
    };

    const handle = window_msg.LoadImageA(
        null,
        cursor_id,
        window_msg.GDI_IMAGE_TYPE.CURSOR,
        0,
        0,
        @enumFromInt(@intFromEnum(window_msg.LR_DEFAULTSIZE) |
            @intFromEnum(window_msg.LR_SHARED)),
    );

    if (handle == null) {
        // We failed.
        std.debug.print("error {}\n", .{utils.getLastError()});
        return error.FailedToLoadStdCursor;
    }

    return CursorHints{
        .image = @ptrCast(handle),
        .shared = true,
        .mode = common.cursor.CursorMode.Normal,
    };
}
