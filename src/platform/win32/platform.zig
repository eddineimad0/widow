pub const internals = @import("./internals.zig");
pub const window_impl = @import("./window_impl.zig");
pub const joystick = @import("./joystick_impl.zig");
const win32 = @import("win32_defs.zig");
// Platform handles
pub const MonitorHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;
