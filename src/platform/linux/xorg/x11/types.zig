const builtin = @import("builtin");
const endian = builtin.target.cpu.arch.endian();

pub const XID = c_ulong;
pub const Time = c_ulong;
pub const Mask = c_ulong;
pub const Bool = c_int;
pub const Status = Bool;
pub const Window = XID;
pub const Pixmap = XID;
pub const Atom = XID;
pub const GContext = XID;
pub const Font = XID;
pub const VisualID = XID;
pub const Colormap = XID;
pub const Cursor = XID;
pub const KeySym = XID;
pub const KeyCode = u8;
pub const _XDisplay = opaque {};
pub const _XPrivate = opaque {};
pub const _XGC = opaque {};
pub const _XrmHashBucketRec = opaque {};
pub const Display = _XDisplay;
pub const XPointer = ?[*]u8;

pub const XExtData = extern struct {
    number: c_int,
    next: ?[*]XExtData,
    free_private: ?*fn (?[*]XExtData) callconv(.C) c_int,
    private_data: XPointer,
};

pub const Depth = extern struct {
    depth: c_int,
    nvisuals: c_int,
    visuals: ?[*]Visual,
};

pub const Screen = extern struct {
    ext_data: ?[*]XExtData,
    display: ?_XDisplay,
    root: Window,
    width: c_int,
    height: c_int,
    mwidth: c_int,
    mheight: c_int,
    ndepths: c_int,
    depths: ?[*]Depth,
    root_depth: c_int,
    root_visual: ?[*]Visual,
    default_gc: _XGC,
    cmap: Colormap,
    white_pixel: c_ulong,
    black_pixel: c_ulong,
    max_maps: c_int,
    min_maps: c_int,
    backing_store: c_int,
    save_unders: c_int,
    root_input_mask: c_long,
};

pub const ScreenFormat = extern struct {
    ext_data: ?[*]XExtData,
    depth: c_int,
    bits_per_pixel: c_int,
    scanline_pad: c_int,
};

pub const _XPrivDisplay = extern struct {
    ext_data: ?[*]XExtData,
    private1: ?*_XPrivate,
    fd: c_int,
    private2: c_int,
    proto_major_version: c_int,
    proto_minor_version: c_int,
    vendor: ?[*]u8,
    private3: XID,
    private4: XID,
    private5: XID,
    private6: c_int,
    resource_alloc: ?*fn (?*_XDisplay) callconv(.C) XID,
    byte_order: c_int,
    bitmap_unit: c_int,
    bitmap_pad: c_int,
    bitmap_bit_order: c_int,
    nformats: c_int,
    pixmap_format: ?[*]ScreenFormat,
    private8: c_int,
    release: c_int,
    private9: ?*_XPrivate,
    private10: ?*_XPrivate,
    qlen: c_int,
    last_request_read: c_ulong,
    request: c_ulong,
    private11: XPointer,
    private12: XPointer,
    private13: XPointer,
    private14: XPointer,
    max_request_size: c_uint,
    db: ?*_XrmHashBucketRec,
    private15: ?*fn (?*_XDisplay) callconv(.C) c_int,
    display_name: ?[*]u8,
    default_screen: c_int,
    nscreens: c_int,
    screens: ?[*]Screen,
    motion_buffer: c_ulong,
    private16: c_ulong,
    min_keycode: c_int,
    max_keycode: c_int,
    private17: XPointer,
    private18: XPointer,
    private19: c_int,
    xdefaults: ?[*]u8,
};

pub const XSetWindowAttributes = extern struct {
    background_pixmap: Pixmap,
    background_pixel: c_ulong,
    border_pixmap: Pixmap,
    border_pixel: c_ulong,
    bit_gravity: c_int,
    win_gravity: c_int,
    backing_store: c_int,
    backing_planes: c_ulong,
    backing_pixel: c_ulong,
    save_under: c_int,
    event_mask: c_long,
    do_not_propagate_mask: c_long,
    override_redirect: c_int,
    colormap: Colormap,
    cursor: Cursor,
};

pub const Visual = extern struct {
    ext_data: ?[*]XExtData,
    visualid: VisualID,
    class: c_int,
    red_mask: c_ulong,
    green_mask: c_ulong,
    blue_mask: c_ulong,
    bits_per_rgb: c_int,
    map_entries: c_int,
};
