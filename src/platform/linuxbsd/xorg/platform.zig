const std = @import("std");
const display = @import("display.zig");
const libx11 = @import("x11/xlib.zig");
const x11ext = @import("x11/extensions/extensions.zig");
const common = @import("common");
const driver = @import("driver.zig");

const so = common.unix.so;
const dbg = std.debug;
const mem = std.mem;

pub const WindowHandle = libx11.Window;
pub const DisplayHandle = x11ext.xrandr.RRCrtc;

const KeyMaps = @import("keymaps.zig").KeyMaps;
pub const Window = @import("window.zig").Window;
pub const Canvas = @import("window.zig").X11Canvas;
pub const WindowError = @import("window.zig").WindowError;

pub const GLContext = @import("glx.zig").GLContext;
pub const BlitContext = @import("window.zig").BlitContext;
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

pub fn createWidowContext(a: mem.Allocator) (mem.Allocator.Error ||
    so.ModuleError ||
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

pub inline fn getPrimaryDisplay(ctx: *const WidowContext) ?DisplayHandle {
    for (ctx.display_mgr.displays.items) |*d| {
        if (d.is_primary) {
            return d.adapter;
        }
    }
    return null;
}

pub inline fn getDisplayFromWindow(ctx: *WidowContext, w: *Window) ?DisplayHandle {
    const d = ctx.display_mgr.findWindowDisplay(w) catch return null;
    return d.adapter;
}

pub fn getDisplayInfo(ctx: *WidowContext, h: DisplayHandle, info: *common.video_mode.DisplayInfo) bool {
    for (ctx.display_mgr.displays.items) |*d| {
        if (d.adapter == h) {
            d.queryCurrentMode(ctx.driver, &info.video_mode);
            info.name_len = d.name.len;
            dbg.assert(info.name_len <= info.name.len);
            const end = @min(info.name_len, info.name.len);
            @memcpy(info.name[0..end], d.name);
            return true;
        }
    }
    return false;
}

test "Platform" {
    @import("std").testing.refAllDecls(@import("utils.zig"));
}
