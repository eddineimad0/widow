const std = @import("std");
const types = @import("types.zig");
const funcs = @import("funcs.zig");
const cst = @import("constants.zig");
const iface = @import("interfaces.zig");

const NULL = @as(c_int,0);

pub fn wl_display_get_registry(display:*types.wl_display) ?*types.wl_registry {
    var r:?*types.wl_proxy = undefined;
    r = funcs.libwayland_client_api.wl_proxy_marshal_constructor(
        @ptrCast(display),
        cst.WL_DISPLAY_GET_REGISTRY,
        &iface.wl_registry_interface, NULL);
    return @ptrCast(r);
} 

pub fn wl_registry_add_listener(
    registry: *types.wl_registry,
    listener: *const types.wl_registry_listener,
    data: ?*anyopaque,
) c_int{
    return funcs.libwayland_client_api.wl_proxy_add_listener(@ptrCast(registry), @ptrCast(listener), data);
}

pub inline fn wl_registry_bind(
    registry: *types.wl_registry,
    name:u32,
    interface: *const types.wl_interface,
    version:u32
    ) ?*anyopaque {
    const WL_REGISTRY_BIND = 0;
    var id:?*types.wl_proxy = undefined;
    id = funcs.libwayland_client_api.wl_proxy_marshal_flags(
        @ptrCast(registry),
        WL_REGISTRY_BIND,
        interface,
        version,
        0,
        name,
        interface.name,
        version,
        NULL);
    return @ptrCast(id);
}
