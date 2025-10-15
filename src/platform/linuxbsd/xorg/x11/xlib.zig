const std = @import("std");
const builtin = @import("builtin");
const endian = builtin.target.cpu.arch.endian();
//=====================
// Types
//====================
pub const XID = c_ulong;
pub const Time = c_ulong;
pub const Mask = c_ulong;
pub const Bool = c_int;
pub const XContext = c_int;
pub const XrmQuark = c_int;
pub const Status = Bool;
pub const Window = XID;
pub const Drawable = XID;
pub const Pixmap = XID;
pub const Atom = XID;
pub const GContext = XID;
pub const Font = XID;
pub const VisualID = XID;
pub const Colormap = XID;
pub const Cursor = XID;
pub const KeySym = XID;
pub const KeyCode = u8;
pub const CARD32 = u32;
const _XDisplay = opaque {};
const _XPrivate = opaque {};
const _XGC = opaque {};
const _XrmDatabase = opaque {};
pub const XrmDatabase = ?*_XrmDatabase;
pub const GC = ?*_XGC;
const _XrmHashBucketRec = opaque {};
pub const Display = _XDisplay;
pub const XPointer = ?[*]u8;

pub const XExtData = extern struct {
    number: c_int,
    next: ?[*]XExtData,
    free_private: ?*const fn (?[*]XExtData) callconv(.c) c_int,
    private_data: XPointer,
};

pub const XExtCodes = extern struct {
    extension: c_int,
    major_opcode: c_int,
    first_event: c_int,
    first_error: c_int,
};
pub const XrmValue = extern struct {
    size: c_uint,
    addr: XPointer,
};

pub const Depth = extern struct {
    depth: c_int,
    nvisuals: c_int,
    visuals: ?[*]Visual,
};

pub const Screen = extern struct {
    ext_data: ?[*]XExtData,
    display: ?*_XDisplay,
    root: Window,
    width: c_int,
    height: c_int,
    mwidth: c_int,
    mheight: c_int,
    ndepths: c_int,
    depths: ?[*]Depth,
    root_depth: c_int,
    root_visual: ?*Visual,
    default_gc: GC,
    cmap: Colormap,
    white_pixel: c_ulong,
    black_pixel: c_ulong,
    max_maps: c_int,
    min_maps: c_int,
    backing_store: c_int,
    save_unders: c_int,
    root_input_mask: c_long,
};

pub const XGCValues = extern struct {
    function: c_int, // logical operation
    plane_mask: c_ulong, // plane mask
    foreground: c_ulong, // foreground pixel
    background: c_ulong, // background pixel
    line_width: c_int, // line width (in pixels)
    line_style: c_int, // LineSolid, LineOnOffDash, LineDoubleDash
    cap_style: c_int, // CapNotLast, CapButt, CapRound, CapProjecting,
    join_style: c_int, // JoinMiter, JoinRound, JoinBevel
    fill_style: c_int, // FillSolid, FillTiled, FillStippled FillOpaqueStippled
    fill_rule: c_int, // EvenOddRule, WindingRule
    arc_mode: c_int, // ArcChord, ArcPieSlice
    tile: Pixmap, // tile pixmap for tiling operations
    stipple: Pixmap, // stipple 1 plane pixmap for stippling
    ts_x_origin: c_int, // offset for tile or stipple operations
    ts_y_origin: c_int,
    font: Font, // default text font for text operations
    subwindow_mode: c_int, // ClipByChildren, IncludeInferiors
    graphics_exposures: Bool, // boolean, should exposures be generated
    clip_x_origin: c_int, // origin for clipping
    clip_y_origin: c_int,
    clip_mask: Pixmap, // bitmap clipping; other calls for rects
    dash_offset: c_int, // patterned/dashed line information
    dashes: u8,
};

pub const XImage = extern struct {
    width: c_int, // size of image
    height: c_int,
    xoffset: c_int, // number of pixels offset in x diretion
    format: c_int, // XYBitmap, XYPixmap, ZPixmap
    data: ?[*]u8, // pointer to image data
    byte_order: c_int, // data byte rder LSBFirst, MSBFirst
    bitmap_unit: c_int, // quant of scanline 8, 16, 32
    bitmap_bit_order: c_int, // LSBFirst, MSBFirst
    bitmap_pad: c_int, // 8, 16 32 either XY or ZPixmap
    depth: c_int, // depth of image
    bytes_per_line: c_int, // accelerator to next scanline
    bits_per_pixel: c_int, // bits per pixel (ZPixmap)
    red_mask: c_ulong, // bits in z arrangement
    green_mask: c_ulong,
    blue_mask: c_ulong,
    obdata: XPointer, // hook for the object routines to hang on
    f: extern struct { // image manipulation routines
        create_image: *const fn () callconv(.c) ?*XImage,
        destroy_image: *const fn () callconv(.c) c_int,
        get_pixel: *const fn () callconv(.c) c_ulong,
        put_pixel: *const fn () callconv(.c) c_int,
        sub_image: *const fn () callconv(.c) ?*XImage,
        add_pixel: *const fn () callconv(.c) c_int,
    },
};

pub const XPixmapFormatValues = extern struct {
    depth: c_int,
    bits_per_pixel: c_int,
    scanline_pad: c_int,
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
    resource_alloc: ?*const fn (?*_XDisplay) callconv(.c) XID,
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
    private15: ?*const fn (?*_XDisplay) callconv(.c) c_int,
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

pub const XWindowAttributes = extern struct {
    x: c_int,
    y: c_int, // location of window
    width: c_int,
    height: c_int, // width and height of window */
    border_width: c_int, // border width of window */
    depth: c_int, // depth of window */
    visual: ?*Visual, // the associated visual structure */
    root: Window, // root of screen containing window */
    class: c_int, // InputOutput, InputOnly*/
    bit_gravity: c_int, // one of the bit gravity values */
    win_gravity: c_int, // one of the window gravity values */
    backing_store: c_int, // NotUseful, WhenMapped, Always */
    backing_planes: c_ulong, // planes to be preserved if possible */
    backing_pixel: c_ulong, // value to be used when restoring planes */
    save_under: Bool, // boolean, should bits under be saved? */
    colormap: Colormap, // color map to be associated with window */
    map_installed: Bool, // boolean, is color map currently installed*/
    map_state: c_int, // IsUnmapped, IsUnviewable, IsViewable */
    all_event_masks: c_long, // set of events all people have interest in*/
    your_event_mask: c_long, // my event mask */
    do_not_propagate_mask: c_long, // set of events that should not propagate */
    override_redirect: bool, // boolean value for override-redirect */
    screen: ?*Screen, // back pointer to correct screen */
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

pub const XVisualInfo = extern struct {
    visual: ?*Visual,
    visualid: VisualID,
    screen: c_int,
    depth: c_int,
    class: c_int,
    red_mask: c_ulong,
    green_mask: c_ulong,
    blue_mask: c_ulong,
    colormap_size: c_int,
    bits_per_rgb: c_int,
};

pub const XAnyEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
};

pub const XKeyEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    keycode: c_uint,
    same_screen: c_int,
};
pub const XKeyPressedEvent = XKeyEvent;
pub const XKeyReleasedEvent = XKeyEvent;
pub const XButtonEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    button: c_uint,
    same_screen: c_int,
};
pub const XButtonPressedEvent = XButtonEvent;
pub const XButtonReleasedEvent = XButtonEvent;
pub const XMotionEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    is_hint: u8,
    same_screen: c_int,
};
pub const XPointerMovedEvent = XMotionEvent;
pub const XCrossingEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    mode: c_int,
    detail: c_int,
    same_screen: c_int,
    focus: c_int,
    state: c_uint,
};
pub const XEnterWindowEvent = XCrossingEvent;
pub const XLeaveWindowEvent = XCrossingEvent;
pub const XFocusChangeEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    mode: c_int,
    detail: c_int,
};
pub const XFocusInEvent = XFocusChangeEvent;
pub const XFocusOutEvent = XFocusChangeEvent;
pub const XKeymapEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    key_vector: [32]u8,
};
pub const XExposeEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    count: c_int,
};
pub const XGraphicsExposeEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    drawable: Drawable,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    count: c_int,
    major_code: c_int,
    minor_code: c_int,
};
pub const XNoExposeEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    drawable: Drawable,
    major_code: c_int,
    minor_code: c_int,
};
pub const XVisibilityEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    state: c_int,
};
pub const XCreateWindowEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    parent: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    override_redirect: c_int,
};
pub const XDestroyWindowEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
};
pub const XUnmapEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    from_configure: c_int,
};
pub const XMapEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    override_redirect: c_int,
};
pub const XMapRequestEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    parent: Window,
    window: Window,
};
pub const XReparentEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    parent: Window,
    x: c_int,
    y: c_int,
    override_redirect: c_int,
};
pub const XConfigureEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    above: Window,
    override_redirect: c_int,
};
pub const XGravityEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    x: c_int,
    y: c_int,
};
pub const XResizeRequestEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    width: c_int,
    height: c_int,
};
pub const XConfigureRequestEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    parent: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    above: Window,
    detail: c_int,
    value_mask: c_ulong,
};
pub const XCirculateEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    event: Window,
    window: Window,
    place: c_int,
};
pub const XCirculateRequestEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    parent: Window,
    window: Window,
    place: c_int,
};
pub const XWMHints = extern struct {
    flags: c_long,
    input: c_int,
    initial_state: c_int,
    icon_pixmap: Pixmap,
    icon_window: Window,
    icon_x: c_int,
    icon_y: c_int,
    icon_mask: Pixmap,
    window_group: XID,
};
pub const XComposeStatus = extern struct {
    compose_ptr: XPointer,
    chars_matched: c_int,
};

pub const XSizeHints = extern struct {
    flags: c_long,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    width_inc: c_int,
    height_inc: c_int,
    min_aspect: extern struct {
        x: c_int,
        y: c_int,
    },
    max_aspect: extern struct {
        x: c_int,
        y: c_int,
    },
    base_width: c_int,
    base_height: c_int,
    win_gravity: c_int,
};
pub const XIconSize = extern struct {
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    width_inc: c_int,
    height_inc: c_int,
};
pub const XClassHint = extern struct {
    res_name: ?[*]const u8,
    res_class: ?[*]const u8,
};
pub const XStandardColormap = extern struct {
    colormap: Colormap,
    red_max: c_ulong,
    red_mult: c_ulong,
    green_max: c_ulong,
    green_mult: c_ulong,
    blue_max: c_ulong,
    blue_mult: c_ulong,
    base_pixel: c_ulong,
    visualid: VisualID,
    killid: XID,
};
pub const XPropertyEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    atom: Atom,
    time: Time,
    state: c_int,
};
pub const XSelectionClearEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    selection: Atom,
    time: Time,
};
pub const XSelectionRequestEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    owner: Window,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};
pub const XSelectionEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};
pub const XColormapEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    colormap: Colormap,
    new: c_int,
    state: c_int,
};
pub const XClientMessageEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    message_type: Atom,
    format: c_int,
    data: extern union {
        b: [20]u8,
        s: [10]c_short,
        l: [5]c_long,
    },
};
pub const XMappingEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    window: Window,
    request: c_int,
    first_keycode: c_int,
    count: c_int,
};
pub const XErrorEvent = extern struct {
    type: c_int,
    display: ?*Display,
    resourceid: XID,
    serial: c_ulong,
    error_code: u8,
    request_code: u8,
    minor_code: u8,
};
pub const XGenericEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    extension: c_int,
    evtype: c_int,
};
pub const XGenericEventCookie = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: ?*Display,
    extension: c_int,
    evtype: c_int,
    cookie: c_uint,
    data: ?*anyopaque,
};
pub const XEvent = extern union {
    type: c_int,
    xany: XAnyEvent,
    xkey: XKeyEvent,
    xbutton: XButtonEvent,
    xmotion: XMotionEvent,
    xcrossing: XCrossingEvent,
    xfocus: XFocusChangeEvent,
    xexpose: XExposeEvent,
    xgraphicsexpose: XGraphicsExposeEvent,
    xnoexpose: XNoExposeEvent,
    xvisibility: XVisibilityEvent,
    xcreatewindow: XCreateWindowEvent,
    xdestroywindow: XDestroyWindowEvent,
    xunmap: XUnmapEvent,
    xmap: XMapEvent,
    xmaprequest: XMapRequestEvent,
    xreparent: XReparentEvent,
    xconfigure: XConfigureEvent,
    xgravity: XGravityEvent,
    xresizerequest: XResizeRequestEvent,
    xconfigurerequest: XConfigureRequestEvent,
    xcirculate: XCirculateEvent,
    xcirculaterequest: XCirculateRequestEvent,
    xproperty: XPropertyEvent,
    xselectionclear: XSelectionClearEvent,
    xselectionrequest: XSelectionRequestEvent,
    xselection: XSelectionEvent,
    xcolormap: XColormapEvent,
    xclient: XClientMessageEvent,
    xmapping: XMappingEvent,
    xerror: XErrorEvent,
    xkeymap: XKeymapEvent,
    xgeneric: XGenericEvent,
    xcookie: XGenericEventCookie,
    pad: [24]c_long,
};

pub const XErrorHandlerFunc = fn (display: ?*Display, err: *XErrorEvent) callconv(.c) c_int;
//=====================
// constants
//=====================
pub const AllocNone = 0;
pub const AllocAll = 1;

pub const XA_PRIMARY = 1;
pub const XA_SECONDARY = 2;
pub const XA_ARC = 3;
pub const XA_ATOM = 4;
pub const XA_BITMAP = 5;
pub const XA_CARDINAL = 6;
pub const XA_COLORMAP = 7;
pub const XA_CURSOR = 8;
pub const XA_CUT_BUFFER0 = 9;
pub const XA_CUT_BUFFER1 = 10;
pub const XA_CUT_BUFFER2 = 11;
pub const XA_CUT_BUFFER3 = 12;
pub const XA_CUT_BUFFER4 = 13;
pub const XA_CUT_BUFFER5 = 14;
pub const XA_CUT_BUFFER6 = 15;
pub const XA_CUT_BUFFER7 = 16;
pub const XA_DRAWABLE = 17;
pub const XA_FONT = 18;
pub const XA_INTEGER = 19;
pub const XA_PIXMAP = 20;
pub const XA_POINT = 21;
pub const XA_RECTANGLE = 22;
pub const XA_RESOURCE_MANAGER = 23;
pub const XA_RGB_COLOR_MAP = 24;
pub const XA_RGB_BEST_MAP = 25;
pub const XA_RGB_BLUE_MAP = 26;
pub const XA_RGB_DEFAULT_MAP = 27;
pub const XA_RGB_GRAY_MAP = 28;
pub const XA_RGB_GREEN_MAP = 29;
pub const XA_RGB_RED_MAP = 30;
pub const XA_STRING = 31;
pub const XA_VISUALID = 32;
pub const XA_WINDOW = 33;
pub const XA_WM_COMMAND = 34;
pub const XA_WM_HINTS = 35;
pub const XA_WM_CLIENT_MACHINE = 36;
pub const XA_WM_ICON_NAME = 37;
pub const XA_WM_ICON_SIZE = 38;
pub const XA_WM_NAME = 39;
pub const XA_WM_NORMAL_HINTS = 40;
pub const XA_WM_SIZE_HINTS = 41;
pub const XA_WM_ZOOM_HINTS = 42;
pub const XA_MIN_SPACE = 43;
pub const XA_NORM_SPACE = 44;
pub const XA_MAX_SPACE = 45;
pub const XA_END_SPACE = 46;
pub const XA_SUPERSCRIPT_X = 47;
pub const XA_SUPERSCRIPT_Y = 48;
pub const XA_SUBSCRIPT_X = 49;
pub const XA_SUBSCRIPT_Y = 50;
pub const XA_UNDERLINE_POSITION = 51;
pub const XA_UNDERLINE_THICKNESS = 52;
pub const XA_STRIKEOUT_ASCENT = 53;
pub const XA_STRIKEOUT_DESCENT = 54;
pub const XA_ITALIC_ANGLE = 55;
pub const XA_X_HEIGHT = 56;
pub const XA_QUAD_WIDTH = 57;
pub const XA_WEIGHT = 58;
pub const XA_POINT_SIZE = 59;
pub const XA_RESOLUTION = 60;
pub const XA_COPYRIGHT = 61;
pub const XA_NOTICE = 62;
pub const XA_FONT_NAME = 63;
pub const XA_FAMILY_NAME = 64;
pub const XA_FULL_NAME = 65;
pub const XA_CAP_HEIGHT = 66;
pub const XA_WM_CLASS = 67;
pub const XA_WM_TRANSIENT_FOR = 68;

