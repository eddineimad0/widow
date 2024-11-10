const std = @import("std");
const mem = std.mem;
const types = @import("./types.zig");
const unix = @import("common").unix;

const WAYLAND_CLIENT_SO_NAME = "libwayland-client.so.0";

pub const libwayland_client_api = struct {
    // display creation and destruction
    pub var wl_display_connect_to_fd: *const fn (fd: c_int) callconv(.C) ?*types.wl_display = undefined;
    pub var wl_display_connect: *const fn (name: ?[*:0]const u8) callconv(.C) ?*types.wl_display = undefined;
    pub var wl_display_disconnect: *const fn (display: *types.wl_display) callconv(.C) void = undefined;
    pub var wl_display_get_fd: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    // display events handling
    pub var wl_display_roundtrip: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    pub var wl_display_read_events: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    pub var wl_display_prepare_read: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    pub var wl_display_cancel_read: *const fn (display: *types.wl_display) callconv(.C) void = undefined;
    pub var wl_display_dispatch_pending: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    // registry
    pub var wl_registry_add_listener: *const fn (
        registry: *types.wl_registry,
        listener: *const types.wl_registry_listener,
        data: ?*anyopaque,
    ) callconv(.C) c_int = undefined;
    // error handling
    pub var wl_display_get_error: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    pub var wl_display_flush: *const fn (display: *types.wl_display) callconv(.C) c_int = undefined;
    // proxys
    pub var wl_proxy_destroy: *const fn (proxy: *types.wl_proxy) callconv(.C) void = undefined;
    pub var wl_proxy_add_listener: *const fn (
        proxy: *types.wl_proxy,
        implementation: *const fn () callconv(.C) void,
        data: *anyopaque,
    ) callconv(.C) c_int = undefined;
    pub var wl_proxy_set_user_data: *const fn (proxy: *types.wl_proxy, data: *anyopaque) callconv(.C) void = undefined;
    pub var wl_proxy_get_user_data: *const fn (proxy: *types.wl_proxy) callconv(.C) ?*anyopaque = undefined;
    pub var wl_proxy_get_version: *const fn (proxy: *types.wl_proxy) callconv(.C) u32 = undefined;
    pub var wl_proxy_get_tag: *const fn (proxy: *types.wl_proxy) callconv(.C) *const [*:0]const u8 = undefined;
    pub var wl_proxy_set_tag: *const fn (proxy: *types.wl_proxy, tag: *const [*:0]const u8) callconv(.C) void = undefined;
    // varargs:
    pub var wl_proxy_marshal_constructor: *const fn (
        proxy: *types.wl_proxy,
        opcode: u32,
        interface: *const types.wl_interface,
        vargs:?*anyopaque,
    ) callconv(.C) *types.wl_proxy = undefined;
    pub var wl_proxy_marshal_constructor_versioned: *const fn (
        proxy: *types.wl_proxy,
        opcode: u32,
        interface: *const types.wl_interface,
        version: u32,
        vargs:?*anyopaque,
    ) callconv(.C) *types.wl_proxy = undefined;
    pub var wl_proxy_marshal: *const fn (proxy: *types.wl_proxy, opcode: u32,vargs:?*anyopaque) callconv(.C) void = undefined;
    pub var wl_proxy_marshal_flags: *const fn (
        proxy: *types.wl_proxy,
        opcode: u32,
        interface: *const types.wl_interface,
        version: u32,
        flags: u32,
        vargs:?*anyopaque,
    ) callconv(.C) *types.wl_proxy = undefined;
    // log
    pub var wl_log_set_handler_client: *const fn (handler: types.wl_log_func_t) callconv(.C) void = undefined;

    // compositor
    pub var wl_display_get_compositor:*const fn(display:*types.wl_display) callconv(.C) *types.wl_compositor = undefined;
    pub var wl_compositor_create_surface: *const fn(compositor:*types.wl_compositor) callconv(.C) *types.wl_surface = undefined;
    pub var wl_compositor_commit:*const fn(compositor:*types.wl_compositor, key:u32) callconv(.C) void = undefined;
    // surface
    pub var wl_surface_destroy: *const fn (surface: *types.wl_surface) callconv(.C) void = undefined;
    pub var wl_surface_attach: *const fn(surface: *types.wl_surface, name:u32, width:i32, height:i32,
    stride:u32, visual:*types.wl_visual,) callconv(.C) void = undefined;
    pub var wl_surface_map:*const fn(surface: *types.wl_surface,
                x:i32, y:i32, width:i32, height:i32) callconv(.C) void = undefined;
    pub var wl_surface_copy:*const fn(surface: *types.wl_surface, dst_x:i32, dst_y:i32,
                    name:u32, stride:u32,
                    x:i32, y:i32, width:i32, height:i32) callconv(.C) void = undefined;
    pub var wl_surface_damage:*const fn (surface: *types.wl_surface,
                    x:i32, y:i32, width:i32, height:i32) callconv(.C) void = undefined;
	
};

var __libxwayland_client_module: ?*anyopaque = null;

pub fn initDynamicApi() unix.ModuleError!void {
    // Easy shortcut but require the field.name to be 0 terminated
    // since it will be passed to a c function.
    const MAX_NAME_LENGTH = 256;
    const info = @typeInfo(libwayland_client_api);
    var field_name: [MAX_NAME_LENGTH]u8 = undefined;

    if (__libxwayland_client_module != null) {
        return;
    }

    __libxwayland_client_module = unix.loadPosixModule(WAYLAND_CLIENT_SO_NAME);

    if (__libxwayland_client_module) |m| {
        inline for (info.Struct.decls) |*d| {
            if (comptime d.name.len > MAX_NAME_LENGTH - 1) {
                @compileError(
                    "LibWayland function name is greater than the maximum buffer length",
                );
            }

            mem.copyForwards(u8, &field_name, d.name);
            field_name[d.name.len] = 0;
            const symbol = unix.moduleSymbol(m, @ptrCast(&field_name)) orelse
                return unix.ModuleError.UndefinedSymbol;
            @field(libwayland_client_api, d.name) = @ptrCast(symbol);
        }
    } else {
        return unix.ModuleError.NotFound;
    }
}
