const std = @import("std");
const types = @import("types.zig");
const unix = @import("common").unix;
const mem = std.mem;
const WAYLAND_CLIENT_SO_NAME = "libwayland-client.so.0";

pub const ifaces = struct {
    pub var wl_surface_interface : *types.wl_interface=undefined;
    pub var wl_display_interface : *types.wl_interface = undefined;
    pub var wl_registry_interface: *types.wl_interface =undefined; 
    pub var wl_callback_interface : *types.wl_interface = undefined;
    pub var wl_compositor_interface : *types.wl_interface = undefined;
    pub var wl_shm_pool_interface : *types.wl_interface = undefined;
    pub var  wl_shm_interface : *types.wl_interface = undefined;
    pub var wl_buffer_interface : *types.wl_interface = undefined;
    pub var  wl_data_offer_interface : *types.wl_interface = undefined;
    pub var wl_data_source_interface : *types.wl_interface = undefined;
    pub var  wl_data_device_interface : *types.wl_interface = undefined;
    pub var wl_data_device_manager_interface : *types.wl_interface = undefined;
    pub var wl_shell_interface : *types.wl_interface=undefined;
    pub var wl_shell_surface_interface : *types.wl_interface=undefined;
    pub var wl_seat_interface : *types.wl_interface = undefined;
    pub var wl_pointer_interface : *types.wl_interface = undefined;
    pub var wl_keyboard_interface : *types.wl_interface = undefined;
    pub var wl_touch_interface : *types.wl_interface=undefined;
    pub var wl_output_interface : *types.wl_interface = undefined;
    pub var  wl_region_interface : *types.wl_interface = undefined;
    pub var wl_subcompositor_interface : *types.wl_interface = undefined;
    pub var  wl_subsurface_interface : *types.wl_interface = undefined;
};


var __libxwayland_client_module: ?*anyopaque = null;

pub fn loadIfaces() unix.ModuleError!void {
    // Easy shortcut but require the field.name to be 0 terminated
    // since it will be passed to a c function.
    const MAX_NAME_LENGTH = 256;
    const info = @typeInfo(ifaces);
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
            @field(ifaces, d.name) = @ptrCast(@alignCast(symbol));
        }
    } else {
        return unix.ModuleError.NotFound;
    }
}
