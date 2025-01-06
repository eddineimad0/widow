const std = @import("std");
const mem = std.mem;
const types = @import("./types.zig");
const unix = @import("common").unix;

const WAYLAND_CLIENT_SO_NAME = "libwayland-client.so.0";

pub const libwayland_client_api = struct {
    // display creation and destruction
    const wl_display_connect_to_fd:*const fn(c_int) [*] types.wl_display = undefined;
    const wl_display_connect:*const fn([*:0]const u8) [*] types.wl_display = undefined;
    const wl_display_disconnect:*const fn([*]types.wl_display) void = undefined;
    const wl_display_get_fd:*const fn([*]types.wl_display) c_int = undefined;

};
    // // display events handling
    //     fn wl_display_roundtrip(*mut wl_display) -> c_int,
    //     fn wl_display_read_events(*mut wl_display) -> c_int,
    //     fn wl_display_prepare_read(*mut wl_display) -> c_int,
    //     fn wl_display_cancel_read(*mut wl_display) -> (),
    //     fn wl_display_dispatch(*mut wl_display) -> c_int,
    //     fn wl_display_dispatch_pending(*mut wl_display) -> c_int,
    // // error handling
    //     fn wl_display_get_error(*mut wl_display) -> c_int,
    //     fn wl_display_get_protocol_error(*mut wl_display, *mut *const wl_interface, *mut u32) -> u32,
    // // requests handling
    //     fn wl_display_flush(*mut wl_display) -> c_int,
    //
    // // event queues
    //     fn wl_event_queue_destroy(*mut wl_event_queue) -> (),
    //     fn wl_display_create_queue(*mut wl_display) -> *mut wl_event_queue,
    //     fn wl_display_roundtrip_queue(*mut wl_display, *mut wl_event_queue) -> c_int,
    //     fn wl_display_prepare_read_queue(*mut wl_display, *mut wl_event_queue) -> c_int,
    //     fn wl_display_dispatch_queue(*mut wl_display, *mut wl_event_queue) -> c_int,
    //     fn wl_display_dispatch_queue_pending(*mut wl_display, *mut wl_event_queue) -> c_int,
    //
    // // proxys
    //     fn wl_proxy_create(*mut wl_proxy, *const wl_interface) -> *mut wl_proxy,
    //     fn wl_proxy_destroy(*mut wl_proxy) -> (),
    //     fn wl_proxy_add_listener(*mut wl_proxy, *mut extern fn(), *mut c_void) -> c_int,
    //     fn wl_proxy_get_listener(*mut wl_proxy) -> *const c_void,
    //     fn wl_proxy_add_dispatcher(*mut wl_proxy, wl_dispatcher_func_t, *const c_void, *mut c_void) -> c_int,
    //     fn wl_proxy_marshal_array_constructor(*mut wl_proxy, u32, *mut wl_argument, *const wl_interface) -> *mut wl_proxy,
    //     fn wl_proxy_marshal_array_constructor_versioned(*mut wl_proxy, u32, *mut wl_argument, *const wl_interface, u32) -> *mut wl_proxy,
    //     fn wl_proxy_marshal_array(*mut wl_proxy, u32, *mut wl_argument ) -> (),
    //     fn wl_proxy_set_user_data(*mut wl_proxy, *mut c_void) -> (),
    //     fn wl_proxy_get_user_data(*mut wl_proxy) -> *mut c_void,
    //     fn wl_proxy_get_id(*mut wl_proxy) -> u32,
    //     fn wl_proxy_get_class(*mut wl_proxy) -> *const c_char,
    //     fn wl_proxy_set_queue(*mut wl_proxy, *mut wl_event_queue) -> (),
    //     fn wl_proxy_get_version(*mut wl_proxy) -> u32,
    //     fn wl_proxy_create_wrapper(*mut wl_proxy) -> *mut wl_proxy,
    //     fn wl_proxy_wrapper_destroy(*mut wl_proxy) -> (),
    //
    // // log
    //     fn wl_log_set_handler_client(wl_log_func_t) -> (),
    //
    // // lists
    //     fn wl_list_init(*mut wl_list) -> (),
    //     fn wl_list_insert(*mut wl_list, *mut wl_list) -> (),
    //     fn wl_list_remove(*mut wl_list) -> (),
    //     fn wl_list_length(*const wl_list) -> c_int,
    //     fn wl_list_empty(*const wl_list) -> c_int,
    //     fn wl_list_insert_list(*mut wl_list,*mut wl_list) -> (),
    //
    // // arrays
    //     fn wl_array_init(*mut wl_array) -> (),
    //     fn wl_array_release(*mut wl_array) -> (),
    //     fn wl_array_add(*mut wl_array,usize) -> (),
    //     fn wl_array_copy(*mut wl_array, *mut wl_array) -> (),
    //
    // varargs:
    //     fn wl_proxy_marshal_constructor(*mut wl_proxy, u32, *const wl_interface) -> *mut wl_proxy,
    //     fn wl_proxy_marshal_constructor_versioned(*mut wl_proxy, u32, *const wl_interface, u32) -> *mut wl_proxy,
    //     fn wl_proxy_marshal(*mut wl_proxy, u32) -> (),


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
                    "Libx11 function name is greater than the maximum buffer length",
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
