const std = @import("std");
const display = @import("display.zig");
const time = @import("time.zig");
const driver = @import("driver.zig");
const wndw = @import("window.zig");
const win32_gfx = @import("win32api/graphics.zig");
const win32 = std.os.windows;

const mem = std.mem;

pub const Window = wndw.Window;
pub const WindowError = wndw.WindowError;

// Platform handles
pub const DisplayHandle = win32_gfx.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const GLContext = @import("wgl.zig").GLContext;
pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

pub const WidowContext = struct {
    helper_window: win32.HWND,
    driver: *const driver.Win32Driver,
    display_mgr: display.DisplayManager,

    const Self = @This();
    fn init(a: mem.Allocator) (mem.Allocator.Error ||
        display.DisplayError ||
        driver.Win32DriverError ||
        wndw.WindowError)!Self {
        const d = try driver.Win32Driver.initSingleton();
        const h = try wndw.createHiddenWindow(&[0:0]u16{}, d);
        const display_mgr = try display.DisplayManager.init(a);
        return .{
            .driver = d,
            .helper_window = h,
            .display_mgr = display_mgr,
        };
    }
};

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error ||
    display.DisplayError ||
    driver.Win32DriverError ||
    wndw.WindowError)!*WidowContext {
    const ctx = try a.create(WidowContext);
    ctx.* = try WidowContext.init(a);
    // register helper properties
    _ = win32_gfx.SetPropW(
        ctx.helper_window,
        display.HELPER_DISPLAY_PROP,
        @ptrCast(&ctx.display_mgr),
    );
    return ctx;
}

pub fn destroyWidowContext(a: mem.Allocator, ctx: *WidowContext) void {
    // unregister helper properties
    _ = win32_gfx.SetPropW(
        ctx.helper_window,
        display.HELPER_DISPLAY_PROP,
        null,
    );
    _ = win32_gfx.DestroyWindow(ctx.helper_window);
    ctx.display_mgr.deinit();
    a.destroy(ctx);
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("display.zig"));
    @import("std").testing.refAllDecls(@import("dynlib.zig"));
}
