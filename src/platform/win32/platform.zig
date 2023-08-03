pub const internals = @import("internals.zig");
pub const window_impl = @import("window_impl.zig");
pub const joystick = @import("joystick_impl.zig");
const win32 = @import("win32_defs.zig");
// Platform handles
pub const MonitorHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

const WidowContext = @import("global.zig").Win32Context;

pub fn initPlatform(options: anytype) !void {
    if (@hasField(@TypeOf(options), "wnd_class")) {
        try WidowContext.initSingleton(@field(options, "wnd_class"));
    } else {
        try WidowContext.initSingleton("WIDOW_CLASS");
    }
}

pub fn deinitPlatform() void {
    WidowContext.deinitSingleton();
}
