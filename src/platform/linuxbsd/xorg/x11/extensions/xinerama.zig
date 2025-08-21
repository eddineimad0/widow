const types = @import("../types.zig");

// Types
pub const XineramaScreenInfo = extern struct {
    screen_number: c_int,
    x_org: c_short,
    y_org: c_short,
    width: c_short,
    height: c_short,
};

// Functions Signature.
pub const XineramaIsActiveProc = *const fn (dpy: *types.Display) callconv(.c) types.Bool;
pub const XineramaQueryExtension = *const fn (
    dpy: *types.Display,
    event_base_return: *c_int,
    error_base_return: *c_int,
) callconv(.c) types.Bool;
pub const XineramaQueryVersion = *const fn (
    dpy: *types.Display,
    version_major: *c_int,
    version_minor: *c_int,
) callconv(.c) types.Status;
pub const XineramaQueryScreens = *const fn (
    dpy: *types.Display,
    number: *c_int,
) callconv(.c) ?[*]XineramaScreenInfo;
