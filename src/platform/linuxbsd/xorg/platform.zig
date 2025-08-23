const std = @import("std");
const display = @import("display.zig");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const so = @import("common").unix.so;
const driver = @import("driver.zig");

const mem = std.mem;

pub const WindowHandle = libx11.Window;
pub const DisplayHandle = x11ext.RRCrtc;

const KeyMaps = @import("keymaps.zig").KeyMaps;
pub const Window = @import("window.zig").Window;
pub const WindowError = @import("window.zig").WindowError;

pub const GLContext = @import("glx.zig").GLContext;
pub const glLoaderFunc = @import("glx.zig").glLoaderFunc;

pub const WidowContext = struct {
    driver: *const driver.X11Driver,
    key_map: *const KeyMaps,
    allocator: mem.Allocator,
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
            .allocator = a,
            .display_mgr = display_mgr,
            .raw_mouse_motion_window = null,
        };
    }
};

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error || so.ModuleError ||
    display.DisplayError ||
    driver.XConnectionError)!*WidowContext {
    libx11.initDynamicApi() catch |e| {
        std.log.err("[X11] {s}\n", .{so.moduleErrorMsg()});
        return e;
    };
    const ctx = try a.create(WidowContext);
    ctx.* = try WidowContext.init(a);
    return ctx;
}

pub fn destroyWidowContext(a: mem.Allocator, ctx: *WidowContext) void {
    ctx.display_mgr.deinit(ctx.allocator);
    a.destroy(ctx);
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("utils.zig"));
}
