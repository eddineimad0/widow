const std = @import("std");
const common = @import("common");
const win32_defs = @import("win32api/defs.zig");
const win32 = std.os.windows;
const gdi = @import("win32api/gdi.zig");
const utils = @import("utils.zig");
const mem = std.mem;

pub const IconError = error{
    NotFound, // requested icon resource was not found.
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
) IconError!win32.HICON {
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

    var icon_info = gdi.ICONINFO{
        // A value of TRUE(1) specifies an icon, FALSE(0) specify a cursor.
        .fIcon = @intFromBool(!is_cursor),
        .xHotspot = xhot,
        .yHotspot = yhot,
        .hbmMask = monochrome_mask,
        .hbmColor = color_mask,
    };

    const icon_handle = gdi.CreateIconIndirect(&icon_info);

    return icon_handle orelse return IconError.BadIcon;
}

pub const CursorHints = struct {
    icon: ?win32.HCURSOR,
    // Track the cursor coordinates in respect to top left corner.
    pos: common.geometry.Point2D,
    // Accumulate the mouse movement
    accum_pos: common.geometry.Point2D,
    mode: common.cursor.CursorMode,
    sys_owned: bool, // As to avoid deleting system owned cursor images.
};

pub fn destroyCursorIcon(cursor: *CursorHints) void {
    if (!cursor.sys_owned and cursor.icon != null) {
        _ = gdi.DestroyCursor(cursor.icon);
        cursor.icon = null;
    }
}

pub const Icon = struct {
    sm_handle: ?win32.HICON,
    bg_handle: ?win32.HICON,
};

pub fn destroyIcon(icon: *Icon) void {
    if (icon.sm_handle) |handle| {
        _ = gdi.DestroyIcon(handle);
        icon.sm_handle = null;
    }

    if (icon.bg_handle) |handle| {
        _ = gdi.DestroyIcon(handle);
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
        const sm_handle = try createWin32Icon(
            slice,
            width,
            height,
            0,
            0,
            false,
        );
        const bg_handle = try createWin32Icon(
            slice,
            width,
            height,
            0,
            0,
            false,
        );
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
        const handle = try createWin32Icon(slice, width, height, xhot, yhot, true);
        return CursorHints{
            .icon = handle,
            .sys_owned = false,
            .mode = common.cursor.CursorMode.Normal,
            .pos = .{ .x = 0, .y = 0 },
            .accum_pos = .{ .x = 0, .y = 0 },
        };
    } else {
        return CursorHints{
            .icon = null,
            .sys_owned = false,
            .mode = common.cursor.CursorMode.Normal,
            .pos = .{ .x = 0, .y = 0 },
            .accum_pos = .{ .x = 0, .y = 0 },
        };
    }
}

/// Returns a handle to a shared(standard) platform cursor.
pub fn createNativeCursor(
    shape: common.cursor.NativeCursorShape,
) IconError!CursorHints {
    const CursorShape = common.cursor.NativeCursorShape;

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

    const handle = gdi.LoadImageA(
        null,
        cursor_id,
        gdi.GDI_IMAGE_TYPE.CURSOR,
        0,
        0,
        gdi.IMAGE_FLAGS{ .SHARED = 1, .DEFAULTSIZE = 1 },
    );

    if (handle == null) {
        // We failed.
        std.debug.print("error {}\n", .{utils.getLastError()});
        return IconError.NotFound;
    }

    return CursorHints{
        .icon = @ptrCast(handle),
        .sys_owned = true,
        .mode = common.cursor.CursorMode.Normal,
        .pos = .{ .x = 0, .y = 0 },
        .accum_pos = .{ .x = 0, .y = 0 },
    };
}