// boolean values
pub const False = 0;
pub const True = 1;

// clip rect ordering
pub const Unsorted = 0;
pub const YSorted = 1;
pub const YXSorted = 2;
pub const YXBanded = 3;

// color component mask
pub const DoRed = 1;
pub const DoGreen = 2;
pub const DoBlue = 4;

// error codes
pub const Success = 0;
pub const BadRequest = 1;
pub const BadValue = 2;
pub const BadWindow = 3;
pub const BadPixmap = 4;
pub const BadAtom = 5;
pub const BadCursor = 6;
pub const BadFont = 7;
pub const BadMatch = 8;
pub const BadDrawable = 9;
pub const BadAccess = 10;
pub const BadAlloc = 11;
pub const BadColor = 12;
pub const BadGC = 13;
pub const BadIDChoice = 14;
pub const BadName = 15;
pub const BadLength = 16;
pub const BadImplementation = 17;
pub const FirstExtensionError = 128;
pub const LastExtensionError = 255;

// event kinds
pub const KeyPress = 2;
pub const KeyRelease = 3;
pub const ButtonPress = 4;
pub const ButtonRelease = 5;
pub const MotionNotify = 6;
pub const EnterNotify = 7;
pub const LeaveNotify = 8;
pub const FocusIn = 9;
pub const FocusOut = 10;
pub const KeymapNotify = 11;
pub const Expose = 12;
pub const GraphicsExpose = 13;
pub const NoExpose = 14;
pub const VisibilityNotify = 15;
pub const CreateNotify = 16;
pub const DestroyNotify = 17;
pub const UnmapNotify = 18;
pub const MapNotify = 19;
pub const MapRequest = 20;
pub const ReparentNotify = 21;
pub const ConfigureNotify = 22;
pub const ConfigureRequest = 23;
pub const GravityNotify = 24;
pub const ResizeRequest = 25;
pub const CirculateNotify = 26;
pub const CirculateRequest = 27;
pub const PropertyNotify = 28;
pub const SelectionClear = 29;
pub const SelectionRequest = 30;
pub const SelectionNotify = 31;
pub const ColormapNotify = 32;
pub const ClientMessage = 33;
pub const MappingNotify = 34;
pub const GenericEvent = 35;
pub const LASTEvent = 36;

// event mask
pub const NoEventMask = 0;
pub const KeyPressMask = 0x0000_0001;
pub const KeyReleaseMask = 0x0000_0002;
pub const ButtonPressMask = 0x0000_0004;
pub const ButtonReleaseMask = 0x0000_0008;
pub const EnterWindowMask = 0x0000_0010;
pub const LeaveWindowMask = 0x0000_0020;
pub const PointerMotionMask = 0x0000_0040;
pub const PointerMotionHintMask = 0x0000_0080;
pub const Button1MotionMask = 0x0000_0100;
pub const Button2MotionMask = 0x0000_0200;
pub const Button3MotionMask = 0x0000_0400;
pub const Button4MotionMask = 0x0000_0800;
pub const Button5MotionMask = 0x0000_1000;
pub const ButtonMotionMask = 0x0000_2000;
pub const KeymapStateMask = 0x0000_4000;
pub const ExposureMask = 0x0000_8000;
pub const VisibilityChangeMask = 0x0001_0000;
pub const StructureNotifyMask = 0x0002_0000;
pub const ResizeRedirectMask = 0x0004_0000;
pub const SubstructureNotifyMask = 0x0008_0000;
pub const SubstructureRedirectMask = 0x0010_0000;
pub const FocusChangeMask = 0x0020_0000;
pub const PropertyChangeMask = 0x0040_0000;
pub const ColormapChangeMask = 0x0080_0000;
pub const OwnerGrabButtonMask = 0x0100_0000;
pub const QueuedAlready = 0;
pub const QueuedAfterReading = 1;
pub const QueuedAfterFlush = 2;

// property modes
pub const PropModeReplace = 0;
pub const PropModePrepend = 1;
pub const PropModeAppend = 2;

// modifier names
pub const ShiftMapIndex = 0;
pub const LockMapIndex = 1;
pub const ControlMapIndex = 2;
pub const Mod1MapIndex = 3;
pub const Mod2MapIndex = 4;
pub const Mod3MapIndex = 5;
pub const Mod4MapIndex = 6;
pub const Mod5MapIndex = 7;

// button masks
pub const Button1Mask = 1 << 8;
pub const Button2Mask = 1 << 9;
pub const Button3Mask = 1 << 10;
pub const Button4Mask = 1 << 11;
pub const Button5Mask = 1 << 12;
pub const AnyModifier = 1 << 15;

// Notify modes
pub const NotifyNormal = 0;
pub const NotifyGrab = 1;
pub const NotifyUngrab = 2;
pub const NotifyWhileGrabbed = 3;

pub const NotifyHint = 1;

// Notify detail
pub const NotifyAncestor = 0;
pub const NotifyVirtual = 1;
pub const NotifyInferior = 2;
pub const NotifyNonlinear = 3;
pub const NotifyNonlinearVirtual = 4;
pub const NotifyPointer = 5;
pub const NotifyPointerRoot = 6;
pub const NotifyDetailNone = 7;

// Visibility notify
pub const VisibilityUnobscured = 0;
pub const VisibilityPartiallyObscured = 1;
pub const VisibilityFullyObscured = 2;

// Circulation request
pub const PlaceOnTop = 0;
pub const PlaceOnBottom = 1;

// protocol families
pub const FamilyInternet = 0;
pub const FamilyDECnet = 1;
pub const FamilyChaos = 2;
pub const FamilyInternet6 = 6;

// authentication families not tied to a specific protocol
pub const FamilyServerInterpreted = 5;

// property notification
pub const PropertyNewValue = 0;
pub const PropertyDelete = 1;

// Color Map notification
pub const ColormapUninstalled = 0;
pub const ColormapInstalled = 1;

// grab modes
pub const GrabModeSync = 0;
pub const GrabModeAsync = 1;

// grab status
pub const GrabSuccess = 0;
pub const AlreadyGrabbed = 1;
pub const GrabInvalidTime = 2;
pub const GrabNotViewable = 3;
pub const GrabFrozen = 4;

// AllowEvents modes
pub const AsyncPointer = 0;
pub const SyncPointer = 1;
pub const ReplayPointer = 2;
pub const AsyncKeyboard = 3;
pub const SyncKeyboard = 4;
pub const ReplayKeyboard = 5;
pub const AsyncBoth = 6;
pub const SyncBoth = 7;

// Used in SetInputFocus, GetInputFocus
pub const RevertToNone = 0;
pub const RevertToPointerRoot = 1;
pub const RevertToParent = 2;

// ConfigureWindow structure
pub const CWX = 1 << 0;
pub const CWY = 1 << 1;
pub const CWWidth = 1 << 2;
pub const CWHeight = 1 << 3;
pub const CWBorderWidth = 1 << 4;
pub const CWSibling = 1 << 5;
pub const CWStackMode = 1 << 6;

// gravity
pub const ForgetGravity = 0;
pub const UnmapGravity = 0;
pub const NorthWestGravity = 1;
pub const NorthGravity = 2;
pub const NorthEastGravity = 3;
pub const WestGravity = 4;
pub const CenterGravity = 5;
pub const EastGravity = 6;
pub const SouthWestGravity = 7;
pub const SouthGravity = 8;
pub const SouthEastGravity = 9;
pub const StaticGravity = 10;

// image format
pub const XYBitmap = 0;
pub const XYPixmap = 1;
pub const ZPixmap = 2;

// Used in CreateWindow for backing-store hint
pub const NotUseful = 0;
pub const WhenMapped = 1;
pub const Always = 2;

// map state
pub const IsUnmapped = 0;
pub const IsUnviewable = 1;
pub const IsViewable = 2;

// modifier keys mask
pub const ShiftMask = 0x01;
pub const LockMask = 0x02;
pub const ControlMask = 0x04;
pub const Mod1Mask = 0x08;
pub const Mod2Mask = 0x10;
pub const Mod3Mask = 0x20;
pub const Mod4Mask = 0x40;
pub const Mod5Mask = 0x80;

pub const Button1 = 1;
pub const Button2 = 2;
pub const Button3 = 3;
pub const Button4 = 4;
pub const Button5 = 5;
pub const Button6 = 6;
pub const Button7 = 7;

pub const USPosition = 0x0001;
pub const USSize = 0x0002;
pub const PPosition = 0x0004;
pub const PSize = 0x0008;
pub const PMinSize = 0x0010;
pub const PMaxSize = 0x0020;
pub const PResizeInc = 0x0040;
pub const PAspect = 0x0080;
pub const PBaseSize = 0x0100;
pub const PWinGravity = 0x0200;
pub const PAllHints = PPosition | PSize | PMinSize | PMaxSize | PResizeInc | PAspect;

pub const SetModeInsert = 0;
pub const SetModeDelete = 1;

pub const DestroyAll = 0;
pub const RetainPermanent = 1;
pub const RetainTemporary = 2;

pub const Above = 0;
pub const Below = 1;
pub const TopIf = 2;
pub const BottomIf = 3;
pub const Opposite = 4;

pub const RaiseLowest = 0;
pub const LowerHighest = 1;

pub const GXclear = 0x0;
pub const GXand = 0x1;
pub const GXandReverse = 0x2;
pub const GXcopy = 0x3;
pub const GXandInverted = 0x4;
pub const GXnoop = 0x5;
pub const GXxor = 0x6;
pub const GXor = 0x7;
pub const GXnor = 0x8;
pub const GXequiv = 0x9;
pub const GXinvert = 0xa;
pub const GXorReverse = 0xb;
pub const GXcopyInverted = 0xc;
pub const GXorInverted = 0xd;
pub const GXnand = 0xe;
pub const GXset = 0xf;

pub const LineSolid = 0;
pub const LineOnOffDash = 1;
pub const LineDoubleDash = 2;

pub const CapNotLast = 0;
pub const CapButt = 1;
pub const CapRound = 2;
pub const CapProjecting = 3;

pub const JoinMiter = 0;
pub const JoinRound = 1;
pub const JoinBevel = 2;

pub const FillSolid = 0;
pub const FillTiled = 1;
pub const FillStippled = 2;
pub const FillOpaqueStippled = 3;

pub const EvenOddRule = 0;
pub const WindingRule = 1;

pub const ClipByChildren = 0;
pub const IncludeInferiors = 1;

pub const CoordModeOrigin = 0;
pub const CoordModePrevious = 1;

pub const Complex = 0;
pub const Nonconvex = 1;
pub const Convex = 2;

pub const ArcChord = 0;
pub const ArcPieSlice = 1;

pub const GCFunction = 1 << 0;
pub const GCPlaneMask = 1 << 1;
pub const GCForeground = 1 << 2;
pub const GCBackground = 1 << 3;
pub const GCLineWidth = 1 << 4;
pub const GCLineStyle = 1 << 5;
pub const GCCapStyle = 1 << 6;
pub const GCJoinStyle = 1 << 7;
pub const GCFillStyle = 1 << 8;
pub const GCFillRule = 1 << 9;
pub const GCTile = 1 << 10;
pub const GCStipple = 1 << 11;
pub const GCTileStipXOrigin = 1 << 12;
pub const GCTileStipYOrigin = 1 << 13;
pub const GCFont = 1 << 14;
pub const GCSubwindowMode = 1 << 15;
pub const GCGraphicsExposures = 1 << 16;
pub const GCClipXOrigin = 1 << 17;
pub const GCClipYOrigin = 1 << 18;
pub const GCClipMask = 1 << 19;
pub const GCDashOffset = 1 << 20;
pub const GCDashList = 1 << 21;
pub const GCArcMode = 1 << 22;

pub const GCLastBit = 22;

pub const FontLeftToRight = 0;
pub const FontRightToLeft = 1;

pub const FontChange = 255;

pub const CursorShape = 0;
pub const TileShape = 1;
pub const StippleShape = 2;

pub const AutoRepeatModeOff = 0;
pub const AutoRepeatModeOn = 1;
pub const AutoRepeatModeDefault = 2;

pub const LedModeOff = 0;
pub const LedModeOn = 1;

pub const KBKeyClickPercent = 1 << 0;
pub const KBBellPercent = 1 << 1;
pub const KBBellPitch = 1 << 2;
pub const KBBellDuration = 1 << 3;
pub const KBLed = 1 << 4;
pub const KBLedMode = 1 << 5;
pub const KBKey = 1 << 6;
pub const KBAutoRepeatMode = 1 << 7;

pub const MappingSuccess = 0;
pub const MappingBusy = 1;
pub const MappingFailed = 2;

pub const MappingModifier = 0;
pub const MappingKeyboard = 1;
pub const MappingPointer = 2;

pub const DontPreferBlanking = 0;
pub const PreferBlanking = 1;
pub const DefaultBlanking = 2;

pub const DisableScreenSaver = 0;
pub const DisableScreenInterval = 0;

pub const DontAllowExposures = 0;
pub const AllowExposures = 1;
pub const DefaultExposures = 2;

pub const ScreenSaverReset = 0;
pub const ScreenSaverActive = 1;

pub const HostInsert = 0;
pub const HostDelete = 1;

pub const EnableAccess = 1;
pub const DisableAccess = 0;

pub const StaticGray = 0;
pub const GrayScale = 1;
pub const StaticColor = 2;
pub const PseudoColor = 3;
pub const TrueColor = 4;
pub const DirectColor = 5;

pub const VisualNoMask = 0x0000;
pub const VisualIDMask = 0x0001;
pub const VisualScreenMask = 0x0002;
pub const VisualDepthMask = 0x0004;
pub const VisualClassMask = 0x0008;
pub const VisualRedMaskMask = 0x0010;
pub const VisualGreenMaskMask = 0x0020;
pub const VisualBlueMaskMask = 0x0040;
pub const VisualColormapSizeMask = 0x0080;
pub const VisualBitsPerRGBMask = 0x0100;
pub const VisualAllMask = 0x01ff;

pub const CWBackPixmap = 0x0001;
pub const CWBackPixel = 0x0002;
pub const CWBorderPixmap = 0x0004;
pub const CWBorderPixel = 0x0008;
pub const CWBitGravity = 0x0010;
pub const CWWinGravity = 0x0020;
pub const CWBackingStore = 0x0040;
pub const CWBackingPlanes = 0x0080;
pub const CWBackingPixel = 0x0100;
pub const CWOverrideRedirect = 0x0200;
pub const CWSaveUnder = 0x0400;
pub const CWEventMask = 0x0800;
pub const CWDontPropagate = 0x1000;
pub const CWColormap = 0x2000;
pub const CWCursor = 0x4000;

pub const InputOutput = 1;
pub const InputOnly = 2;

pub const XIMPreeditArea = 0x0001;
pub const XIMPreeditCallbacks = 0x0002;
pub const XIMPreeditPosition = 0x0004;
pub const XIMPreeditNothing = 0x0008;
pub const XIMPreeditNone = 0x0010;
pub const XIMStatusArea = 0x0100;
pub const XIMStatusCallbacks = 0x0200;
pub const XIMStatusNothing = 0x0400;
pub const XIMStatusNone = 0x0800;

pub const LSBFirst = 0;
pub const MSBFirst = 1;

pub const None = 0;
pub const ParentRelative = 1;
pub const CopyFromParent = 0;
pub const PointerWindow = 0;
pub const InputFocus = 1;
pub const PointerRoot = 1;
pub const AnyPropertyType = 0;
pub const AnyKey = 0;
pub const AnyButton = 0;
pub const AllTemporary = 0;
pub const CurrentTime = 0;
pub const NoSymbol = 0;

pub const X_PROTOCOL = 11;
pub const X_PROTOCOL_REVISION = 0;

