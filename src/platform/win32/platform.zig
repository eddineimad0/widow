pub const internals = @import("./internals.zig");
pub const window_impl = @import("./window_impl.zig");
pub const joystick = @import("./joystick_impl.zig");
// defs
const win32 = @import("win32_defs.zig");
// Platform handles
pub const PMonitorHandle = win32.HMONITOR;
pub const PWindowHandle = win32.HWND;
