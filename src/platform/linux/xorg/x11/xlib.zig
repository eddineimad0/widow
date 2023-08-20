///! Functions
const types = @import("types.zig");
pub usingnamespace types;
pub usingnamespace @import("macros.zig");

pub extern "X11" fn XOpenDisplay(display_name: ?[*:0]u8) ?*types.Display;
pub extern "X11" fn XCloseDisplay(display: ?*types.Display) c_int;

// // Multithreading routines.
// pub extern fn XInitThreads() Status;
// pub extern fn XFreeThreads() Status;
// pub extern fn XLockDisplay(display: *Display) void;
// pub extern fn XUnlockDisplay(display: *Display) void;
//
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