pub const XNVaNestedList = "XNVaNestedList";
pub const XNQueryInputStyle = "queryInputStyle";
pub const XNClientWindow = "clientWindow";
pub const XNInputStyle = "inputStyle";
pub const XNFocusWindow = "focusWindow";
pub const XNResourceName = "resourceName";
pub const XNResourceClass = "resourceClass";
pub const XNGeometryCallback = "geometryCallback";
pub const XNDestroyCallback = "destroyCallback";
pub const XNFilterEvents = "filterEvents";
pub const XNPreeditStartCallback = "preeditStartCallback";
pub const XNPreeditDoneCallback = "preeditDoneCallback";
pub const XNPreeditDrawCallback = "preeditDrawCallback";
pub const XNPreeditCaretCallback = "preeditCaretCallback";
pub const XNPreeditStateNotifyCallback = "preeditStateNotifyCallback";
pub const XNPreeditAttributes = "preeditAttributes";
pub const XNStatusStartCallback = "statusStartCallback";
pub const XNStatusDoneCallback = "statusDoneCallback";
pub const XNStatusDrawCallback = "statusDrawCallback";
pub const XNStatusAttributes = "statusAttributes";
pub const XNArea = "area";
pub const XNAreaNeeded = "areaNeeded";
pub const XNSpotLocation = "spotLocation";
pub const XNColormap = "colorMap";
pub const XNStdColormap = "stdColorMap";
pub const XNForeground = "foreground";
pub const XNBackground = "background";
pub const XNBackgroundPixmap = "backgroundPixmap";
pub const XNFontSet = "fontSet";
pub const XNLineSpace = "lineSpace";
pub const XNCursor = "cursor";

pub const XNVaNestedList_0 = "XNVaNestedList";
pub const XNQueryInputStyle_0 = "queryInputStyle";
pub const XNClientWindow_0 = "clientWindow";
pub const XNInputStyle_0 = "inputStyle";
pub const XNFocusWindow_0 = "focusWindow";
pub const XNResourceName_0 = "resourceName";
pub const XNResourceClass_0 = "resourceClass";
pub const XNGeometryCallback_0 = "geometryCallback";
pub const XNDestroyCallback_0 = "destroyCallback";
pub const XNFilterEvents_0 = "filterEvents";
pub const XNPreeditStartCallback_0 = "preeditStartCallback";
pub const XNPreeditDoneCallback_0 = "preeditDoneCallback";
pub const XNPreeditDrawCallback_0 = "preeditDrawCallback";
pub const XNPreeditCaretCallback_0 = "preeditCaretCallback";
pub const XNPreeditStateNotifyCallback_0 = "preeditStateNotifyCallback";
pub const XNPreeditAttributes_0 = "preeditAttributes";
pub const XNStatusStartCallback_0 = "statusStartCallback";
pub const XNStatusDoneCallback_0 = "statusDoneCallback";
pub const XNStatusDrawCallback_0 = "statusDrawCallback";
pub const XNStatusAttributes_0 = "statusAttributes";
pub const XNArea_0 = "area";
pub const XNAreaNeeded_0 = "areaNeeded";
pub const XNSpotLocation_0 = "spotLocation";
pub const XNColormap_0 = "colorMap";
pub const XNStdColormap_0 = "stdColorMap";
pub const XNForeground_0 = "foreground";
pub const XNBackground_0 = "background";
pub const XNBackgroundPixmap_0 = "backgroundPixmap";
pub const XNFontSet_0 = "fontSet";
pub const XNLineSpace_0 = "lineSpace";
pub const XNCursor_0 = "cursor";

pub const XNQueryIMValuesList = "queryIMValuesList";
pub const XNQueryICValuesList = "queryICValuesList";
pub const XNVisiblePosition = "visiblePosition";
pub const XNR6PreeditCallback = "r6PreeditCallback";
pub const XNStringConversionCallback = "stringConversionCallback";
pub const XNStringConversion = "stringConversion";
pub const XNResetState = "resetState";
pub const XNHotKey = "hotKey";
pub const XNHotKeyState = "hotKeyState";
pub const XNPreeditState = "preeditState";
pub const XNSeparatorofNestedList = "separatorofNestedList";

pub const XNQueryIMValuesList_0 = "queryIMValuesList";
pub const XNQueryICValuesList_0 = "queryICValuesList";
pub const XNVisiblePosition_0 = "visiblePosition";
pub const XNR6PreeditCallback_0 = "r6PreeditCallback";
pub const XNStringConversionCallback_0 = "stringConversionCallback";
pub const XNStringConversion_0 = "stringConversion";
pub const XNResetState_0 = "resetState";
pub const XNHotKey_0 = "hotKey";
pub const XNHotKeyState_0 = "hotKeyState";
pub const XNPreeditState_0 = "preeditState";
pub const XNSeparatorofNestedList_0 = "separatorofNestedList";

pub const XBufferOverflow = -1;
pub const XLookupNone = 1;
pub const XLookupChars = 2;
pub const XLookupKeySym = 3;
pub const XLookupBoth = 4;

pub const NoValue = 0x0000;
pub const XValue = 0x0001;
pub const YValue = 0x0002;
pub const WidthValue = 0x0004;
pub const HeightValue = 0x0008;
pub const AllValues = 0x000f;
pub const XNegative = 0x0010;
pub const YNegative = 0x0020;

pub const InputHint = 1 << 0;
pub const StateHint = 1 << 1;
pub const IconPixmapHint = 1 << 2;
pub const IconWindowHint = 1 << 3;
pub const IconPositionHint = 1 << 4;
pub const IconMaskHint = 1 << 5;
pub const WindowGroupHint = 1 << 6;
pub const AllHints = InputHint |
    StateHint |
    IconPixmapHint |
    IconWindowHint |
    IconPositionHint |
    IconMaskHint |
    WindowGroupHint;
pub const XUrgencyHint = 1 << 8;
pub const XStringStyle = 0;
pub const XCompoundTextStyle = 1;
pub const XTextStyle = 2;
pub const XStdICCTextStyle = 3;
pub const XUTF8StringStyle = 4;

pub const NormalState = 1;
pub const IconicState = 3;

// cursor icon
pub const XC_left_ptr = 68;
pub const XC_xterm = 152;
pub const XC_crosshair = 32;
pub const XC_hand1 = 58;
pub const XC_hand2 = 60;
pub const XC_fleur = 52;
pub const XC_circle = 24;
pub const XC_question_arrow = 92;
pub const XC_watch = 150;
pub const XC_exchange = 50;
pub const XC_X_cursor = 0;

pub const XDND_VER = 5;

/// Determine the modules name at comptime.
pub const XORG_LIBS_NAME = switch (builtin.target.os.tag) {
    .linux => [_][*:0]const u8{
        "libX11.so.6", "libXrandr.so.2", "libXinerama.so.1", "libXcursor.so.1",
        "libXi.so.6",
    },
    .freebsd, .netbsd, .openbsd => [_][*:0]const u8{
        "libX11.so", "libXrandr.so", "libXinerama.so", "libXcursor.so",
        "libXi.so",
    },
    else => @compileError("Unsupported Unix Platform"),
};

pub const LIB_X11_SONAME_INDEX = 0;
pub const LIB_XRANDR_SONAME_INDEX = 1;
pub const LIB_XINERAMA_SONAME_INDEX = 2;
pub const LIB_XCURSOR_SONAME_INDEX = 3;
pub const LIB_XINPUT2_SONAME_INDEX = 4;

//=====================
// Macros
//=====================
const assert = std.debug.assert;

pub inline fn ScreenOfDisplay(dpy: *Display, scr: c_int) *Screen {
    const priv_dpy: *_XPrivDisplay = @ptrCast(@alignCast(dpy));
    assert(scr >= 0);
    return &priv_dpy.screens.?[@intCast(scr)];
}
pub inline fn RootWindow(dpy: *Display, scr: c_int) Window {
    return ScreenOfDisplay(dpy, scr).root;
}

pub inline fn DefaultScreen(dpy: *Display) c_int {
    const priv_dpy: *_XPrivDisplay = @ptrCast(@alignCast(dpy));
    return priv_dpy.default_screen;
}

pub inline fn ConnectionNumber(dpy: *Display) c_int {
    const priv_dpy: *_XPrivDisplay = @ptrCast(@alignCast(dpy));
    return priv_dpy.fd;
}

pub inline fn DefaultVisual(dpy: *Display, scr: c_int) ?*Visual {
    return ScreenOfDisplay(dpy, scr).root_visual;
}

pub inline fn DefaultDepth(dpy: *Display, scr: c_int) c_int {
    return ScreenOfDisplay(dpy, scr).root_depth;
}

pub inline fn DisplayWidth(dpy: *Display, scr: c_int) c_int {
    return ScreenOfDisplay(dpy, scr).width;
}

pub inline fn DisplayHeight(dpy: *Display, scr: c_int) c_int {
    return ScreenOfDisplay(dpy, scr).height;
}
pub inline fn XUniqueContext() c_int {
    return dyn_api.XrmUniqueQuark();
}
//=====================
// Key symbol
//=====================

// x11-rs: Rust bindings for X11 libraries
// The X11 libraries are available under the MIT license.
// These bindings are public domain.

