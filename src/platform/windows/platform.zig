const std = @import("std");
const display = @import("display.zig");
const driver = @import("driver.zig");
const wndw = @import("window.zig");
const win32_gfx = @import("win32api/graphics.zig");
const win32 = std.os.windows;

const mem = std.mem;
const io = std.io;

pub const Window = wndw.Window;
pub const WindowError = wndw.WindowError;

// Platform handles
pub const DisplayHandle = win32_gfx.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const GLContext = @import("wgl.zig").GLContext;
pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

pub const WidowContext = struct {
    helper_window: win32.HWND,
    allocator: mem.Allocator,
    driver: *const driver.Win32Driver,
    display_mgr: display.DisplayManager,
    err_wr: ?*io.Writer,

    const Self = @This();
    fn init(
        a: mem.Allocator,
        err_wr: ?*io.Writer,
    ) (mem.Allocator.Error ||
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
            .allocator = a,
            .err_wr = err_wr,
        };
    }
};

pub fn createWidowContext(a: mem.Allocator, err_wr: ?*io.Writer) (mem.Allocator.Error ||
    display.DisplayError ||
    driver.Win32DriverError ||
    wndw.WindowError)!*WidowContext {
    const ctx = try a.create(WidowContext);
    ctx.* = try WidowContext.init(a, err_wr);
    // register helper properties
    _ = win32_gfx.SetPropW(
        ctx.helper_window,
        display.HELPER_DISPLAY_PROP,
        @ptrCast(ctx),
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
    ctx.display_mgr.deinit(ctx.allocator);
    a.destroy(ctx);
}

pub fn getPrimaryDisplay(ctx: *WidowContext) DisplayHandle {
    // TODO:
    _ = ctx;
}

pub fn getDisplayFromWindow(ctx: *WidowContext, w: *Window) DisplayHandle {
    // TODO:
    _ = ctx;
    _ = w;
}

const DisplayInfo = struct {
    name: []u8,
    video_mode: anyopaque,
};

pub fn getDisplayInfo(ctx: *WidowContext, d: DisplayHandle) DisplayInfo {
    // TODO:
    _ = ctx;
    _ = d;
}

test "platform_unit_test" {
    @import("std").testing.refAllDecls(display);
    @import("std").testing.refAllDecls(driver);
    @import("std").testing.refAllDecls(@import("dynlib.zig"));
}
