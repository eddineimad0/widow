const std = @import("std");
const monitor_impl = @import("display.zig");
const dyn_x11 = @import("x11/dynamic.zig");
const unix = @import("common").unix;
const driver = @import("driver.zig");

const mem = std.mem;

const KeyMaps = @import("keymaps.zig").KeyMaps;
pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub const GLContext = @import("glx.zig").GLContext;
pub const glLoaderFunc = @import("glx.zig").glLoaderFunc;

pub const WidowContext = struct {
    driver: *const driver.X11Driver,
    key_map: *const KeyMaps,
    //display_mgr: display.DisplayManager,

    const Self = @This();
    fn init(a: mem.Allocator) (mem.Allocator.Error || //display.DisplayError ||
        driver.XConnectionError)!Self {
        _ = a;
        const d = try driver.X11Driver.initSingleton();
        const km = KeyMaps.initSingleton(d);
        //const display_mgr = try display.DisplayManager.init(a);
        return .{
            .driver = d,
            .key_map = km,
            //.display_mgr = display_mgr,
        };
    }
};

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error || unix.ModuleError ||
    //display.DisplayError ||
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
    //ctx.display_mgr.deinit();
    a.destroy(ctx);
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("display.zig"));
}
