const types = @import("types.zig");
pub usingnamespace types;
pub usingnamespace @import("macros.zig");
pub usingnamespace @import("defs.zig");

pub extern "X11" fn XOpenDisplay(display_name: ?[*:0]u8) ?*types.Display;
pub extern "X11" fn XCloseDisplay(display: ?*types.Display) c_int;
pub extern "X11" fn XInitExtension(display: ?*types.Display, ext_name: ?[*:0]const u8) ?[*]types.XExtCodes;
pub extern "X11" fn XAddExtension(display: ?*types.Display) ?[*]types.XExtCodes;

// Multithreading routines.
pub extern "X11" fn XInitThreads() c_int;
pub extern "X11" fn XLockDisplay(display: ?*types.Display) void;
pub extern "X11" fn XUnlockDisplay(display: ?*types.Display) void;

// Ressource Manager
pub extern "X11" fn XrmInitialize() void;
pub extern "X11" fn XResourceManagerString(display: ?*types.Display) ?[*:0]const u8;
pub extern "X11" fn XrmGetStringDatabase(data: ?[*:0]const u8) types.XrmDatabase;
pub extern "X11" fn XrmDestroyDatabase(db: types.XrmDatabase) void;
pub extern "X11" fn XrmGetResource(
    db: types.XrmDatabase,
    str_name: [*:0]const u8,
    str_class: [*:0]const u8,
    str_type_return: *?[*:0]const u8,
    value_return: *types.XrmValue,
) types.Bool;

pub extern "X11" fn XrmUniqueQuark() types.XrmQuark;

// Window Management
pub extern "X11" fn XCreateSimpleWindow(
    display: ?*types.Display,
    parent: types.Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border_width: c_uint,
    border: c_ulong,
    background: c_ulong,
) types.Window;

pub extern "X11" fn XCreateWindow(
    display: ?*types.Display,
    parent: types.Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border_width: c_uint,
    depth: c_int,
    class: c_uint,
    visual: ?[*]types.Visual,
    value_mask: c_ulong,
    attributes: ?[*]types.XSetWindowAttributes,
) types.Window;

pub extern "X11" fn XDestroyWindow(display: ?*types.Display, window: types.Window) c_int;
pub extern "X11" fn XMapWindow(display: ?*types.Display, window: types.Window) c_int;
pub extern "X11" fn XUnmapWindow(display: ?*types.Display, window: types.Window) c_int;
pub extern "X11" fn XMoveWindow(
    display: ?*types.Display,
    window: types.Window,
    x: c_int,
    y: c_int,
) c_int;

pub extern "X11" fn XResizeWindow(
    display: ?*types.Display,
    window: types.Window,
    width: c_uint,
    height: c_uint,
) c_int;

pub extern "X11" fn XIconifyWindow(
    display: ?*types.Display,
    window: types.Window,
    screen_number: c_int,
) types.Status;

// Properties
pub extern "X11" fn XChangeProperty(
    display: ?*types.Display,
    w: types.Window,
    property: types.Atom,
    prop_type: types.Atom,
    format: c_int,
    mode: c_int,
    data: [*]const u8,
    nelements: c_int,
) void;

pub extern "X11" fn XDeleteProperty(
    display: ?*types.Display,
    w: types.Window,
    property: types.Atom,
) void;

// Events
pub extern "X11" fn XNextEvent(display: *types.Display, x_event: *types.XEvent) c_int;
pub extern "X11" fn XPending(display: *types.Display) c_int;
pub extern "X11" fn XQLength(display: *types.Display) c_int;
pub extern "X11" fn XSendEvent(
    display: *types.Display,
    w: types.Window,
    propagate: types.Bool,
    event_mask: c_long,
    event: *types.XEvent,
) types.Status;

// Output buffer handler
pub extern "X11" fn XSync(display: *types.Display, discard: types.Bool) void;
pub extern "X11" fn XFlush(Display: *types.Display) c_int;

// Errors
pub const XErrorHandlerFunc = fn (display: ?*types.Display, err: *types.XErrorEvent) callconv(.C) c_int;
const XIOErrorHandlerFunc = fn (display: ?*types.Display) callconv(.C) c_int;
pub extern "X11" fn XSetErrorHandler(handler: ?*const XErrorHandlerFunc) ?*XErrorHandlerFunc;

// XUtil
pub const XUniqueContext = XrmUniqueQuark;

pub extern "X11" fn XSaveContext(
    display: ?*types.Display,
    rid: types.XID,
    context: types.XContext,
    data: types.XPointer,
) c_int;

pub extern "X11" fn XFindContext(
    display: ?*types.Display,
    rid: types.XID,
    context: types.XContext,
    data_return: *types.XPointer,
) c_int;

pub extern "X11" fn XDeleteContext(
    display: ?*types.Display,
    rid: types.XID,
    context: types.XContext,
) c_int;

// Misc
pub extern "X11" fn XGetWindowProperty(
    display: ?*types.Display,
    w: types.Window,
    property: types.Atom,
    long_offset: c_long,
    long_lenght: c_long,
    delete: types.Bool,
    req_type: types.Atom,
    actual_type_return: *types.Atom,
    actual_format_return: *c_int,
    nitems_return: *c_ulong,
    bytes_after_return: *c_ulong,
    prop_return: ?[*]?[*]u8,
) c_int;

pub extern "X11" fn XInternAtom(
    display: ?*types.Display,
    atom_name: [*:0]const u8,
    if_exist: types.Bool,
) types.Atom;

pub extern "X11" fn XFree(data: *anyopaque) c_int;