pub const XK_BackSpace = 0xFF08;
pub const XK_Tab = 0xFF09;
pub const XK_Linefeed = 0xFF0A;
pub const XK_Clear = 0xFF0B;
pub const XK_Return = 0xFF0D;
pub const XK_Pause = 0xFF13;
pub const XK_Scroll_Lock = 0xFF14;
pub const XK_Sys_Req = 0xFF15;
pub const XK_Escape = 0xFF1B;
pub const XK_Delete = 0xFFFF;
pub const XK_Multi_key = 0xFF20;
pub const XK_Kanji = 0xFF21;
pub const XK_Muhenkan = 0xFF22;
pub const XK_Henkan_Mode = 0xFF23;
pub const XK_Henkan = 0xFF23;
pub const XK_Romaji = 0xFF24;
pub const XK_Hiragana = 0xFF25;
pub const XK_Katakana = 0xFF26;
pub const XK_Hiragana_Katakana = 0xFF27;
pub const XK_Zenkaku = 0xFF28;
pub const XK_Hankaku = 0xFF29;
pub const XK_Zenkaku_Hankaku = 0xFF2A;
pub const XK_Touroku = 0xFF2B;
pub const XK_Massyo = 0xFF2C;
pub const XK_Kana_Lock = 0xFF2D;
pub const XK_Kana_Shift = 0xFF2E;
pub const XK_Eisu_Shift = 0xFF2F;
pub const XK_Eisu_toggle = 0xFF30;
pub const XK_Home = 0xFF50;
pub const XK_Left = 0xFF51;
pub const XK_Up = 0xFF52;
pub const XK_Right = 0xFF53;
pub const XK_Down = 0xFF54;
pub const XK_Prior = 0xFF55;
pub const XK_Page_Up = 0xFF55;
pub const XK_Next = 0xFF56;
pub const XK_Page_Down = 0xFF56;
pub const XK_End = 0xFF57;
pub const XK_Begin = 0xFF58;
pub const XK_Win_L = 0xFF5B;
pub const XK_Win_R = 0xFF5C;
pub const XK_App = 0xFF5D;
pub const XK_Select = 0xFF60;
pub const XK_Print = 0xFF61;
pub const XK_Execute = 0xFF62;
pub const XK_Insert = 0xFF63;
pub const XK_Undo = 0xFF65;
pub const XK_Redo = 0xFF66;
pub const XK_Menu = 0xFF67;
pub const XK_Find = 0xFF68;
pub const XK_Cancel = 0xFF69;
pub const XK_Help = 0xFF6A;
pub const XK_Break = 0xFF6B;
pub const XK_Mode_switch = 0xFF7E;
pub const XK_script_switch = 0xFF7E;
pub const XK_Num_Lock = 0xFF7F;
pub const XK_KP_Space = 0xFF80;
pub const XK_KP_Tab = 0xFF89;
pub const XK_KP_Enter = 0xFF8D;
pub const XK_KP_F1 = 0xFF91;
pub const XK_KP_F2 = 0xFF92;
pub const XK_KP_F3 = 0xFF93;
pub const XK_KP_F4 = 0xFF94;
pub const XK_KP_Home = 0xFF95;
pub const XK_KP_Left = 0xFF96;
pub const XK_KP_Up = 0xFF97;
pub const XK_KP_Right = 0xFF98;
pub const XK_KP_Down = 0xFF99;
pub const XK_KP_Prior = 0xFF9A;
pub const XK_KP_Page_Up = 0xFF9A;
pub const XK_KP_Next = 0xFF9B;
pub const XK_KP_Page_Down = 0xFF9B;
pub const XK_KP_End = 0xFF9C;
pub const XK_KP_Begin = 0xFF9D;
pub const XK_KP_Insert = 0xFF9E;
pub const XK_KP_Delete = 0xFF9F;
pub const XK_KP_Equal = 0xFFBD;
pub const XK_KP_Multiply = 0xFFAA;
pub const XK_KP_Add = 0xFFAB;
pub const XK_KP_Separator = 0xFFAC;
pub const XK_KP_Subtract = 0xFFAD;
pub const XK_KP_Decimal = 0xFFAE;
pub const XK_KP_Divide = 0xFFAF;
pub const XK_KP_0 = 0xFFB0;
pub const XK_KP_1 = 0xFFB1;
pub const XK_KP_2 = 0xFFB2;
pub const XK_KP_3 = 0xFFB3;
pub const XK_KP_4 = 0xFFB4;
pub const XK_KP_5 = 0xFFB5;
pub const XK_KP_6 = 0xFFB6;
pub const XK_KP_7 = 0xFFB7;
pub const XK_KP_8 = 0xFFB8;
pub const XK_KP_9 = 0xFFB9;
pub const XK_F1 = 0xFFBE;
pub const XK_F2 = 0xFFBF;
pub const XK_F3 = 0xFFC0;
pub const XK_F4 = 0xFFC1;
pub const XK_F5 = 0xFFC2;
pub const XK_F6 = 0xFFC3;
pub const XK_F7 = 0xFFC4;
pub const XK_F8 = 0xFFC5;
pub const XK_F9 = 0xFFC6;
pub const XK_F10 = 0xFFC7;
pub const XK_F11 = 0xFFC8;
pub const XK_L1 = 0xFFC8;
pub const XK_F12 = 0xFFC9;
pub const XK_L2 = 0xFFC9;
pub const XK_F13 = 0xFFCA;
pub const XK_L3 = 0xFFCA;
pub const XK_F14 = 0xFFCB;
pub const XK_L4 = 0xFFCB;
pub const XK_F15 = 0xFFCC;
pub const XK_L5 = 0xFFCC;
pub const XK_F16 = 0xFFCD;
pub const XK_L6 = 0xFFCD;
pub const XK_F17 = 0xFFCE;
pub const XK_L7 = 0xFFCE;
pub const XK_F18 = 0xFFCF;
pub const XK_L8 = 0xFFCF;
pub const XK_F19 = 0xFFD0;
pub const XK_L9 = 0xFFD0;
pub const XK_F20 = 0xFFD1;
pub const XK_L10 = 0xFFD1;
pub const XK_F21 = 0xFFD2;
pub const XK_R1 = 0xFFD2;
pub const XK_F22 = 0xFFD3;
pub const XK_R2 = 0xFFD3;
pub const XK_F23 = 0xFFD4;
pub const XK_R3 = 0xFFD4;
pub const XK_F24 = 0xFFD5;
pub const XK_R4 = 0xFFD5;
pub const XK_F25 = 0xFFD6;
pub const XK_R5 = 0xFFD6;
pub const XK_F26 = 0xFFD7;
pub const XK_R6 = 0xFFD7;
pub const XK_F27 = 0xFFD8;
pub const XK_R7 = 0xFFD8;
pub const XK_F28 = 0xFFD9;
pub const XK_R8 = 0xFFD9;
pub const XK_F29 = 0xFFDA;
pub const XK_R9 = 0xFFDA;
pub const XK_F30 = 0xFFDB;
pub const XK_R10 = 0xFFDB;
pub const XK_F31 = 0xFFDC;
pub const XK_R11 = 0xFFDC;
pub const XK_F32 = 0xFFDD;
pub const XK_R12 = 0xFFDD;
pub const XK_F33 = 0xFFDE;
pub const XK_R13 = 0xFFDE;
pub const XK_F34 = 0xFFDF;
pub const XK_R14 = 0xFFDF;
pub const XK_F35 = 0xFFE0;
pub const XK_R15 = 0xFFE0;
pub const XK_Shift_L = 0xFFE1;
pub const XK_Shift_R = 0xFFE2;
pub const XK_Control_L = 0xFFE3;
pub const XK_Control_R = 0xFFE4;
pub const XK_Caps_Lock = 0xFFE5;
pub const XK_Shift_Lock = 0xFFE6;
pub const XK_Meta_L = 0xFFE7;
pub const XK_Meta_R = 0xFFE8;
pub const XK_Alt_L = 0xFFE9;
pub const XK_Alt_R = 0xFFEA;
pub const XK_Super_L = 0xFFEB;
pub const XK_Super_R = 0xFFEC;
pub const XK_Hyper_L = 0xFFED;
pub const XK_Hyper_R = 0xFFEE;
pub const XK_space = 0x020;
pub const XK_exclam = 0x021;
pub const XK_quotedbl = 0x022;
pub const XK_numbersign = 0x023;
pub const XK_dollar = 0x024;
pub const XK_percent = 0x025;
pub const XK_ampersand = 0x026;
pub const XK_apostrophe = 0x027;
pub const XK_quoteright = 0x027;
pub const XK_parenleft = 0x028;
pub const XK_parenright = 0x029;
pub const XK_asterisk = 0x02a;
pub const XK_plus = 0x02b;
pub const XK_comma = 0x02c;
pub const XK_minus = 0x02d;
pub const XK_period = 0x02e;
pub const XK_slash = 0x02f;
pub const XK_0 = 0x030;
pub const XK_1 = 0x031;
pub const XK_2 = 0x032;
pub const XK_3 = 0x033;
pub const XK_4 = 0x034;
pub const XK_5 = 0x035;
pub const XK_6 = 0x036;
pub const XK_7 = 0x037;
pub const XK_8 = 0x038;
pub const XK_9 = 0x039;
pub const XK_colon = 0x03a;
pub const XK_semicolon = 0x03b;
pub const XK_less = 0x03c;
pub const XK_equal = 0x03d;
pub const XK_greater = 0x03e;
pub const XK_question = 0x03f;
pub const XK_at = 0x040;
pub const XK_A = 0x041;
pub const XK_B = 0x042;
pub const XK_C = 0x043;
pub const XK_D = 0x044;
pub const XK_E = 0x045;
pub const XK_F = 0x046;
pub const XK_G = 0x047;
pub const XK_H = 0x048;
pub const XK_I = 0x049;
pub const XK_J = 0x04a;
pub const XK_K = 0x04b;
pub const XK_L = 0x04c;
pub const XK_M = 0x04d;
pub const XK_N = 0x04e;
pub const XK_O = 0x04f;
pub const XK_P = 0x050;
pub const XK_Q = 0x051;
pub const XK_R = 0x052;
pub const XK_S = 0x053;
pub const XK_T = 0x054;
pub const XK_U = 0x055;
pub const XK_V = 0x056;
pub const XK_W = 0x057;
pub const XK_X = 0x058;
pub const XK_Y = 0x059;
pub const XK_Z = 0x05a;
pub const XK_bracketleft = 0x05b;
pub const XK_backslash = 0x05c;
pub const XK_bracketright = 0x05d;
pub const XK_asciicircum = 0x05e;
pub const XK_underscore = 0x05f;
pub const XK_grave = 0x060;
pub const XK_quoteleft = 0x060;
pub const XK_a = 0x061;
pub const XK_b = 0x062;
pub const XK_c = 0x063;
pub const XK_d = 0x064;
pub const XK_e = 0x065;
pub const XK_f = 0x066;
pub const XK_g = 0x067;
pub const XK_h = 0x068;
pub const XK_i = 0x069;
pub const XK_j = 0x06a;
pub const XK_k = 0x06b;
pub const XK_l = 0x06c;
pub const XK_m = 0x06d;
pub const XK_n = 0x06e;
pub const XK_o = 0x06f;
pub const XK_p = 0x070;
pub const XK_q = 0x071;
pub const XK_r = 0x072;
pub const XK_s = 0x073;
pub const XK_t = 0x074;
pub const XK_u = 0x075;
pub const XK_v = 0x076;
pub const XK_w = 0x077;
pub const XK_x = 0x078;
pub const XK_y = 0x079;
pub const XK_z = 0x07a;
pub const XK_braceleft = 0x07b;
pub const XK_bar = 0x07c;
pub const XK_braceright = 0x07d;
pub const XK_asciitilde = 0x07e;
pub const XK_nobreakspace = 0x0a0;
pub const XK_exclamdown = 0x0a1;
pub const XK_cent = 0x0a2;
pub const XK_sterling = 0x0a3;
pub const XK_currency = 0x0a4;
pub const XK_yen = 0x0a5;
pub const XK_brokenbar = 0x0a6;
pub const XK_section = 0x0a7;
pub const XK_diaeresis = 0x0a8;
pub const XK_copyright = 0x0a9;
pub const XK_ordfeminine = 0x0aa;
pub const XK_guillemotleft = 0x0ab;
pub const XK_notsign = 0x0ac;
pub const XK_hyphen = 0x0ad;
pub const XK_registered = 0x0ae;
pub const XK_macron = 0x0af;
pub const XK_degree = 0x0b0;
pub const XK_plusminus = 0x0b1;
pub const XK_twosuperior = 0x0b2;
pub const XK_threesuperior = 0x0b3;
pub const XK_acute = 0x0b4;
pub const XK_mu = 0x0b5;
pub const XK_paragraph = 0x0b6;
pub const XK_periodcentered = 0x0b7;
pub const XK_cedilla = 0x0b8;
pub const XK_onesuperior = 0x0b9;
pub const XK_masculine = 0x0ba;
pub const XK_guillemotright = 0x0bb;
pub const XK_onequarter = 0x0bc;
pub const XK_onehalf = 0x0bd;
pub const XK_threequarters = 0x0be;
pub const XK_questiondown = 0x0bf;
pub const XK_Agrave = 0x0c0;
pub const XK_Aacute = 0x0c1;
pub const XK_Acircumflex = 0x0c2;
pub const XK_Atilde = 0x0c3;
pub const XK_Adiaeresis = 0x0c4;
pub const XK_Aring = 0x0c5;
pub const XK_AE = 0x0c6;
pub const XK_Ccedilla = 0x0c7;
pub const XK_Egrave = 0x0c8;
pub const XK_Eacute = 0x0c9;
pub const XK_Ecircumflex = 0x0ca;
pub const XK_Ediaeresis = 0x0cb;
pub const XK_Igrave = 0x0cc;
pub const XK_Iacute = 0x0cd;
pub const XK_Icircumflex = 0x0ce;
pub const XK_Idiaeresis = 0x0cf;
pub const XK_ETH = 0x0d0;
pub const XK_Eth = 0x0d0;
pub const XK_Ntilde = 0x0d1;
pub const XK_Ograve = 0x0d2;
pub const XK_Oacute = 0x0d3;
pub const XK_Ocircumflex = 0x0d4;
pub const XK_Otilde = 0x0d5;
pub const XK_Odiaeresis = 0x0d6;
pub const XK_multiply = 0x0d7;
pub const XK_Ooblique = 0x0d8;
pub const XK_Ugrave = 0x0d9;
pub const XK_Uacute = 0x0da;
pub const XK_Ucircumflex = 0x0db;
pub const XK_Udiaeresis = 0x0dc;
pub const XK_Yacute = 0x0dd;
pub const XK_THORN = 0x0de;
pub const XK_Thorn = 0x0de;
pub const XK_ssharp = 0x0df;
pub const XK_agrave = 0x0e0;
pub const XK_aacute = 0x0e1;
pub const XK_acircumflex = 0x0e2;
pub const XK_atilde = 0x0e3;
pub const XK_adiaeresis = 0x0e4;
pub const XK_aring = 0x0e5;
pub const XK_ae = 0x0e6;
pub const XK_ccedilla = 0x0e7;
pub const XK_egrave = 0x0e8;
pub const XK_eacute = 0x0e9;
pub const XK_ecircumflex = 0x0ea;
pub const XK_ediaeresis = 0x0eb;
pub const XK_igrave = 0x0ec;
pub const XK_iacute = 0x0ed;
pub const XK_icircumflex = 0x0ee;
pub const XK_idiaeresis = 0x0ef;
pub const XK_eth = 0x0f0;
pub const XK_ntilde = 0x0f1;
pub const XK_ograve = 0x0f2;
pub const XK_oacute = 0x0f3;
pub const XK_ocircumflex = 0x0f4;
pub const XK_otilde = 0x0f5;
pub const XK_odiaeresis = 0x0f6;
pub const XK_division = 0x0f7;
pub const XK_oslash = 0x0f8;
pub const XK_ugrave = 0x0f9;
pub const XK_uacute = 0x0fa;
pub const XK_ucircumflex = 0x0fb;
pub const XK_udiaeresis = 0x0fc;
pub const XK_yacute = 0x0fd;
pub const XK_thorn = 0x0fe;
pub const XK_ydiaeresis = 0x0ff;
pub const XK_Aogonek = 0x1a1;
pub const XK_breve = 0x1a2;
pub const XK_Lstroke = 0x1a3;
pub const XK_Lcaron = 0x1a5;
pub const XK_Sacute = 0x1a6;
pub const XK_Scaron = 0x1a9;
pub const XK_Scedilla = 0x1aa;
pub const XK_Tcaron = 0x1ab;
pub const XK_Zacute = 0x1ac;
pub const XK_Zcaron = 0x1ae;
pub const XK_Zabovedot = 0x1af;
pub const XK_aogonek = 0x1b1;
pub const XK_ogonek = 0x1b2;
pub const XK_lstroke = 0x1b3;
pub const XK_lcaron = 0x1b5;
pub const XK_sacute = 0x1b6;
pub const XK_caron = 0x1b7;
pub const XK_scaron = 0x1b9;
pub const XK_scedilla = 0x1ba;
pub const XK_tcaron = 0x1bb;
pub const XK_zacute = 0x1bc;
pub const XK_doubleacute = 0x1bd;
pub const XK_zcaron = 0x1be;
pub const XK_zabovedot = 0x1bf;
pub const XK_Racute = 0x1c0;
pub const XK_Abreve = 0x1c3;
pub const XK_Lacute = 0x1c5;
pub const XK_Cacute = 0x1c6;
pub const XK_Ccaron = 0x1c8;
pub const XK_Eogonek = 0x1ca;
pub const XK_Ecaron = 0x1cc;
pub const XK_Dcaron = 0x1cf;
pub const XK_Dstroke = 0x1d0;
pub const XK_Nacute = 0x1d1;
pub const XK_Ncaron = 0x1d2;
pub const XK_Odoubleacute = 0x1d5;
pub const XK_Rcaron = 0x1d8;
pub const XK_Uring = 0x1d9;
pub const XK_Udoubleacute = 0x1db;
pub const XK_Tcedilla = 0x1de;
pub const XK_racute = 0x1e0;
pub const XK_abreve = 0x1e3;
pub const XK_lacute = 0x1e5;
pub const XK_cacute = 0x1e6;
pub const XK_ccaron = 0x1e8;
pub const XK_eogonek = 0x1ea;
pub const XK_ecaron = 0x1ec;
pub const XK_dcaron = 0x1ef;
pub const XK_dstroke = 0x1f0;
pub const XK_nacute = 0x1f1;
pub const XK_ncaron = 0x1f2;
pub const XK_odoubleacute = 0x1f5;
pub const XK_udoubleacute = 0x1fb;
pub const XK_rcaron = 0x1f8;
pub const XK_uring = 0x1f9;
pub const XK_tcedilla = 0x1fe;
pub const XK_abovedot = 0x1ff;
pub const XK_Hstroke = 0x2a1;
pub const XK_Hcircumflex = 0x2a6;
pub const XK_Iabovedot = 0x2a9;
pub const XK_Gbreve = 0x2ab;
pub const XK_Jcircumflex = 0x2ac;
pub const XK_hstroke = 0x2b1;
pub const XK_hcircumflex = 0x2b6;
pub const XK_idotless = 0x2b9;
pub const XK_gbreve = 0x2bb;
pub const XK_jcircumflex = 0x2bc;
pub const XK_Cabovedot = 0x2c5;
pub const XK_Ccircumflex = 0x2c6;
pub const XK_Gabovedot = 0x2d5;
pub const XK_Gcircumflex = 0x2d8;
pub const XK_Ubreve = 0x2dd;
pub const XK_Scircumflex = 0x2de;
pub const XK_cabovedot = 0x2e5;
pub const XK_ccircumflex = 0x2e6;
pub const XK_gabovedot = 0x2f5;
pub const XK_gcircumflex = 0x2f8;
pub const XK_ubreve = 0x2fd;
pub const XK_scircumflex = 0x2fe;
pub const XK_kra = 0x3a2;
pub const XK_kappa = 0x3a2;
pub const XK_Rcedilla = 0x3a3;
pub const XK_Itilde = 0x3a5;
pub const XK_Lcedilla = 0x3a6;
pub const XK_Emacron = 0x3aa;
pub const XK_Gcedilla = 0x3ab;
pub const XK_Tslash = 0x3ac;
pub const XK_rcedilla = 0x3b3;
pub const XK_itilde = 0x3b5;
pub const XK_lcedilla = 0x3b6;
pub const XK_emacron = 0x3ba;
pub const XK_gcedilla = 0x3bb;
pub const XK_tslash = 0x3bc;
pub const XK_ENG = 0x3bd;
pub const XK_eng = 0x3bf;
pub const XK_Amacron = 0x3c0;
pub const XK_Iogonek = 0x3c7;
pub const XK_Eabovedot = 0x3cc;
pub const XK_Imacron = 0x3cf;
pub const XK_Ncedilla = 0x3d1;
pub const XK_Omacron = 0x3d2;
pub const XK_Kcedilla = 0x3d3;
pub const XK_Uogonek = 0x3d9;
pub const XK_Utilde = 0x3dd;
pub const XK_Umacron = 0x3de;
pub const XK_amacron = 0x3e0;
pub const XK_iogonek = 0x3e7;
pub const XK_eabovedot = 0x3ec;
pub const XK_imacron = 0x3ef;
pub const XK_ncedilla = 0x3f1;
pub const XK_omacron = 0x3f2;
pub const XK_kcedilla = 0x3f3;
pub const XK_uogonek = 0x3f9;
pub const XK_utilde = 0x3fd;
pub const XK_umacron = 0x3fe;
pub const XK_overline = 0x47e;
pub const XK_kana_fullstop = 0x4a1;
pub const XK_kana_openingbracket = 0x4a2;
pub const XK_kana_closingbracket = 0x4a3;
pub const XK_kana_comma = 0x4a4;
pub const XK_kana_conjunctive = 0x4a5;
pub const XK_kana_middledot = 0x4a5;
pub const XK_kana_WO = 0x4a6;
pub const XK_kana_a = 0x4a7;
pub const XK_kana_i = 0x4a8;
pub const XK_kana_u = 0x4a9;
pub const XK_kana_e = 0x4aa;
pub const XK_kana_o = 0x4ab;
pub const XK_kana_ya = 0x4ac;
pub const XK_kana_yu = 0x4ad;
pub const XK_kana_yo = 0x4ae;
pub const XK_kana_tsu = 0x4af;
pub const XK_kana_tu = 0x4af;
pub const XK_prolongedsound = 0x4b0;
pub const XK_kana_A = 0x4b1;
pub const XK_kana_I = 0x4b2;
pub const XK_kana_U = 0x4b3;
pub const XK_kana_E = 0x4b4;
pub const XK_kana_O = 0x4b5;
pub const XK_kana_KA = 0x4b6;
pub const XK_kana_KI = 0x4b7;
pub const XK_kana_KU = 0x4b8;
pub const XK_kana_KE = 0x4b9;
pub const XK_kana_KO = 0x4ba;
pub const XK_kana_SA = 0x4bb;
pub const XK_kana_SHI = 0x4bc;
pub const XK_kana_SU = 0x4bd;
pub const XK_kana_SE = 0x4be;
pub const XK_kana_SO = 0x4bf;
pub const XK_kana_TA = 0x4c0;
pub const XK_kana_CHI = 0x4c1;
pub const XK_kana_TI = 0x4c1;
pub const XK_kana_TSU = 0x4c2;
pub const XK_kana_TU = 0x4c2;
pub const XK_kana_TE = 0x4c3;
pub const XK_kana_TO = 0x4c4;
pub const XK_kana_NA = 0x4c5;
pub const XK_kana_NI = 0x4c6;
pub const XK_kana_NU = 0x4c7;
pub const XK_kana_NE = 0x4c8;
pub const XK_kana_NO = 0x4c9;
pub const XK_kana_HA = 0x4ca;
pub const XK_kana_HI = 0x4cb;
pub const XK_kana_FU = 0x4cc;
pub const XK_kana_HU = 0x4cc;
pub const XK_kana_HE = 0x4cd;
pub const XK_kana_HO = 0x4ce;
pub const XK_kana_MA = 0x4cf;
pub const XK_kana_MI = 0x4d0;
pub const XK_kana_MU = 0x4d1;
pub const XK_kana_ME = 0x4d2;
pub const XK_kana_MO = 0x4d3;
pub const XK_kana_YA = 0x4d4;
pub const XK_kana_YU = 0x4d5;
pub const XK_kana_YO = 0x4d6;
pub const XK_kana_RA = 0x4d7;
pub const XK_kana_RI = 0x4d8;
pub const XK_kana_RU = 0x4d9;
pub const XK_kana_RE = 0x4da;
pub const XK_kana_RO = 0x4db;
pub const XK_kana_WA = 0x4dc;
pub const XK_kana_N = 0x4dd;
pub const XK_voicedsound = 0x4de;
pub const XK_semivoicedsound = 0x4df;
pub const XK_kana_switch = 0xFF7E;
pub const XK_Arabic_comma = 0x5ac;
pub const XK_Arabic_semicolon = 0x5bb;
pub const XK_Arabic_question_mark = 0x5bf;
pub const XK_Arabic_hamza = 0x5c1;
pub const XK_Arabic_maddaonalef = 0x5c2;
pub const XK_Arabic_hamzaonalef = 0x5c3;
pub const XK_Arabic_hamzaonwaw = 0x5c4;
pub const XK_Arabic_hamzaunderalef = 0x5c5;
pub const XK_Arabic_hamzaonyeh = 0x5c6;
pub const XK_Arabic_alef = 0x5c7;
pub const XK_Arabic_beh = 0x5c8;
pub const XK_Arabic_tehmarbuta = 0x5c9;
pub const XK_Arabic_teh = 0x5ca;
pub const XK_Arabic_theh = 0x5cb;
pub const XK_Arabic_jeem = 0x5cc;
pub const XK_Arabic_hah = 0x5cd;
pub const XK_Arabic_khah = 0x5ce;
pub const XK_Arabic_dal = 0x5cf;
pub const XK_Arabic_thal = 0x5d0;
pub const XK_Arabic_ra = 0x5d1;
pub const XK_Arabic_zain = 0x5d2;
pub const XK_Arabic_seen = 0x5d3;
pub const XK_Arabic_sheen = 0x5d4;
pub const XK_Arabic_sad = 0x5d5;
pub const XK_Arabic_dad = 0x5d6;
pub const XK_Arabic_tah = 0x5d7;
pub const XK_Arabic_zah = 0x5d8;
pub const XK_Arabic_ain = 0x5d9;
pub const XK_Arabic_ghain = 0x5da;
pub const XK_Arabic_tatweel = 0x5e0;
pub const XK_Arabic_feh = 0x5e1;
pub const XK_Arabic_qaf = 0x5e2;
pub const XK_Arabic_kaf = 0x5e3;
pub const XK_Arabic_lam = 0x5e4;
pub const XK_Arabic_meem = 0x5e5;
pub const XK_Arabic_noon = 0x5e6;
pub const XK_Arabic_ha = 0x5e7;
pub const XK_Arabic_heh = 0x5e7;
pub const XK_Arabic_waw = 0x5e8;
pub const XK_Arabic_alefmaksura = 0x5e9;
pub const XK_Arabic_yeh = 0x5ea;
pub const XK_Arabic_fathatan = 0x5eb;
pub const XK_Arabic_dammatan = 0x5ec;
pub const XK_Arabic_kasratan = 0x5ed;
pub const XK_Arabic_fatha = 0x5ee;
pub const XK_Arabic_damma = 0x5ef;
pub const XK_Arabic_kasra = 0x5f0;
pub const XK_Arabic_shadda = 0x5f1;
pub const XK_Arabic_sukun = 0x5f2;
pub const XK_Arabic_switch = 0xFF7E;
pub const XK_Serbian_dje = 0x6a1;
pub const XK_Macedonia_gje = 0x6a2;
pub const XK_Cyrillic_io = 0x6a3;
pub const XK_Ukrainian_ie = 0x6a4;
pub const XK_Ukranian_je = 0x6a4;
pub const XK_Macedonia_dse = 0x6a5;
pub const XK_Ukrainian_i = 0x6a6;
pub const XK_Ukranian_i = 0x6a6;
pub const XK_Ukrainian_yi = 0x6a7;
pub const XK_Ukranian_yi = 0x6a7;
pub const XK_Cyrillic_je = 0x6a8;
pub const XK_Serbian_je = 0x6a8;
pub const XK_Cyrillic_lje = 0x6a9;
pub const XK_Serbian_lje = 0x6a9;
pub const XK_Cyrillic_nje = 0x6aa;
pub const XK_Serbian_nje = 0x6aa;
pub const XK_Serbian_tshe = 0x6ab;
pub const XK_Macedonia_kje = 0x6ac;
pub const XK_Byelorussian_shortu = 0x6ae;
pub const XK_Cyrillic_dzhe = 0x6af;
pub const XK_Serbian_dze = 0x6af;
pub const XK_numerosign = 0x6b0;
pub const XK_Serbian_DJE = 0x6b1;
pub const XK_Macedonia_GJE = 0x6b2;
pub const XK_Cyrillic_IO = 0x6b3;
pub const XK_Ukrainian_IE = 0x6b4;
pub const XK_Ukranian_JE = 0x6b4;
pub const XK_Macedonia_DSE = 0x6b5;
pub const XK_Ukrainian_I = 0x6b6;
pub const XK_Ukranian_I = 0x6b6;
pub const XK_Ukrainian_YI = 0x6b7;
pub const XK_Ukranian_YI = 0x6b7;
pub const XK_Cyrillic_JE = 0x6b8;
pub const XK_Serbian_JE = 0x6b8;
pub const XK_Cyrillic_LJE = 0x6b9;
pub const XK_Serbian_LJE = 0x6b9;
pub const XK_Cyrillic_NJE = 0x6ba;
pub const XK_Serbian_NJE = 0x6ba;
pub const XK_Serbian_TSHE = 0x6bb;
pub const XK_Macedonia_KJE = 0x6bc;
pub const XK_Byelorussian_SHORTU = 0x6be;
pub const XK_Cyrillic_DZHE = 0x6bf;
pub const XK_Serbian_DZE = 0x6bf;
pub const XK_Cyrillic_yu = 0x6c0;
pub const XK_Cyrillic_a = 0x6c1;
pub const XK_Cyrillic_be = 0x6c2;
pub const XK_Cyrillic_tse = 0x6c3;
pub const XK_Cyrillic_de = 0x6c4;
pub const XK_Cyrillic_ie = 0x6c5;
pub const XK_Cyrillic_ef = 0x6c6;
pub const XK_Cyrillic_ghe = 0x6c7;
pub const XK_Cyrillic_ha = 0x6c8;
pub const XK_Cyrillic_i = 0x6c9;
pub const XK_Cyrillic_shorti = 0x6ca;
pub const XK_Cyrillic_ka = 0x6cb;
pub const XK_Cyrillic_el = 0x6cc;
pub const XK_Cyrillic_em = 0x6cd;
pub const XK_Cyrillic_en = 0x6ce;
pub const XK_Cyrillic_o = 0x6cf;
pub const XK_Cyrillic_pe = 0x6d0;
pub const XK_Cyrillic_ya = 0x6d1;
pub const XK_Cyrillic_er = 0x6d2;
pub const XK_Cyrillic_es = 0x6d3;
pub const XK_Cyrillic_te = 0x6d4;
pub const XK_Cyrillic_u = 0x6d5;
pub const XK_Cyrillic_zhe = 0x6d6;
pub const XK_Cyrillic_ve = 0x6d7;
pub const XK_Cyrillic_softsign = 0x6d8;
pub const XK_Cyrillic_yeru = 0x6d9;
pub const XK_Cyrillic_ze = 0x6da;
pub const XK_Cyrillic_sha = 0x6db;
pub const XK_Cyrillic_e = 0x6dc;
pub const XK_Cyrillic_shcha = 0x6dd;
pub const XK_Cyrillic_che = 0x6de;
pub const XK_Cyrillic_hardsign = 0x6df;
pub const XK_Cyrillic_YU = 0x6e0;
pub const XK_Cyrillic_A = 0x6e1;
pub const XK_Cyrillic_BE = 0x6e2;
pub const XK_Cyrillic_TSE = 0x6e3;
pub const XK_Cyrillic_DE = 0x6e4;
pub const XK_Cyrillic_IE = 0x6e5;
pub const XK_Cyrillic_EF = 0x6e6;
pub const XK_Cyrillic_GHE = 0x6e7;
pub const XK_Cyrillic_HA = 0x6e8;
pub const XK_Cyrillic_I = 0x6e9;
pub const XK_Cyrillic_SHORTI = 0x6ea;
pub const XK_Cyrillic_KA = 0x6eb;
pub const XK_Cyrillic_EL = 0x6ec;
pub const XK_Cyrillic_EM = 0x6ed;
pub const XK_Cyrillic_EN = 0x6ee;
pub const XK_Cyrillic_O = 0x6ef;
pub const XK_Cyrillic_PE = 0x6f0;
pub const XK_Cyrillic_YA = 0x6f1;
pub const XK_Cyrillic_ER = 0x6f2;
pub const XK_Cyrillic_ES = 0x6f3;
pub const XK_Cyrillic_TE = 0x6f4;
pub const XK_Cyrillic_U = 0x6f5;
pub const XK_Cyrillic_ZHE = 0x6f6;
pub const XK_Cyrillic_VE = 0x6f7;
pub const XK_Cyrillic_SOFTSIGN = 0x6f8;
pub const XK_Cyrillic_YERU = 0x6f9;
pub const XK_Cyrillic_ZE = 0x6fa;
pub const XK_Cyrillic_SHA = 0x6fb;
pub const XK_Cyrillic_E = 0x6fc;
pub const XK_Cyrillic_SHCHA = 0x6fd;
pub const XK_Cyrillic_CHE = 0x6fe;
pub const XK_Cyrillic_HARDSIGN = 0x6ff;
pub const XK_Greek_ALPHAaccent = 0x7a1;
pub const XK_Greek_EPSILONaccent = 0x7a2;
pub const XK_Greek_ETAaccent = 0x7a3;
pub const XK_Greek_IOTAaccent = 0x7a4;
pub const XK_Greek_IOTAdiaeresis = 0x7a5;
pub const XK_Greek_OMICRONaccent = 0x7a7;
pub const XK_Greek_UPSILONaccent = 0x7a8;
pub const XK_Greek_UPSILONdieresis = 0x7a9;
pub const XK_Greek_OMEGAaccent = 0x7ab;
pub const XK_Greek_accentdieresis = 0x7ae;
pub const XK_Greek_horizbar = 0x7af;
pub const XK_Greek_alphaaccent = 0x7b1;
pub const XK_Greek_epsilonaccent = 0x7b2;
pub const XK_Greek_etaaccent = 0x7b3;
pub const XK_Greek_iotaaccent = 0x7b4;
pub const XK_Greek_iotadieresis = 0x7b5;
pub const XK_Greek_iotaaccentdieresis = 0x7b6;
pub const XK_Greek_omicronaccent = 0x7b7;
pub const XK_Greek_upsilonaccent = 0x7b8;
pub const XK_Greek_upsilondieresis = 0x7b9;
pub const XK_Greek_upsilonaccentdieresis = 0x7ba;
pub const XK_Greek_omegaaccent = 0x7bb;
pub const XK_Greek_ALPHA = 0x7c1;
pub const XK_Greek_BETA = 0x7c2;
pub const XK_Greek_GAMMA = 0x7c3;
pub const XK_Greek_DELTA = 0x7c4;
pub const XK_Greek_EPSILON = 0x7c5;
pub const XK_Greek_ZETA = 0x7c6;
pub const XK_Greek_ETA = 0x7c7;
pub const XK_Greek_THETA = 0x7c8;
pub const XK_Greek_IOTA = 0x7c9;
pub const XK_Greek_KAPPA = 0x7ca;
pub const XK_Greek_LAMDA = 0x7cb;
pub const XK_Greek_LAMBDA = 0x7cb;
pub const XK_Greek_MU = 0x7cc;
pub const XK_Greek_NU = 0x7cd;
pub const XK_Greek_XI = 0x7ce;
pub const XK_Greek_OMICRON = 0x7cf;
pub const XK_Greek_PI = 0x7d0;
pub const XK_Greek_RHO = 0x7d1;
pub const XK_Greek_SIGMA = 0x7d2;
pub const XK_Greek_TAU = 0x7d4;
pub const XK_Greek_UPSILON = 0x7d5;
pub const XK_Greek_PHI = 0x7d6;
pub const XK_Greek_CHI = 0x7d7;
pub const XK_Greek_PSI = 0x7d8;
pub const XK_Greek_OMEGA = 0x7d9;
pub const XK_Greek_alpha = 0x7e1;
pub const XK_Greek_beta = 0x7e2;
pub const XK_Greek_gamma = 0x7e3;
pub const XK_Greek_delta = 0x7e4;
pub const XK_Greek_epsilon = 0x7e5;
pub const XK_Greek_zeta = 0x7e6;
pub const XK_Greek_eta = 0x7e7;
pub const XK_Greek_theta = 0x7e8;
pub const XK_Greek_iota = 0x7e9;
pub const XK_Greek_kappa = 0x7ea;
pub const XK_Greek_lamda = 0x7eb;
pub const XK_Greek_lambda = 0x7eb;
pub const XK_Greek_mu = 0x7ec;
pub const XK_Greek_nu = 0x7ed;
pub const XK_Greek_xi = 0x7ee;
pub const XK_Greek_omicron = 0x7ef;
pub const XK_Greek_pi = 0x7f0;
pub const XK_Greek_rho = 0x7f1;
pub const XK_Greek_sigma = 0x7f2;
pub const XK_Greek_finalsmallsigma = 0x7f3;
pub const XK_Greek_tau = 0x7f4;
pub const XK_Greek_upsilon = 0x7f5;
pub const XK_Greek_phi = 0x7f6;
pub const XK_Greek_chi = 0x7f7;
pub const XK_Greek_psi = 0x7f8;
pub const XK_Greek_omega = 0x7f9;
pub const XK_Greek_switch = 0xFF7E;
pub const XK_leftradical = 0x8a1;
pub const XK_topleftradical = 0x8a2;
pub const XK_horizconnector = 0x8a3;
pub const XK_topintegral = 0x8a4;
pub const XK_botintegral = 0x8a5;
pub const XK_vertconnector = 0x8a6;
pub const XK_topleftsqbracket = 0x8a7;
pub const XK_botleftsqbracket = 0x8a8;
pub const XK_toprightsqbracket = 0x8a9;
pub const XK_botrightsqbracket = 0x8aa;
pub const XK_topleftparens = 0x8ab;
pub const XK_botleftparens = 0x8ac;
pub const XK_toprightparens = 0x8ad;
pub const XK_botrightparens = 0x8ae;
pub const XK_leftmiddlecurlybrace = 0x8af;
pub const XK_rightmiddlecurlybrace = 0x8b0;
pub const XK_topleftsummation = 0x8b1;
pub const XK_botleftsummation = 0x8b2;
pub const XK_topvertsummationconnector = 0x8b3;
pub const XK_botvertsummationconnector = 0x8b4;
pub const XK_toprightsummation = 0x8b5;
pub const XK_botrightsummation = 0x8b6;
pub const XK_rightmiddlesummation = 0x8b7;
pub const XK_lessthanequal = 0x8bc;
pub const XK_notequal = 0x8bd;
pub const XK_greaterthanequal = 0x8be;
pub const XK_integral = 0x8bf;
pub const XK_therefore = 0x8c0;
pub const XK_variation = 0x8c1;
pub const XK_infinity = 0x8c2;
pub const XK_nabla = 0x8c5;
pub const XK_approximate = 0x8c8;
pub const XK_similarequal = 0x8c9;
pub const XK_ifonlyif = 0x8cd;
pub const XK_implies = 0x8ce;
pub const XK_identical = 0x8cf;
pub const XK_radical = 0x8d6;
pub const XK_includedin = 0x8da;
pub const XK_includes = 0x8db;
pub const XK_intersection = 0x8dc;
pub const XK_union = 0x8dd;
pub const XK_logicaland = 0x8de;
pub const XK_logicalor = 0x8df;
pub const XK_partialderivative = 0x8ef;
pub const XK_function = 0x8f6;
pub const XK_leftarrow = 0x8fb;
pub const XK_uparrow = 0x8fc;
pub const XK_rightarrow = 0x8fd;
pub const XK_downarrow = 0x8fe;
pub const XK_blank = 0x9df;
pub const XK_soliddiamond = 0x9e0;
pub const XK_checkerboard = 0x9e1;
pub const XK_ht = 0x9e2;
pub const XK_ff = 0x9e3;
pub const XK_cr = 0x9e4;
pub const XK_lf = 0x9e5;
pub const XK_nl = 0x9e8;
pub const XK_vt = 0x9e9;
pub const XK_lowrightcorner = 0x9ea;
pub const XK_uprightcorner = 0x9eb;
pub const XK_upleftcorner = 0x9ec;
pub const XK_lowleftcorner = 0x9ed;
pub const XK_crossinglines = 0x9ee;
pub const XK_horizlinescan1 = 0x9ef;
pub const XK_horizlinescan3 = 0x9f0;
pub const XK_horizlinescan5 = 0x9f1;
pub const XK_horizlinescan7 = 0x9f2;
pub const XK_horizlinescan9 = 0x9f3;
pub const XK_leftt = 0x9f4;
pub const XK_rightt = 0x9f5;
pub const XK_bott = 0x9f6;
pub const XK_topt = 0x9f7;
pub const XK_vertbar = 0x9f8;
pub const XK_emspace = 0xaa1;
pub const XK_enspace = 0xaa2;
pub const XK_em3space = 0xaa3;
pub const XK_em4space = 0xaa4;
pub const XK_digitspace = 0xaa5;
pub const XK_punctspace = 0xaa6;
pub const XK_thinspace = 0xaa7;
pub const XK_hairspace = 0xaa8;
pub const XK_emdash = 0xaa9;
pub const XK_endash = 0xaaa;
pub const XK_signifblank = 0xaac;
pub const XK_ellipsis = 0xaae;
pub const XK_doubbaselinedot = 0xaaf;
pub const XK_onethird = 0xab0;
pub const XK_twothirds = 0xab1;
pub const XK_onefifth = 0xab2;
pub const XK_twofifths = 0xab3;
pub const XK_threefifths = 0xab4;
pub const XK_fourfifths = 0xab5;
pub const XK_onesixth = 0xab6;
pub const XK_fivesixths = 0xab7;
pub const XK_careof = 0xab8;
pub const XK_figdash = 0xabb;
pub const XK_leftanglebracket = 0xabc;
pub const XK_decimalpoint = 0xabd;
pub const XK_rightanglebracket = 0xabe;
pub const XK_marker = 0xabf;
pub const XK_oneeighth = 0xac3;
pub const XK_threeeighths = 0xac4;
pub const XK_fiveeighths = 0xac5;
pub const XK_seveneighths = 0xac6;
pub const XK_trademark = 0xac9;
pub const XK_signaturemark = 0xaca;
pub const XK_trademarkincircle = 0xacb;
pub const XK_leftopentriangle = 0xacc;
pub const XK_rightopentriangle = 0xacd;
pub const XK_emopencircle = 0xace;
pub const XK_emopenrectangle = 0xacf;
pub const XK_leftsinglequotemark = 0xad0;
pub const XK_rightsinglequotemark = 0xad1;
pub const XK_leftdoublequotemark = 0xad2;
pub const XK_rightdoublequotemark = 0xad3;
pub const XK_prescription = 0xad4;
pub const XK_minutes = 0xad6;
pub const XK_seconds = 0xad7;
pub const XK_latincross = 0xad9;
pub const XK_hexagram = 0xada;
pub const XK_filledrectbullet = 0xadb;
pub const XK_filledlefttribullet = 0xadc;
pub const XK_filledrighttribullet = 0xadd;
pub const XK_emfilledcircle = 0xade;
pub const XK_emfilledrect = 0xadf;
pub const XK_enopencircbullet = 0xae0;
pub const XK_enopensquarebullet = 0xae1;
pub const XK_openrectbullet = 0xae2;
pub const XK_opentribulletup = 0xae3;
pub const XK_opentribulletdown = 0xae4;
pub const XK_openstar = 0xae5;
pub const XK_enfilledcircbullet = 0xae6;
pub const XK_enfilledsqbullet = 0xae7;
pub const XK_filledtribulletup = 0xae8;
pub const XK_filledtribulletdown = 0xae9;
pub const XK_leftpointer = 0xaea;
pub const XK_rightpointer = 0xaeb;
pub const XK_club = 0xaec;
pub const XK_diamond = 0xaed;
pub const XK_heart = 0xaee;
pub const XK_maltesecross = 0xaf0;
pub const XK_dagger = 0xaf1;
pub const XK_doubledagger = 0xaf2;
pub const XK_checkmark = 0xaf3;
pub const XK_ballotcross = 0xaf4;
pub const XK_musicalsharp = 0xaf5;
pub const XK_musicalflat = 0xaf6;
pub const XK_malesymbol = 0xaf7;
pub const XK_femalesymbol = 0xaf8;
pub const XK_telephone = 0xaf9;
pub const XK_telephonerecorder = 0xafa;
pub const XK_phonographcopyright = 0xafb;
pub const XK_caret = 0xafc;
pub const XK_singlelowquotemark = 0xafd;
pub const XK_doublelowquotemark = 0xafe;
pub const XK_cursor = 0xaff;
pub const XK_leftcaret = 0xba3;
pub const XK_rightcaret = 0xba6;
pub const XK_downcaret = 0xba8;
pub const XK_upcaret = 0xba9;
pub const XK_overbar = 0xbc0;
pub const XK_downtack = 0xbc2;
pub const XK_upshoe = 0xbc3;
pub const XK_downstile = 0xbc4;
pub const XK_underbar = 0xbc6;
pub const XK_jot = 0xbca;
pub const XK_quad = 0xbcc;
pub const XK_uptack = 0xbce;
pub const XK_circle = 0xbcf;
pub const XK_upstile = 0xbd3;
pub const XK_downshoe = 0xbd6;
pub const XK_rightshoe = 0xbd8;
pub const XK_leftshoe = 0xbda;
pub const XK_lefttack = 0xbdc;
pub const XK_righttack = 0xbfc;
pub const XK_hebrew_doublelowline = 0xcdf;
pub const XK_hebrew_aleph = 0xce0;
pub const XK_hebrew_bet = 0xce1;
pub const XK_hebrew_beth = 0xce1;
pub const XK_hebrew_gimel = 0xce2;
pub const XK_hebrew_gimmel = 0xce2;
pub const XK_hebrew_dalet = 0xce3;
pub const XK_hebrew_daleth = 0xce3;
pub const XK_hebrew_he = 0xce4;
pub const XK_hebrew_waw = 0xce5;
pub const XK_hebrew_zain = 0xce6;
pub const XK_hebrew_zayin = 0xce6;
pub const XK_hebrew_chet = 0xce7;
pub const XK_hebrew_het = 0xce7;
pub const XK_hebrew_tet = 0xce8;
pub const XK_hebrew_teth = 0xce8;
pub const XK_hebrew_yod = 0xce9;
pub const XK_hebrew_finalkaph = 0xcea;
pub const XK_hebrew_kaph = 0xceb;
pub const XK_hebrew_lamed = 0xcec;
pub const XK_hebrew_finalmem = 0xced;
pub const XK_hebrew_mem = 0xcee;
pub const XK_hebrew_finalnun = 0xcef;
pub const XK_hebrew_nun = 0xcf0;
pub const XK_hebrew_samech = 0xcf1;
pub const XK_hebrew_samekh = 0xcf1;
pub const XK_hebrew_ayin = 0xcf2;
pub const XK_hebrew_finalpe = 0xcf3;
pub const XK_hebrew_pe = 0xcf4;
pub const XK_hebrew_finalzade = 0xcf5;
pub const XK_hebrew_finalzadi = 0xcf5;
pub const XK_hebrew_zade = 0xcf6;
pub const XK_hebrew_zadi = 0xcf6;
pub const XK_hebrew_qoph = 0xcf7;
pub const XK_hebrew_kuf = 0xcf7;
pub const XK_hebrew_resh = 0xcf8;
pub const XK_hebrew_shin = 0xcf9;
pub const XK_hebrew_taw = 0xcfa;
pub const XK_hebrew_taf = 0xcfa;
pub const XK_Hebrew_switch = 0xFF7E;

