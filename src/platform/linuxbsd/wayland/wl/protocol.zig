const types = @import("types.zig");
const funcs = @import("funcs.zig");
const cst = @import("constants.zig");

pub fn wl_display_get_registry(display:*types.wl_display) *types.wl_registry {

    var r:*types.wl_registry = undefined;
    r = funcs.libwayland_client_api.wl_proxy_marshal_constructor(@ptrCast(display),
        cst.WL_DISPLAY_GET_REGISTRY,
        &cst.wl_registry_interface, null);
    return @ptrCast(r);
} 
