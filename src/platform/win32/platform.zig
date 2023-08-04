pub const internals = @import("internals.zig");
pub const window_impl = @import("window_impl.zig");
pub const joystick = @import("joystick_impl.zig");
const win32 = @import("win32_defs.zig");
// Platform handles
pub const MonitorHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

const WidowContext = @import("global.zig").Win32Context;

pub fn initPlatform(options: anytype) !void {
    const window_class = if (@hasField(@TypeOf(options), "wnd_class"))
        @field(options, "wnd_class")
    else
        "WIDOW_CLASS";

    const res_icon = if (@hasField(@TypeOf(options), "res_icon"))
        @field(options, "res_icon")
    else
        null;

    try WidowContext.initSingleton(window_class, res_icon);
}

pub fn deinitPlatform() void {
    WidowContext.deinitSingleton();
}