pub const XF86XK_ModeLock = 0x1008FF01;
pub const XF86XK_MonBrightnessUp = 0x1008FF02;
pub const XF86XK_MonBrightnessDown = 0x1008FF03;
pub const XF86XK_KbdLightOnOff = 0x1008FF04;
pub const XF86XK_KbdBrightnessUp = 0x1008FF05;
pub const XF86XK_KbdBrightnessDown = 0x1008FF06;
pub const XF86XK_Standby = 0x1008FF10;
pub const XF86XK_AudioLowerVolume = 0x1008FF11;
pub const XF86XK_AudioMute = 0x1008FF12;
pub const XF86XK_AudioRaiseVolume = 0x1008FF13;
pub const XF86XK_AudioPlay = 0x1008FF14;
pub const XF86XK_AudioStop = 0x1008FF15;
pub const XF86XK_AudioPrev = 0x1008FF16;
pub const XF86XK_AudioNext = 0x1008FF17;
pub const XF86XK_HomePage = 0x1008FF18;
pub const XF86XK_Mail = 0x1008FF19;
pub const XF86XK_Start = 0x1008FF1A;
pub const XF86XK_Search = 0x1008FF1B;
pub const XF86XK_AudioRecord = 0x1008FF1C;
pub const XF86XK_Calculator = 0x1008FF1D;
pub const XF86XK_Memo = 0x1008FF1E;
pub const XF86XK_ToDoList = 0x1008FF1F;
pub const XF86XK_Calendar = 0x1008FF20;
pub const XF86XK_PowerDown = 0x1008FF21;
pub const XF86XK_ContrastAdjust = 0x1008FF22;
pub const XF86XK_RockerUp = 0x1008FF23;
pub const XF86XK_RockerDown = 0x1008FF24;
pub const XF86XK_RockerEnter = 0x1008FF25;
pub const XF86XK_Back = 0x1008FF26;
pub const XF86XK_Forward = 0x1008FF27;
pub const XF86XK_Stop = 0x1008FF28;
pub const XF86XK_Refresh = 0x1008FF29;
pub const XF86XK_PowerOff = 0x1008FF2A;
pub const XF86XK_WakeUp = 0x1008FF2B;
pub const XF86XK_Eject = 0x1008FF2C;
pub const XF86XK_ScreenSaver = 0x1008FF2D;
pub const XF86XK_WWW = 0x1008FF2E;
pub const XF86XK_Sleep = 0x1008FF2F;
pub const XF86XK_Favorites = 0x1008FF30;
pub const XF86XK_AudioPause = 0x1008FF31;
pub const XF86XK_AudioMedia = 0x1008FF32;
pub const XF86XK_MyComputer = 0x1008FF33;
pub const XF86XK_VendorHome = 0x1008FF34;
pub const XF86XK_LightBulb = 0x1008FF35;
pub const XF86XK_Shop = 0x1008FF36;
pub const XF86XK_History = 0x1008FF37;
pub const XF86XK_OpenURL = 0x1008FF38;
pub const XF86XK_AddFavorite = 0x1008FF39;
pub const XF86XK_HotLinks = 0x1008FF3A;
pub const XF86XK_BrightnessAdjust = 0x1008FF3B;
pub const XF86XK_Finance = 0x1008FF3C;
pub const XF86XK_Community = 0x1008FF3D;
pub const XF86XK_AudioRewind = 0x1008FF3E;
pub const XF86XK_BackForward = 0x1008FF3F;
pub const XF86XK_Launch0 = 0x1008FF40;
pub const XF86XK_Launch1 = 0x1008FF41;
pub const XF86XK_Launch2 = 0x1008FF42;
pub const XF86XK_Launch3 = 0x1008FF43;
pub const XF86XK_Launch4 = 0x1008FF44;
pub const XF86XK_Launch5 = 0x1008FF45;
pub const XF86XK_Launch6 = 0x1008FF46;
pub const XF86XK_Launch7 = 0x1008FF47;
pub const XF86XK_Launch8 = 0x1008FF48;
pub const XF86XK_Launch9 = 0x1008FF49;
pub const XF86XK_LaunchA = 0x1008FF4A;
pub const XF86XK_LaunchB = 0x1008FF4B;
pub const XF86XK_LaunchC = 0x1008FF4C;
pub const XF86XK_LaunchD = 0x1008FF4D;
pub const XF86XK_LaunchE = 0x1008FF4E;
pub const XF86XK_LaunchF = 0x1008FF4F;
pub const XF86XK_ApplicationLeft = 0x1008FF50;
pub const XF86XK_ApplicationRight = 0x1008FF51;
pub const XF86XK_Book = 0x1008FF52;
pub const XF86XK_CD = 0x1008FF53;
pub const XF86XK_Calculater = 0x1008FF54;
pub const XF86XK_Clear = 0x1008FF55;
pub const XF86XK_Close = 0x1008FF56;
pub const XF86XK_Copy = 0x1008FF57;
pub const XF86XK_Cut = 0x1008FF58;
pub const XF86XK_Display = 0x1008FF59;
pub const XF86XK_DOS = 0x1008FF5A;
pub const XF86XK_Documents = 0x1008FF5B;
pub const XF86XK_Excel = 0x1008FF5C;
pub const XF86XK_Explorer = 0x1008FF5D;
pub const XF86XK_Game = 0x1008FF5E;
pub const XF86XK_Go = 0x1008FF5F;
pub const XF86XK_iTouch = 0x1008FF60;
pub const XF86XK_LogOff = 0x1008FF61;
pub const XF86XK_Market = 0x1008FF62;
pub const XF86XK_Meeting = 0x1008FF63;
pub const XF86XK_MenuKB = 0x1008FF65;
pub const XF86XK_MenuPB = 0x1008FF66;
pub const XF86XK_MySites = 0x1008FF67;
pub const XF86XK_New = 0x1008FF68;
pub const XF86XK_News = 0x1008FF69;
pub const XF86XK_OfficeHome = 0x1008FF6A;
pub const XF86XK_Open = 0x1008FF6B;
pub const XF86XK_Option = 0x1008FF6C;
pub const XF86XK_Paste = 0x1008FF6D;
pub const XF86XK_Phone = 0x1008FF6E;
pub const XF86XK_Q = 0x1008FF70;
pub const XF86XK_Reply = 0x1008FF72;
pub const XF86XK_Reload = 0x1008FF73;
pub const XF86XK_RotateWindows = 0x1008FF74;
pub const XF86XK_RotationPB = 0x1008FF75;
pub const XF86XK_RotationKB = 0x1008FF76;
pub const XF86XK_Save = 0x1008FF77;
pub const XF86XK_ScrollUp = 0x1008FF78;
pub const XF86XK_ScrollDown = 0x1008FF79;
pub const XF86XK_ScrollClick = 0x1008FF7A;
pub const XF86XK_Send = 0x1008FF7B;
pub const XF86XK_Spell = 0x1008FF7C;
pub const XF86XK_SplitScreen = 0x1008FF7D;
pub const XF86XK_Support = 0x1008FF7E;
pub const XF86XK_TaskPane = 0x1008FF7F;
pub const XF86XK_Terminal = 0x1008FF80;
pub const XF86XK_Tools = 0x1008FF81;
pub const XF86XK_Travel = 0x1008FF82;
pub const XF86XK_UserPB = 0x1008FF84;
pub const XF86XK_User1KB = 0x1008FF85;
pub const XF86XK_User2KB = 0x1008FF86;
pub const XF86XK_Video = 0x1008FF87;
pub const XF86XK_WheelButton = 0x1008FF88;
pub const XF86XK_Word = 0x1008FF89;
pub const XF86XK_Xfer = 0x1008FF8A;
pub const XF86XK_ZoomIn = 0x1008FF8B;
pub const XF86XK_ZoomOut = 0x1008FF8C;
pub const XF86XK_Away = 0x1008FF8D;
pub const XF86XK_Messenger = 0x1008FF8E;
pub const XF86XK_WebCam = 0x1008FF8F;
pub const XF86XK_MailForward = 0x1008FF90;
pub const XF86XK_Pictures = 0x1008FF91;
pub const XF86XK_Music = 0x1008FF92;
pub const XF86XK_Battery = 0x1008FF93;
pub const XF86XK_Bluetooth = 0x1008FF94;
pub const XF86XK_WLAN = 0x1008FF95;
pub const XF86XK_UWB = 0x1008FF96;
pub const XF86XK_AudioForward = 0x1008FF97;
pub const XF86XK_AudioRepeat = 0x1008FF98;
pub const XF86XK_AudioRandomPlay = 0x1008FF99;
pub const XF86XK_Subtitle = 0x1008FF9A;
pub const XF86XK_AudioCycleTrack = 0x1008FF9B;
pub const XF86XK_CycleAngle = 0x1008FF9C;
pub const XF86XK_FrameBack = 0x1008FF9D;
pub const XF86XK_FrameForward = 0x1008FF9E;
pub const XF86XK_Time = 0x1008FF9F;
pub const XF86XK_Select = 0x1008FFA0;
pub const XF86XK_View = 0x1008FFA1;
pub const XF86XK_TopMenu = 0x1008FFA2;
pub const XF86XK_Red = 0x1008FFA3;
pub const XF86XK_Green = 0x1008FFA4;
pub const XF86XK_Yellow = 0x1008FFA5;
pub const XF86XK_Blue = 0x1008FFA6;
pub const XF86XK_Suspend = 0x1008FFA7;
pub const XF86XK_Hibernate = 0x1008FFA8;
pub const XF86XK_TouchpadToggle = 0x1008FFA9;
pub const XF86XK_TouchpadOn = 0x1008FFB0;
pub const XF86XK_TouchpadOff = 0x1008FFB1;
pub const XF86XK_AudioMicMute = 0x1008FFB2;
pub const XF86XK_Switch_VT_1 = 0x1008FE01;
pub const XF86XK_Switch_VT_2 = 0x1008FE02;
pub const XF86XK_Switch_VT_3 = 0x1008FE03;
pub const XF86XK_Switch_VT_4 = 0x1008FE04;
pub const XF86XK_Switch_VT_5 = 0x1008FE05;
pub const XF86XK_Switch_VT_6 = 0x1008FE06;
pub const XF86XK_Switch_VT_7 = 0x1008FE07;
pub const XF86XK_Switch_VT_8 = 0x1008FE08;
pub const XF86XK_Switch_VT_9 = 0x1008FE09;
pub const XF86XK_Switch_VT_10 = 0x1008FE0A;
pub const XF86XK_Switch_VT_11 = 0x1008FE0B;
pub const XF86XK_Switch_VT_12 = 0x1008FE0C;
pub const XF86XK_Ungrab = 0x1008FE20;
pub const XF86XK_ClearGrab = 0x1008FE21;
pub const XF86XK_Next_VMode = 0x1008FE22;
pub const XF86XK_Prev_VMode = 0x1008FE23;
pub const XF86XK_LogWindowTree = 0x1008FE24;
pub const XF86XK_LogGrabInfo = 0x1008FE25;

