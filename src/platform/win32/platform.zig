const win32 = @import("win32_defs.zig");
const display = @import("display.zig");
const time = @import("time.zig");

pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub const DisplayManager = display.DisplayManager;

// Platform handles
pub const DisplayHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const GLContext = @import("wgl.zig").GLContext;
pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

const PlatformDriver = @import("driver.zig").Win32Driver;

pub fn initPlatform() !void {
    try PlatformDriver.initSingleton();
}

pub fn deinitPlatform() void {
    PlatformDriver.deinitSingleton();
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("display.zig"));
    @import("std").testing.refAllDecls(@import("module.zig"));
}
