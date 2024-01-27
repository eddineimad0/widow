const types = @import("types.zig");
const DynApi = @import("dynamic.zig").DynApi;
const assert = @import("std").debug.assert;

pub inline fn ScreenOfDisplay(dpy: *types.Display, scr: c_int) *types.Screen {
    const priv_dpy: *types._XPrivDisplay = @ptrCast(@alignCast(dpy));
    assert(scr >= 0);
    return &priv_dpy.screens.?[@intCast(scr)];
}
pub inline fn RootWindow(dpy: *types.Display, scr: c_int) types.Window {
    return ScreenOfDisplay(dpy, scr).root;
}

pub inline fn DefaultScreen(dpy: *types.Display) c_int {
    const priv_dpy: *types._XPrivDisplay = @ptrCast(@alignCast(dpy));
    return priv_dpy.default_screen;
}

pub inline fn ConnectionNumber(dpy: *types.Display) c_int {
    const priv_dpy: *types._XPrivDisplay = @ptrCast(@alignCast(dpy));
    return priv_dpy.fd;
}

pub inline fn DefaultVisual(dpy: *types.Display, scr: c_int) ?[*]types.Visual {
    return ScreenOfDisplay(dpy, scr).root_visual;
}

pub inline fn DefaultDepth(dpy: *types.Display, scr: c_int) c_int {
    return ScreenOfDisplay(dpy, scr).root_depth;
}

pub inline fn DisplayWidth(dpy: *types.Display, scr: c_int) c_int {
    return ScreenOfDisplay(dpy, scr).width;
}

pub inline fn DisplayHeight(dpy: *types.Display, scr: c_int) c_int {
    return ScreenOfDisplay(dpy, scr).height;
}
pub inline fn XUniqueContext() c_int {
    return DynApi.XrmUniqueQuark();
}
