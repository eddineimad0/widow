const std = @import("std");
const win32 = @import("win32_defs.zig");
const display = @import("display.zig");
const time = @import("time.zig");
const driver = @import("driver.zig");

const mem = std.mem;

pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

// Platform handles
pub const DisplayHandle = win32.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const GLContext = @import("wgl.zig").GLContext;
pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

pub const WidowContext = struct {
    fn init(a: mem.Allocator) (mem.Allocator.Error || display.DisplayError || driver.Win32DriverError)!Self {
        return .{
            .driver = try driver.Win32Driver.initSingleton(),
            .display_mgr = try display.DisplayManager.init(a),
        };
    }

    driver: *const driver.Win32Driver,
    display_mgr: display.DisplayManager,
    const Self = @This();
};

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error ||
    display.DisplayError ||
    driver.Win32DriverError)!*WidowContext {
    const ctx = try a.create(WidowContext);
    ctx.* = try WidowContext.init(a);
    return ctx;
}

pub fn destroyWidowContext(a: mem.Allocator, ctx: *WidowContext) void {
    ctx.display_mgr.deinit();
    a.destroy(ctx);
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("display.zig"));
    @import("std").testing.refAllDecls(@import("module.zig"));
}