pub const XK_ISO_Lock = 0xfe01;
pub const XK_ISO_Level2_Latch = 0xfe02;
pub const XK_ISO_Level3_Shift = 0xfe03;
pub const XK_ISO_Level3_Latch = 0xfe04;
pub const XK_ISO_Level3_Lock = 0xfe05;
pub const XK_ISO_Level5_Shift = 0xfe11;
pub const XK_ISO_Level5_Latch = 0xfe12;
pub const XK_ISO_Level5_Lock = 0xfe13;
pub const XK_ISO_Group_Shift = 0xff7e;
pub const XK_ISO_Group_Latch = 0xfe06;
pub const XK_ISO_Group_Lock = 0xfe07;
pub const XK_ISO_Next_Group = 0xfe08;
pub const XK_ISO_Next_Group_Lock = 0xfe09;
pub const XK_ISO_Prev_Group = 0xfe0a;
pub const XK_ISO_Prev_Group_Lock = 0xfe0b;
pub const XK_ISO_First_Group = 0xfe0c;
pub const XK_ISO_First_Group_Lock = 0xfe0d;
pub const XK_ISO_Last_Group = 0xfe0e;
pub const XK_ISO_Last_Group_Lock = 0xfe0f;

pub const XK_ISO_Left_Tab = 0xfe20;
pub const XK_ISO_Move_Line_Up = 0xfe21;
pub const XK_ISO_Move_Line_Down = 0xfe22;
pub const XK_ISO_Partial_Line_Up = 0xfe23;
pub const XK_ISO_Partial_Line_Down = 0xfe24;
pub const XK_ISO_Partial_Space_Left = 0xfe25;
pub const XK_ISO_Partial_Space_Right = 0xfe26;
pub const XK_ISO_Set_Margin_Left = 0xfe27;
pub const XK_ISO_Set_Margin_Right = 0xfe28;
pub const XK_ISO_Release_Margin_Left = 0xfe29;
pub const XK_ISO_Release_Margin_Right = 0xfe2a;
pub const XK_ISO_Release_Both_Margins = 0xfe2b;
pub const XK_ISO_Fast_Cursor_Left = 0xfe2c;
pub const XK_ISO_Fast_Cursor_Right = 0xfe2d;
pub const XK_ISO_Fast_Cursor_Up = 0xfe2e;
pub const XK_ISO_Fast_Cursor_Down = 0xfe2f;
pub const XK_ISO_Continuous_Underline = 0xfe30;
pub const XK_ISO_Discontinuous_Underline = 0xfe31;
pub const XK_ISO_Emphasize = 0xfe32;
pub const XK_ISO_Center_Object = 0xfe33;
pub const XK_ISO_Enter = 0xfe34;

