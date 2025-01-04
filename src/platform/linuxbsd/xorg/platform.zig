const std = @import("std");
const display = @import("display.zig");
const libx11 = @import("x11/xlib.zig");
const dyn_x11 = @import("x11/dynamic.zig");
const unix = @import("common").unix;
const driver = @import("driver.zig");

const time = unix.time;
const mem = std.mem;

const KeyMaps = @import("keymaps.zig").KeyMaps;
pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub const GLContext = @import("glx.zig").GLContext;
pub const glLoaderFunc = @import("glx.zig").glLoaderFunc;

pub const WidowContext = struct {
    driver: *const driver.X11Driver,
    key_map: *const KeyMaps,
    display_mgr: display.DisplayManager,
    raw_mouse_motion_window: ?libx11.Window,

    const Self = @This();
    fn init(a: mem.Allocator) (mem.Allocator.Error || display.DisplayError ||
        driver.XConnectionError)!Self {
        const d = try driver.X11Driver.initSingleton();
        const km = KeyMaps.initSingleton(d);
        const display_mgr = try display.DisplayManager.init(a, d);
        return .{
            .driver = d,
            .key_map = km,
            .display_mgr = display_mgr,
            .raw_mouse_motion_window = null,
        };
    }
};

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error || unix.ModuleError ||
    display.DisplayError ||
    driver.XConnectionError)!*WidowContext {
    dyn_x11.initDynamicApi() catch |e| {
        std.log.err("[X11] {s}\n", .{unix.moduleErrorMsg()});
        return e;
    };
    const ctx = try a.create(WidowContext);
    ctx.* = try WidowContext.init(a);
    return ctx;
}

pub fn destroyWidowContext(a: mem.Allocator, ctx: *WidowContext) void {
    ctx.display_mgr.deinit();
    a.destroy(ctx);
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("utils.zig"));
}
