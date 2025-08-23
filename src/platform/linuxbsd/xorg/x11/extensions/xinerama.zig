const libx11 = @import("../xlib.zig");

// Types
pub const XineramaScreenInfo = extern struct {
    screen_number: c_int,
    x_org: c_short,
    y_org: c_short,
    width: c_short,
    height: c_short,
};

// Functions Signature.
pub const XineramaIsActiveProc = *const fn (dpy: *libx11.Display) callconv(.c) libx11.Bool;
pub const XineramaQueryExtension = *const fn (
    dpy: *libx11.Display,
    event_base_return: *c_int,
    error_base_return: *c_int,
) callconv(.c) libx11.Bool;
pub const XineramaQueryVersion = *const fn (
    dpy: *libx11.Display,
    version_major: *c_int,
    version_minor: *c_int,
) callconv(.c) libx11.Status;
pub const XineramaQueryScreens = *const fn (
    dpy: *libx11.Display,
    number: *c_int,
) callconv(.c) ?[*]XineramaScreenInfo;
