const std = @import("std");
const common = @import("common");
const display = @import("display.zig");
const driver = @import("driver.zig");
const wndw = @import("window.zig");
const win32_gfx = @import("win32api/graphics.zig");
const win32_macros = @import("win32api/macros.zig");
const win32 = std.os.windows;

const mem = std.mem;
const dbg = std.debug;
const io = std.io;

pub const Window = wndw.Window;
pub const WindowError = wndw.WindowError;

// Platform handles
pub const DisplayHandle = win32_gfx.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

pub const WidowContext = struct {
    helper_window: win32.HWND,
    allocator: mem.Allocator,
    driver: *const driver.Win32Driver,
    display_mgr: display.DisplayManager,

    const Self = @This();
    fn init(a: mem.Allocator) (mem.Allocator.Error ||
        display.DisplayError ||
        driver.Win32DriverError ||
        wndw.WindowError)!Self {
        const d = try driver.Win32Driver.initSingleton();
        errdefer driver.Win32Driver.deinitSingleton();
        const h = blk: { // create hidden window for system messages
            const helper_window = win32_gfx.CreateWindowExW(
                @bitCast(@as(u32, 0)),
                win32_macros.MAKEINTATOM(d.handles.helper_class),
                &[0:0]u16{},
                @bitCast(@as(u32, 0)),
                win32_gfx.CW_USEDEFAULT,
                win32_gfx.CW_USEDEFAULT,
                win32_gfx.CW_USEDEFAULT,
                win32_gfx.CW_USEDEFAULT,
                null,
                null,
                d.handles.hinstance,
                null,
            ) orelse {
                return WindowError.CreateFailed;
            };
            _ = win32_gfx.ShowWindow(helper_window, win32_gfx.SW_HIDE);
            break :blk helper_window;
        };

        errdefer _ = win32_gfx.DestroyWindow(h);
        const display_mgr = try display.DisplayManager.init(a);
        return .{
            .driver = d,
            .helper_window = h,
            .display_mgr = display_mgr,
            .allocator = a,
        };
    }
};

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error ||
    display.DisplayError ||
    driver.Win32DriverError ||
    wndw.WindowError)!*WidowContext {
    const ctx = try a.create(WidowContext);
    errdefer a.destroy(ctx);
    ctx.* = try WidowContext.init(a);
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
    driver.Win32Driver.deinitSingleton();
    a.destroy(ctx);
}

pub inline fn getPrimaryDisplay(ctx: *const WidowContext) ?DisplayHandle {
    for (ctx.display_mgr.displays.items) |*d| {
        if (d.is_primary) {
            return d.handle;
        }
    }
    return null;
}

pub inline fn getDisplayFromWindow(ctx: *WidowContext, w: *Window) ?DisplayHandle {
    const d = ctx.display_mgr.findWindowDisplay(w) catch return null;
    return d.handle;
}

pub fn getDisplayInfo(ctx: *WidowContext, h: DisplayHandle, info: *common.video_mode.DisplayInfo) bool {
    for (ctx.display_mgr.displays.items) |*d| {
        if (d.handle == h) {
            d.getCurrentVideoMode(&info.video_mode);
            info.name_len = d.name.len;
            dbg.assert(info.name_len <= info.name.len);
            @memcpy(info.name[0..info.name_len], d.name);
            return true;
        }
    }
    return false;
}

test "platform_unit_test" {
    @import("std").testing.refAllDecls(display);
    @import("std").testing.refAllDecls(driver);
    @import("std").testing.refAllDecls(@import("dynlib.zig"));
}
