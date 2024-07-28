const types = @import("../types.zig");

pub const XcursorBool = c_int;
pub const XcursorUInt = u32;
pub const XcursorDim = XcursorUInt;
pub const XcursorPixel = XcursorUInt;

pub const XcursorImage = extern struct {
    version: XcursorUInt,
    size: XcursorDim,
    width: XcursorDim,
    height: XcursorDim,
    xhot: XcursorDim,
    yhot: XcursorDim,
    delay: XcursorUInt,
    pixels: [*]XcursorPixel,
};

pub const XcursorImages = extern struct {
    nimages: c_int,
    images: ?[*]?*XcursorImage,
    name: ?[*:0]u8,
};

pub const XcursorCursors = extern struct {
    dpy: *types.Display,
    ref: c_int,
    ncursor: c_int,
    cursors: ?[*]types.Cursor,
};

pub const XcursorAnimate = extern struct {
    cursors: ?[*]XcursorCursors,
    sequence: c_int,
};

pub const XcursorFile = extern struct {
    closure: ?*anyopaque,
    read: *const fn (file: ?*@This(), buf: ?[*]u8, len: c_int) callconv(.C) c_int,
    write: *const fn (file: ?*@This(), buf: ?[*]u8, len: c_int) callconv(.C) c_int,
    seek: *const fn (file: ?*@This(), offset: c_long, whence: c_int) callconv(.C) c_int,
};

pub const XcursorImageCreateProc = *const fn (
    width: c_int,
    height: c_int,
) callconv(.C) ?*XcursorImage;
pub const XcursorImageDestroyProc = *const fn (
    image: *XcursorImage,
) callconv(.C) void;
pub const XcursorLibraryLoadImageProc = *const fn (
    name: [*:0]const u8,
    theme: [*:0]const u8,
    size: c_int,
) callconv(.C) ?*XcursorImage;
pub const XcursorGetThemeProc = *const fn (
    dpy: ?*types.Display,
) callconv(.C) ?[*:0]const u8;
pub const XcursorGetDefaultSizeProc = *const fn (
    dpy: ?*types.Display,
) callconv(.C) c_int;
pub const XcursorImageLoadCursorProc = *const fn (
    dpy: ?*types.Display,
    image: ?*const XcursorImage,
) callconv(.C) c_ulong;
