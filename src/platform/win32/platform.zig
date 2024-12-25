const win32 = @import("win32_defs.zig");
const display = @import("display.zig");
const time = @import("time.zig");
const driver = @import("driver.zig");

pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub const DisplayManager = display.DisplayManager;

// Platform handles
pub const DisplayHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const GLContext = @import("wgl.zig").GLContext;
pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

pub const WidowContext = struct {
    pub fn init() driver.Win32DriverError!Self {
        return .{
            .driver = try driver.Win32Driver.initSingleton(),
        };
    }

    driver: *const driver.Win32Driver,
    const Self = @This();
};

test "Platform" {
    @import("std").testing.refAllDecls(@import("display.zig"));
    @import("std").testing.refAllDecls(@import("module.zig"));
}
