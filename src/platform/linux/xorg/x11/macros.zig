const types = @import("types.zig");
pub inline fn ScreenOfDisplay(dpy: *types.Display, scr: u32) *types.Screen {
    const priv_dpy: *types._XPrivDisplay = @ptrCast(@alignCast(dpy));
    return &priv_dpy.screens.?[scr];
}
pub inline fn RootWindow(dpy: *types.Display, scr: u32) types.Window {
    return ScreenOfDisplay(dpy, scr).root;
}

pub inline fn DefaultScreen(dpy: *types.Display) i32 {
    const priv_dpy: *types._XPrivDisplay = @ptrCast(@alignCast(dpy));
    return priv_dpy.default_screen;
}