pub const XK_dead_grave = 0xfe50;
pub const XK_dead_acute = 0xfe51;
pub const XK_dead_circumflex = 0xfe52;
pub const XK_dead_tilde = 0xfe53;
pub const XK_dead_perispomeni = 0xfe53;
pub const XK_dead_macron = 0xfe54;
pub const XK_dead_breve = 0xfe55;
pub const XK_dead_abovedot = 0xfe56;
pub const XK_dead_diaeresis = 0xfe57;
pub const XK_dead_abovering = 0xfe58;
pub const XK_dead_doubleacute = 0xfe59;
pub const XK_dead_caron = 0xfe5a;
pub const XK_dead_cedilla = 0xfe5b;
pub const XK_dead_ogonek = 0xfe5c;
pub const XK_dead_iota = 0xfe5d;
pub const XK_dead_voiced_sound = 0xfe5e;
pub const XK_dead_semivoiced_sound = 0xfe5f;
pub const XK_dead_belowdot = 0xfe60;
pub const XK_dead_hook = 0xfe61;
pub const XK_dead_horn = 0xfe62;
pub const XK_dead_stroke = 0xfe63;
pub const XK_dead_abovecomma = 0xfe64;
pub const XK_dead_psili = 0xfe64;
pub const XK_dead_abovereversedcomma = 0xfe65;
pub const XK_dead_dasia = 0xfe65;
pub const XK_dead_doublegrave = 0xfe66;
pub const XK_dead_belowring = 0xfe67;
pub const XK_dead_belowmacron = 0xfe68;
pub const XK_dead_belowcircumflex = 0xfe69;
pub const XK_dead_belowtilde = 0xfe6a;
pub const XK_dead_belowbreve = 0xfe6b;
pub const XK_dead_belowdiaeresis = 0xfe6c;
pub const XK_dead_invertedbreve = 0xfe6d;
pub const XK_dead_belowcomma = 0xfe6e;
pub const XK_dead_currency = 0xfe6f;

pub const XK_dead_lowline = 0xfe90;
pub const XK_dead_aboveverticalline = 0xfe91;
pub const XK_dead_belowverticalline = 0xfe92;
pub const XK_dead_longsolidusoverlay = 0xfe93;

pub const XK_dead_a = 0xfe80;
pub const XK_dead_A = 0xfe81;
pub const XK_dead_e = 0xfe82;
pub const XK_dead_E = 0xfe83;
pub const XK_dead_i = 0xfe84;
pub const XK_dead_I = 0xfe85;
pub const XK_dead_o = 0xfe86;
pub const XK_dead_O = 0xfe87;
pub const XK_dead_u = 0xfe88;
pub const XK_dead_U = 0xfe89;
pub const XK_dead_small_schwa = 0xfe8a;
pub const XK_dead_capital_schwa = 0xfe8b;

pub const XK_dead_greek = 0xfe8c;

pub const XK_First_Virtual_Screen = 0xfed0;
pub const XK_Prev_Virtual_Screen = 0xfed1;
pub const XK_Next_Virtual_Screen = 0xfed2;
pub const XK_Last_Virtual_Screen = 0xfed4;
pub const XK_Terminate_Server = 0xfed5;

pub const XK_AccessX_Enable = 0xfe70;
pub const XK_AccessX_Feedback_Enable = 0xfe71;
pub const XK_RepeatKeys_Enable = 0xfe72;
pub const XK_SlowKeys_Enable = 0xfe73;
pub const XK_BounceKeys_Enable = 0xfe74;
pub const XK_StickyKeys_Enable = 0xfe75;
pub const XK_MouseKeys_Enable = 0xfe76;
pub const XK_MouseKeys_Accel_Enable = 0xfe77;
pub const XK_Overlay1_Enable = 0xfe78;
pub const XK_Overlay2_Enable = 0xfe79;
pub const XK_AudibleBell_Enable = 0xfe7a;

pub const XK_Pointer_Left = 0xfee0;
pub const XK_Pointer_Right = 0xfee1;
pub const XK_Pointer_Up = 0xfee2;
pub const XK_Pointer_Down = 0xfee3;
pub const XK_Pointer_UpLeft = 0xfee4;
pub const XK_Pointer_UpRight = 0xfee5;
pub const XK_Pointer_DownLeft = 0xfee6;
pub const XK_Pointer_DownRight = 0xfee7;
pub const XK_Pointer_Button_Dflt = 0xfee8;
pub const XK_Pointer_Button1 = 0xfee9;
pub const XK_Pointer_Button2 = 0xfeea;
pub const XK_Pointer_Button3 = 0xfeeb;
pub const XK_Pointer_Button4 = 0xfeec;
pub const XK_Pointer_Button5 = 0xfeed;
pub const XK_Pointer_DblClick_Dflt = 0xfeee;
pub const XK_Pointer_DblClick1 = 0xfeef;
pub const XK_Pointer_DblClick2 = 0xfef0;
pub const XK_Pointer_DblClick3 = 0xfef1;
pub const XK_Pointer_DblClick4 = 0xfef2;
pub const XK_Pointer_DblClick5 = 0xfef3;
pub const XK_Pointer_Drag_Dflt = 0xfef4;
pub const XK_Pointer_Drag1 = 0xfef5;
pub const XK_Pointer_Drag2 = 0xfef6;
pub const XK_Pointer_Drag3 = 0xfef7;
pub const XK_Pointer_Drag4 = 0xfef8;
pub const XK_Pointer_Drag5 = 0xfefd;

pub const XK_Pointer_EnableKeys = 0xfef9;
pub const XK_Pointer_Accelerate = 0xfefa;
pub const XK_Pointer_DfltBtnNext = 0xfefb;
pub const XK_Pointer_DfltBtnPrev = 0xfefc;

pub const XK_ch = 0xfea0;
pub const XK_Ch = 0xfea1;
pub const XK_CH = 0xfea2;
pub const XK_c_h = 0xfea3;
pub const XK_C_h = 0xfea4;
pub const XK_C_H = 0xfea5;

//=====================
// Dynamic api
//=====================

// One of the major goals of this widow is to allow cross compilation of any project that
// depends on it, for now cross compiling from linux targeting windows is achieved thanks to zig
// To allow cross compilation from windows targeting linux we need to stop linking against
// X11 system library and instead load it at runtime.
const so = @import("common").unix.so;
const xkb = @import("extensions/xkb.zig");

