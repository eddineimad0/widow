const std = @import("std");
const posix = std.posix;

pub const wl_message = extern struct{
    name: [*:0]const u8,
    signature: [*:0]const u8,
    types: *const ?*const wl_interface,
};

pub const wl_interface = extern struct {
    name: [*:0]const u8,
    version: c_int,
    request_count: c_int,
    requests: ?[*]const wl_message,
    event_count: c_int,
    events: ?[*]const wl_message,
};

pub const wl_list = extern struct {
    prev: *wl_list,
    next: *wl_list,
};

pub const wl_array = extern struct {
    size: usize,
    alloc: usize,
    data: [*] anyopaque,
};

pub const wl_fixed_t = i32;

pub fn wl_fixed_to_double(f: wl_fixed_t) f64 {
    return @as(f64,@floatFromInt(f)) / 256.0;
}

pub fn wl_fixed_from_double(d: f64) wl_fixed_t {
    return @intFromFloat(d * 256.0);
}

pub fn wl_fixed_to_int(f: wl_fixed_t) i32 {
    return f / 256;
}

pub fn wl_fixed_from_int(i: i32) wl_fixed_t {
    return i * 256;
}

// must be the appropriate size
// can contain i32, u32 and pointers
pub const wl_argument = extern union {
    i: i32,
    u: u32,
    f: wl_fixed_t,
    s: *const u8,
    o: *const anyopaque,
    n: u32,
    a: *const wl_array,
    h: posix.fd_t,
};

pub const wl_dispatcher_func_t = *const fn(
    *const anyopaque,
    * anyopaque,
    u32,
    *const wl_message,
    *const wl_argument,
) callconv(.C) c_int;

pub const wl_registry_listener = extern struct {
    global:*const fn(data:*anyopaque,registry:*wl_registry,name:u32,interface:[*:0]const u8,ver:u32) callconv(.C) void,
    global_remove:*const fn(data:*anyopaque,registry:*wl_registry,name:u32) callconv(.C) void
};

pub const wl_log_func_t = *const fn([*:0]const u8, *const anyopaque) callconv(.C) void;

pub const wl_buffer = opaque{};
pub const wl_callback = opaque{};
pub const wl_compositor = opaque{};
pub const wl_data_device = opaque{};
pub const wl_data_device_manager = opaque{};
pub const wl_data_offer = opaque{};
pub const wl_data_source = opaque{};
pub const wl_display = opaque{};
pub const wl_event_queue = opaque{};
pub const wl_keyboard = opaque{};
pub const wl_output = opaque{};
pub const wl_pointer = opaque{};
pub const wl_proxy = opaque{};
pub const wl_region = opaque{};
pub const wl_registry = opaque{};
pub const wl_seat = opaque{};
pub const wl_shell = opaque{};
pub const wl_shell_surface = opaque{};
pub const wl_shm = opaque{};
pub const wl_shm_pool = opaque{};
pub const wl_subcompositor = opaque{};
pub const wl_subsurface = opaque{};
pub const wl_surface = opaque{};
pub const wl_touch = opaque{};
pub const wl_visual = opaque{};
