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

// Events
pub extern "X11" fn XNextEvent(arg0: *types.Display, arg1: *types.XEvent) c_int;

// Misc
pub extern "X11" fn XFree(data: *anyopaque) c_int;