pub const dyn_api = struct {
    // Functions Types:
    const XOpenDisplayProc = *const fn (display_name: ?[*:0]u8) callconv(.c) ?*Display;
    const XCloseDisplayProc = *const fn (display: ?*Display) callconv(.c) c_int;
    const XInitExtensionProc = *const fn (
        display: ?*Display,
        ext_name: ?[*:0]const u8,
    ) callconv(.c) ?[*]XExtCodes;
    const XAddExtensionProc = *const fn (display: ?*Display) callconv(.c) ?[*]XExtCodes;

    // Multithreading routines.
    const XInitThreadsProc = *const fn () callconv(.c) c_int;
    const XLockDisplayProc = *const fn (dispaly: ?*Display) callconv(.c) void;
    const XUnlockDisplayProc = *const fn (display: ?*Display) callconv(.c) void;

    // Ressource Manager
    const XrmInitializeProc = *const fn () callconv(.c) void;
    const XResourceManagerStringProc = *const fn (display: ?*Display) callconv(.c) ?[*:0]const u8;
    const XrmGetStringDatabaseProc = *const fn (data: ?[*:0]const u8) callconv(.c) XrmDatabase;
    const XrmDestroyDatabaseProc = *const fn (db: XrmDatabase) callconv(.c) void;
    const XrmGetResourceProc = *const fn (
        db: XrmDatabase,
        str_name: [*:0]const u8,
        str_class: [*:0]const u8,
        str_type_return: *?[*:0]const u8,
        value_return: *XrmValue,
    ) callconv(.c) Bool;
    const XrmUniqueQuarkProc = *const fn () callconv(.c) XrmQuark;

    // Window Management
    const XCreateSimpleWindowProc = *const fn (
        display: ?*Display,
        parent: Window,
        x: c_int,
        y: c_int,
        width: c_uint,
        height: c_uint,
        border_width: c_uint,
        border: c_ulong,
        background: c_ulong,
    ) callconv(.c) Window;
    const XCreateWindowProc = *const fn (
        display: ?*Display,
        parent: Window,
        x: c_int,
        y: c_int,
        width: c_uint,
        height: c_uint,
        border_width: c_uint,
        depth: c_int,
        class: c_uint,
        visual: ?*Visual,
        value_mask: c_ulong,
        attributes: ?[*]XSetWindowAttributes,
    ) callconv(.c) Window;
    const XCreateColormapProc = *const fn (
        display: ?*Display,
        w: Window,
        visual: ?*Visual,
        alloc: c_int,
    ) callconv(.c) Colormap;
    const XDestroyWindowProc = *const fn (
        display: ?*Display,
        window: Window,
    ) callconv(.c) c_int;
    const XMapWindowProc = *const fn (
        display: ?*Display,
        window: Window,
    ) callconv(.c) c_int;
    const XMapRaisedProc = *const fn (
        display: ?*Display,
        window: Window,
    ) callconv(.c) c_int;
    const XUnmapWindowProc = *const fn (
        display: ?*Display,
        window: Window,
    ) callconv(.c) c_int;
    const XMoveWindowProc = *const fn (
        display: ?*Display,
        window: Window,
        x: c_int,
        y: c_int,
    ) callconv(.c) c_int;
    const XResizeWindowProc = *const fn (
        display: ?*Display,
        window: Window,
        width: c_uint,
        height: c_uint,
    ) callconv(.c) c_int;
    const XMoveResizeWindowProc = *const fn (
        display: ?*Display,
        window: Window,
        x: c_int,
        y: c_int,
        width: c_uint,
        height: c_uint,
    ) callconv(.c) c_int;
    const XIconifyWindowProc = *const fn (
        display: ?*Display,
        window: Window,
        screen_number: c_int,
    ) callconv(.c) Status;
    // Properties
    const XSetWMProtocolsProc = *const fn (
        display: ?*Display,
        window: Window,
        atoms: ?[*]Atom,
        count: c_int,
    ) callconv(.c) Status;
    const XChangePropertyProc = *const fn (
        display: ?*Display,
        w: Window,
        property: Atom,
        prop_type: Atom,
        format: c_int,
        mode: c_int,
        data: [*]const u8,
        nelements: c_int,
    ) callconv(.c) void;
    const XDeletePropertyProc = *const fn (
        display: ?*Display,
        w: Window,
        property: Atom,
    ) callconv(.c) void;
    const XGetWindowPropertyProc = *const fn (
        display: ?*Display,
        w: Window,
        property: Atom,
        long_offset: c_long,
        long_lenght: c_long,
        delete: Bool,
        req_type: Atom,
        actual_type_return: *Atom,
        actual_format_return: *c_int,
        nitems_return: *c_ulong,
        bytes_after_return: *c_ulong,
        prop_return: ?[*]?[*]u8,
    ) callconv(.c) c_int;
    const XInternAtomProc = *const fn (
        display: ?*Display,
        atom_name: [*:0]const u8,
        if_exist: Bool,
    ) callconv(.c) Atom;

    // XUtil
    const XUniqueContextProc = XrmUniqueQuarkProc;
    const XSaveContextProc = *const fn (
        display: ?*Display,
        rid: XID,
        context: XContext,
        data: XPointer,
    ) callconv(.c) c_int;
    const XFindContextProc = *const fn (
        display: ?*Display,
        rid: XID,
        context: XContext,
        data_return: *XPointer,
    ) callconv(.c) c_int;
    const XDeleteContextProc = *const fn (
        display: ?*Display,
        rid: XID,
        context: XContext,
    ) callconv(.c) c_int;
    const XGetScreenSaverProc = *const fn (
        display: ?*Display,
        timout: *c_int,
        interval: *c_int,
        prefer_blanking: *c_int,
        allow_exposures: *c_int,
    ) callconv(.c) c_int;
    const XSetScreenSaverProc = *const fn (
        display: ?*Display,
        timout: c_int,
        interval: c_int,
        prefer_blanking: c_int,
        allow_exposures: c_int,
    ) callconv(.c) c_int;

    // Events
    const XNextEventProc = *const fn (
        display: *Display,
        x_event: *XEvent,
    ) callconv(.c) c_int;
    const XPeekEventProc = *const fn (
        display: *Display,
        x_event: *XEvent,
    ) callconv(.c) c_int;
    const XPendingProc = *const fn (display: *Display) callconv(.c) c_int;
    const XQLengthProc = *const fn (display: *Display) callconv(.c) c_int;
    const XSendEventProc = *const fn (
        display: *Display,
        w: Window,
        propagate: Bool,
        event_mask: c_long,
        event: *XEvent,
    ) callconv(.c) Status;
    const XSyncProc = *const fn (
        display: *Display,
        discard: Bool,
    ) callconv(.c) void;
    const XFlushProc = *const fn (display: *Display) callconv(.c) c_int;
    const XEventsQueuedProc = *const fn (display: ?*Display, mode: c_int) callconv(.c) c_int;
    const XGetEventDataProc = *const fn (display: ?*Display, cookie: *XGenericEventCookie) callconv(.c) Bool;
    const XFreeEventDataProc = *const fn (display: ?*Display, cookie: *XGenericEventCookie) callconv(.c) void;
    const XCheckTypedWindowEventProc = *const fn (
        display: *Display,
        w: Window,
        event_type: c_int,
        x_event: *XEvent,
    ) callconv(.c) Bool;

    // Errors
    const XSetErrorHandlerProc = *const fn (
        handler: ?*const XErrorHandlerFunc,
    ) callconv(.c) ?*const XErrorHandlerFunc;

    // Misc
    const XFreeProc = *const fn (data: *anyopaque) callconv(.c) c_int;
    const XAllocWMHintsProc = *const fn () callconv(.c) ?*XWMHints;
    const XAllocClassHintProc = *const fn () callconv(.c) ?*XClassHint;
    const XAllocSizeHintsProc = *const fn () callconv(.c) ?*XSizeHints;
    // const XAllocIconSize = *const fn () ?*XIconSize;
    // const XAllocStandardColormap = *const fn () ?*XStandardColormap;
    const XSetWMHintsProc = *const fn (
        display: ?*Display,
        window: Window,
        hints: ?[*]XSizeHints,
    ) callconv(.c) void;
    const XSetWMNormalHintsProc = *const fn (
        display: ?*Display,
        window: Window,
        hints: ?[*]XWMHints,
    ) callconv(.c) void;
    const XSetClassHintProc = *const fn (
        display: ?*Display,
        window: Window,
        hints: ?[*]XClassHint,
    ) callconv(.c) c_int;

    // Keyboard.
    const XDisplayKeycodesProc = *const fn (
        display: ?*Display,
        min_keycodes_return: *c_int,
        max_keycodes_return: *c_int,
    ) callconv(.c) c_int;

    const XGetKeyboardMappingProc = *const fn (
        display: ?*Display,
        first_keycode: KeyCode,
        keycode_count: c_int,
        keysyms_per_keycode_return: *c_int,
    ) callconv(.c) ?[*]KeySym;

    const XLookupStringProc = *const fn (
        event_struct: *XKeyEvent,
        buffer_return: ?[*:0]u8,
        bytes_buffer: c_int,
        keysym_return: ?*KeySym,
        status_in_out: ?*XComposeStatus,
    ) callconv(.c) c_int;

    const XQueryPointerProc = *const fn (
        display: ?*Display,
        w: Window,
        root: ?*Window,
        child_ret: ?*Window,
        root_x_ret: ?*c_int,
        root_y_ret: ?*c_int,
        win_x_ret: ?*c_int,
        win_y_ret: ?*c_int,
        mask_ret: ?*c_uint,
    ) callconv(.c) Bool;

    const XWarpPointerProc = *const fn (
        display: ?*Display,
        src_w: Window,
        dest_w: Window,
        src_x: c_int,
        src_y: c_int,
        src_width: c_uint,
        src_height: c_uint,
        dest_x: c_int,
        dest_y: c_int,
    ) callconv(.c) c_int;

    const XGetWindowAttributesProc = *const fn (
        display: ?*Display,
        w: Window,
        attribs_return: *XWindowAttributes,
    ) callconv(.c) Status;

    const XCreateFontCursorProc = *const fn (
        display: ?*Display,
        shape: c_uint,
    ) callconv(.c) Cursor;

    const XFreeCursorProc = *const fn (
        display: ?*Display,
        cursor: Cursor,
    ) callconv(.c) c_int;

    const XDefineCursorProc = *const fn (
        display: ?*Display,
        w: Window,
        cursor: Cursor,
    ) callconv(.c) c_int;

    const XUndefineCursorProc = *const fn (
        display: ?*Display,
        w: Window,
    ) callconv(.c) c_int;

    const XGrabPointerProc = *const fn (
        display: ?*Display,
        grab_window: Window,
        owner_event: Bool,
        event_mask: c_uint,
        pointer_mode: c_int,
        keyboard_mode: c_int,
        confine_to: Window,
        cursor: Cursor,
        time: Time,
    ) callconv(.c) c_int;

    const XUngrabPointerProc = *const fn (
        display: ?*Display,
        time: Time,
    ) callconv(.c) void;

    const XRaiseWindowProc = *const fn (
        display: ?*Display,
        window: Window,
    ) callconv(.c) void;

    const XSetInputFocusProc = *const fn (
        display: ?*Display,
        window: Window,
        revert_to: c_int,
        time: Time,
    ) callconv(.c) void;

    const XGetWMNormalHintsProc = *const fn (
        display: ?*Display,
        window: Window,
        hints_return: *XSizeHints,
        supplied_return: *c_long,
    ) callconv(.c) Status;

    const XConvertSelectionProc = *const fn (
        display: ?*Display,
        selection: Atom,
        target: Atom,
        property: Atom,
        requestor: Window,
        time: Time,
    ) callconv(.c) void;

    const XTranslateCoordinatesProc = *const fn (
        display: ?*Display,
        src_w: Window,
        dest_w: Window,
        src_x: c_int,
        src_y: c_int,
        dest_x: *c_int,
        dest_y: *c_int,
        child_ret: *Window,
    ) callconv(.c) Bool;

    const XQueryExtensionProc = *const fn (
        display: ?*Display,
        name: [*:0]const u8,
        major_opcode: *c_int,
        first_event_code: *c_int,
        first_error_code: *c_int,
    ) callconv(.c) Bool;

    const XCreateGCProc = *const fn (
        display: ?*Display,
        d: Drawable,
        valuemask: c_ulong,
        values: ?*XGCValues,
    ) callconv(.c) GC;

    const XFreeGCProc = *const fn (
        display: ?*Display,
        gc: GC,
    ) callconv(.c) void;

    const XGetVisualInfoProc = *const fn (
        display: ?*Display,
        vinfo_mask: c_long,
        vinfo_template: *XVisualInfo,
        nitems_return: *c_int,
    ) callconv(.c) ?*XVisualInfo;

    const XVisualIDFromVisualProc = *const fn (
        visual: ?*Visual,
    ) callconv(.c) VisualID;

    const XListPixmapFormatsProc = *const fn (
        display: ?*Display,
        count_return: *c_int,
    ) callconv(.c) ?[*]XPixmapFormatValues;

    const XCreateImageProc = *const fn (
        display: ?*Display,
        visual: *Visual,
        depth: c_uint,
        format: c_int,
        offset: c_int,
        data: ?[*]u8,
        width: c_uint,
        height: c_uint,
        bitmap_pad: c_int,
        bytes_per_line: c_int,
    ) callconv(.c) ?*XImage;

    const XPutImageProc = *const fn (
        display: ?*Display,
        d: Drawable,
        gc: GC,
        image: *XImage,
        src_x: c_int,
        src_y: c_int,
        dest_x: c_int,
        dest_y: c_int,
        width: c_uint,
        height: c_uint,
    ) callconv(.c) void;

    const XDestroyImageProc = *const fn (image: *XImage) callconv(.c) void;

    // function pointers
    pub var XOpenDisplay: XOpenDisplayProc = undefined;
    pub var XCloseDisplay: XCloseDisplayProc = undefined;

    // Multithreading routines.
    pub var XInitThreads: XInitThreadsProc = undefined;

    // Ressource Manager
    pub var XrmInitialize: XrmInitializeProc = undefined;
    pub var XResourceManagerString: XResourceManagerStringProc = undefined;
    pub var XrmGetStringDatabase: XrmGetStringDatabaseProc = undefined;
    pub var XrmDestroyDatabase: XrmDestroyDatabaseProc = undefined;
    pub var XrmGetResource: XrmGetResourceProc = undefined;
    pub var XrmUniqueQuark: XrmUniqueQuarkProc = undefined;

    // Window Management.
    pub var XCreateSimpleWindow: XCreateSimpleWindowProc = undefined;
    pub var XCreateWindow: XCreateWindowProc = undefined;
    pub var XCreateColormap: XCreateColormapProc = undefined;
    pub var XDestroyWindow: XDestroyWindowProc = undefined;
    pub var XMapWindow: XMapWindowProc = undefined;
    pub var XMapRaised: XMapRaisedProc = undefined;
    pub var XUnmapWindow: XUnmapWindowProc = undefined;
    pub var XMoveWindow: XMoveWindowProc = undefined;
    pub var XMoveResizeWindow: XMoveResizeWindowProc = undefined;
    pub var XResizeWindow: XResizeWindowProc = undefined;
    pub var XIconifyWindow: XIconifyWindowProc = undefined;

    // XUtil
    pub var XSaveContext: XSaveContextProc = undefined;
    pub var XFindContext: XFindContextProc = undefined;
    pub var XDeleteContext: XDeleteContextProc = undefined;
    pub var XGetScreenSaver: XGetScreenSaverProc = undefined;
    pub var XSetScreenSaver: XSetScreenSaverProc = undefined;

    // Events
    pub var XNextEvent: XNextEventProc = undefined;
    pub var XPeekEvent: XPeekEventProc = undefined;
    pub var XPending: XPendingProc = undefined;
    pub var XQLength: XQLengthProc = undefined;
    pub var XSendEvent: XSendEventProc = undefined;
    pub var XSync: XSyncProc = undefined;
    pub var XFlush: XFlushProc = undefined;
    pub var XEventsQueued: XEventsQueuedProc = undefined;
    pub var XGetEventData: XGetEventDataProc = undefined;
    pub var XFreeEventData: XFreeEventDataProc = undefined;
    pub var XCheckTypedWindowEvent: XCheckTypedWindowEventProc = undefined;

    // Properties
    pub var XSetWMProtocols: XSetWMProtocolsProc = undefined;
    pub var XChangeProperty: XChangePropertyProc = undefined;
    pub var XDeleteProperty: XDeletePropertyProc = undefined;
    pub var XGetWindowProperty: XGetWindowPropertyProc = undefined;
    pub var XGetWindowAttributes: XGetWindowAttributesProc = undefined;
    pub var XInternAtom: XInternAtomProc = undefined;

    // Errors
    pub var XSetErrorHandler: XSetErrorHandlerProc = undefined;

    // Misc
    pub var XFree: XFreeProc = undefined;
    pub var XAllocWMHints: XAllocWMHintsProc = undefined;
    pub var XAllocSizeHints: XAllocSizeHintsProc = undefined;
    pub var XAllocClassHint: XAllocClassHintProc = undefined;
    pub var XSetWMHints: XSetWMHintsProc = undefined;
    pub var XSetWMNormalHints: XSetWMNormalHintsProc = undefined;
    pub var XSetClassHint: XSetClassHintProc = undefined;

    // xkb
    pub var XkbLibraryVersion: xkb.XkbLibraryVersionProc = undefined;
    pub var XkbQueryExtension: xkb.XkbQueryExtensionProc = undefined;
    pub var XkbGetDetectableAutoRepeat: xkb.XkbGetDetectableAutorepeatProc = undefined;
    pub var XkbSetDetectableAutoRepeat: xkb.XkbSetDetectableAutorepeatProc = undefined;
    pub var XkbGetNames: xkb.XkbGetNamesProc = undefined;
    pub var XkbFreeNames: xkb.XkbFreeNamesProc = undefined;
    pub var XkbGetState: xkb.XkbGetStateProc = undefined;
    pub var XkbGetMap: xkb.XkbGetMapProc = undefined;
    pub var XkbFreeClientMap: xkb.XkbFreeClientMapProc = undefined;
    pub var XkbKeycodeToKeysym: xkb.XkbKeycodeToKeysymProc = undefined;
    pub var XkbAllocKeyboard: xkb.XkbAllocKeyboardProc = undefined;
    pub var XkbFreeKeyboard: xkb.XkbFreeKeyboardProc = undefined;
    pub var XkbSelectEventDetails: xkb.XkbSelectEventDetailsProc = undefined;
    pub var XkbGetKeyboard: xkb.XkbGetKeyboardProc = undefined;

    // keyboard
    pub var XDisplayKeycodes: XDisplayKeycodesProc = undefined;
    pub var XGetKeyboardMapping: XGetKeyboardMappingProc = undefined;
    pub var XLookupString: XLookupStringProc = undefined;
    pub var XQueryPointer: XQueryPointerProc = undefined;
    pub var XWarpPointer: XWarpPointerProc = undefined;

    // cursor
    pub var XCreateFontCursor: XCreateFontCursorProc = undefined;
    pub var XFreeCursor: XFreeCursorProc = undefined;
    pub var XDefineCursor: XDefineCursorProc = undefined;
    pub var XUndefineCursor: XUndefineCursorProc = undefined;
    pub var XGrabPointer: XGrabPointerProc = undefined;
    pub var XUngrabPointer: XUngrabPointerProc = undefined;

    pub var XRaiseWindow: XRaiseWindowProc = undefined;
    pub var XSetInputFocus: XSetInputFocusProc = undefined;
    pub var XGetWMNormalHints: XGetWMNormalHintsProc = undefined;
    pub var XConvertSelection: XConvertSelectionProc = undefined;

    pub var XQueryExtension: XQueryExtensionProc = undefined;

    pub var XTranslateCoordinates: XTranslateCoordinatesProc = undefined;

    pub var XCreateGC: XCreateGCProc = undefined;
    pub var XFreeGC: XFreeGCProc = undefined;
    pub var XGetVisualInfo: XGetVisualInfoProc = undefined;
    pub var XVisualIDFromVisual: XVisualIDFromVisualProc = undefined;
    pub var XListPixmapFormats: XListPixmapFormatsProc = undefined;
    pub var XCreateImage: XCreateImageProc = undefined;
    pub var XPutImage: XPutImageProc = undefined;
    pub var XDestroyImage: XDestroyImageProc = undefined;
};

var __libx11_module: ?*anyopaque = null;

pub fn initDynamicApi() so.ModuleError!void {
    // Easy shortcut but require the field.name to be 0 terminated
    // since it will be passed to a c function.
    const MAX_NAME_LENGTH = 256;
    const info = @typeInfo(dyn_api);
    var field_name: [MAX_NAME_LENGTH]u8 = undefined;

    if (__libx11_module != null) {
        return;
    }

    __libx11_module = so.loadPosixModule(
        XORG_LIBS_NAME[LIB_X11_SONAME_INDEX],
    );
    if (__libx11_module) |m| {
        inline for (info.@"struct".decls) |*d| {
            if (comptime d.name.len > MAX_NAME_LENGTH - 1) {
                @compileError(
                    "Libx11 function name is greater than the maximum buffer length",
                );
            }
            std.mem.copyForwards(u8, &field_name, d.name);
            field_name[d.name.len] = 0;
            const symbol = so.moduleSymbol(m, @ptrCast(&field_name)) orelse
                return so.ModuleError.UndefinedSymbol;
            @field(dyn_api, d.name) = @ptrCast(symbol);
        }
    } else {
        return so.ModuleError.NotFound;
    }
}
