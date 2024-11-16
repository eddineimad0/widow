const types = @import("types.zig");

const iface_table = [_]?*types.wl_interface {
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	null,
	// &wl_callback_interface,
	// &wl_registry_interface,
	// &wl_surface_interface,
	// &wl_region_interface,
	// &wl_buffer_interface,
	// null,
	// null,
	// null,
	// null,
	// null,
	// &wl_shm_pool_interface,
	// null,
	// null,
	// &wl_data_source_interface,
	// &wl_surface_interface,
	// &wl_surface_interface,
	// null,
	// &wl_data_source_interface,
	// null,
	// &wl_data_offer_interface,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// &wl_data_offer_interface,
	// &wl_data_offer_interface,
	// &wl_data_source_interface,
	// &wl_data_device_interface,
	// &wl_seat_interface,
	// &wl_shell_surface_interface,
	// &wl_surface_interface,
	// &wl_seat_interface,
	// null,
	// &wl_seat_interface,
	// null,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// null,
	// null,
	// null,
	// &wl_output_interface,
	// &wl_seat_interface,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// null,
	// &wl_output_interface,
	// &wl_buffer_interface,
	// null,
	// null,
	// &wl_callback_interface,
	// &wl_region_interface,
	// &wl_region_interface,
	// &wl_output_interface,
	// &wl_output_interface,
	// &wl_pointer_interface,
	// &wl_keyboard_interface,
	// &wl_touch_interface,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// null,
	// &wl_surface_interface,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// &wl_surface_interface,
	// null,
	// null,
	// null,
	// &wl_subsurface_interface,
	// &wl_surface_interface,
	// &wl_surface_interface,
	// &wl_surface_interface,
	// &wl_surface_interface,
};

// const iface_table = [1]?*const types.wl_interface {null} ** 95;

// const wl_surface_requests = [_]types.wl_message {
//     .{ .name = "destroy", .signature = "", .types = &iface_table[0]},
//     .{ .name = "attach", .signature = "?oii", .types = &iface_table[58] },
//     .{ .name = "damage", .signature = "iiii", .types = &iface_table[0]},
//     .{ .name = "frame", .signature = "n", .types = &iface_table[61] },
//     .{ .name = "set_opaque_region", .signature = "?o", .types = &iface_table[62] },
//     .{ .name = "set_input_region", .signature = "?o", .types = &iface_table[63] },
//     .{ .name = "commit", .signature = "", .types = &iface_table[0] },
//     .{ .name = "set_buffer_transform", .signature = "2i", .types = &iface_table[0] },
//     .{ .name = "set_buffer_scale", .signature = "3i", .types = &iface_table[0] },
//     .{ .name = "damage_buffer", .signature = "4iiii", .types =  &iface_table[0] },
// };
//
// const wl_surface_events = [_]types.wl_message {
//     .{ .name = "enter", .signature = "o", .types = &iface_table[64] },
//     .{ .name = "leave", .signature = "o", .types = &iface_table[65] },
// };
//
// pub const wl_surface_interface = types.wl_interface{
//     .name = "wl_surface",
//     .version =  4,
//     .request_count = wl_surface_requests.len,
//     .requests = &wl_surface_requests,
//     .event_count = wl_surface_events.len,
//     .events = &wl_surface_events,
// };
//
// const wl_display_requests = [_]types.wl_message {
//     .{ .name = "sync", .signature = "n", .types = &iface_table[8] },
//     .{ .name = "get_registry", .signature = "n", .types = &iface_table[9]},
// };
//
// const wl_display_events = [_]types.wl_message{
//     .{ .name = "error", .signature = "ous", .types = &iface_table[0] },
//     .{ .name = "delete_id", .signature = "u", .types = &iface_table[0] },
// };
//
// pub const wl_display_interface = types.wl_interface{
//     .name = "wl_display",
//     .version =  1,
//     .request_count = wl_display_requests.len,
//     .requests = &wl_display_requests,
//     .event_count = wl_display_events.len,
//     .events = &wl_display_events,
// };

const wl_registry_requests = [_]types.wl_message{
    .{.name = "bind", .signature = "usun",.types=&iface_table[0]},
};

const wl_registry_events = [_]types.wl_message{
    .{ .name="global", .signature="usu", .types=&iface_table[0]},
    .{ .name="global_remove", .signature="u", .types=&iface_table[0]},
};

pub const wl_registry_interface: types.wl_interface = .{
    .name = "wl_registry",
    .version = 1,
    .request_count = wl_registry_requests.len,
    .requests = &wl_registry_requests,
    .event_count = wl_registry_events.len,
    .events = &wl_registry_events,
};

// const wl_callback_events = [_]types.wl_message  {
//     .{ .name = "done", .signature = "u", .types = &iface_table[0] },
// };
//
// pub const wl_callback_interface = types.wl_interface{
//     .name = "wl_callback",
//     .version = 1,
//     .request_count = 0,
//     .requests = null,
//     .event_count = wl_callback_events.len,
//     .events = &wl_callback_events,
// };
//
// const wl_compositor_requests = [_]types.wl_message {
//     .{ .name = "create_surface", .signature = "n", .types = &iface_table[10] },
//     .{ .name = "create_region", .signature = "n", .types = &iface_table[11] },
// };
//
// pub const wl_compositor_interface = types.wl_interface{
//     .name = "wl_compositor",
//     .version = 4,
//     .request_count = wl_compositor_requests.len,
//     .requests = &wl_compositor_requests,
//     .event_count =  0,
//     .events =  null,
// };
//
// const wl_shm_pool_requests = [_]types.wl_message {
//     .{ .name = "create_buffer", .signature ="niiiiu", .types = &iface_table[12]},
//     .{ .name = "destroy", .signature = "", .types = &iface_table[0] },
//     .{ .name = "resize", .signature = "i", .types = &iface_table[0] },
// };
// pub const wl_shm_pool_interface = types.wl_interface{
//     .name = "wl_shm_pool",
//     .version = 1,
//     .request_count = wl_shm_pool_requests.len,
//     .requests = &wl_shm_pool_requests,
//     .event_count = 0,
//     .events = null,
// };
// const wl_shm_requests = [_]types.wl_message{
//     .{ .name = "create_pool", .signature = "nhi", .types = &iface_table[18] },
// };
// const wl_shm_events = [_]types.wl_message{
//     .{ .name = "format", .signature = "u", .types = &iface_table[0] },
// };
// pub const  wl_shm_interface = types.wl_interface{
//     .name = "wl_shm",
//     .version = 1,
//     .request_count = wl_shm_requests.len,
//     .requests = &wl_shm_requests,
//     .event_count = wl_shm_events.len,
//     .events = &wl_shm_events,
// };
// const wl_buffer_requests = [_]types.wl_message {
//     .{ .name =  "destroy", .signature = "", .types = &iface_table[0] },
// };
// const wl_buffer_events = [_]types.wl_message {
//     .{ .name = "release", .signature = "", .types = &iface_table[0] },
// };
// pub const wl_buffer_interface = types.wl_interface{
//     .name = "wl_buffer",
//     .version = 1,
//     .request_count = wl_buffer_requests.len,
//     .requests = &wl_buffer_requests,
//     .event_count = wl_buffer_events.len,
//     .events = &wl_buffer_events,
// };
//
// const wl_data_offer_requests = [_]types.wl_message{
//     .{ .name = "accept", .signature = "u?s", .types = &iface_table[0] },
//     .{ .name = "receive", .signature = "sh", .types = &iface_table[0] },
//     .{ .name = "destroy", .signature = "", .types = &iface_table[0] },
//     .{ .name = "finish", .signature = "3", .types = &iface_table[0] },
//     .{ .name = "set_actions", .signature = "3uu", .types = &iface_table[0] },
// };
// const wl_data_offer_events = [_]types.wl_message{
//     .{ .name =  "offer", .signature =  "s", .types = &iface_table[0] },
//     .{ .name =  "source_actions", .signature = "3u", .types = &iface_table[0] },
//     .{ .name =  "action", .signature = "3u", .types = &iface_table[0] },
// };
// pub const  wl_data_offer_interface = types.wl_interface{
//     .name = "wl_data_offer",
//     .version = 3,
//     .request_count = wl_data_offer_requests.len ,
//     .requests = &wl_data_offer_requests,
//     .event_count = wl_data_offer_events.len,
//     .events = &wl_data_offer_events,
// };
//
// const wl_data_source_requests = [_]types.wl_message {
//     .{ .name = "offer", .signature = "s", .types = &iface_table[0] },
//     .{ .name = "destroy", .signature = "", .types = &iface_table[0] },
//     .{ .name = "set_actions", .signature = "3u", .types = &iface_table[0] },
// };
//
// const wl_data_source_events = [_]types.wl_message{
//     .{ .name = "target", .signature = "?s", .types = &iface_table[0] },
//     .{ .name = "send", .signature = "sh", .types = &iface_table[0] },
//     .{ .name = "cancelled", .signature = "", .types = &iface_table[0] },
//     .{ .name = "dnd_drop_performed", .signature = "3", .types = &iface_table[0] },
//     .{ .name = "dnd_finished", .signature = "3", .types = &iface_table[0] },
//     .{ .name = "action", .signature = "3u", .types = &iface_table[0] },
// };
//
// pub const wl_data_source_interface = types.wl_interface{
//     .name = "wl_data_source",
//     .version = 3,
//     .request_count = wl_data_source_requests.len,
//     .requests = &wl_data_source_requests,
//     .event_count = wl_data_source_events.len,
//     .events = &wl_data_source_events,
// };
//
// const  wl_data_device_requests = [_]types.wl_message{
//     .{ .name = "start_drag", .signature = "?oo?ou", .types = &iface_table[21] },
//     .{ .name = "set_selection", .signature = "?ou", .types = &iface_table[25] },
//     .{ .name = "release", .signature = "2", .types = &iface_table[0] },
// };
// const  wl_data_device_events = [_]types.wl_message{
//     .{ .name = "data_offer", .signature = "n", .types = &iface_table[27] },
//     .{ .name = "enter", .signature = "uoff?o", .types = &iface_table[28] },
//     .{ .name = "leave", .signature = "", .types = &iface_table[0] },
//     .{ .name = "motion", .signature = "uff", .types = &iface_table[0] },
//     .{ .name = "drop", .signature = "", .types = &iface_table[0] },
//     .{ .name = "selection", .signature = "?o", .types = &iface_table[33] },
// };
// pub const  wl_data_device_interface = types.wl_interface{
//     .name = "wl_data_device",
//     .version = 3,
//     .request_count = wl_data_device_requests.len,
//     .requests = &wl_data_device_requests,
//     .event_count = wl_data_device_events.len,
//     .events = &wl_data_device_events,
// };
// const wl_data_device_manager_requests = []types.wl_message{
//     .{ .name = "create_data_source", .signature = "n", .types = &iface_table[34] },
//     .{ .name = "get_data_device", .signature = "no", .types = &iface_table[35] },
// };
// pub const wl_data_device_manager_interface = types.wl_interface{
//     .name = "wl_data_device_manager",
//     .version = 3,
//     .request_count =  wl_data_device_manager_requests.len,
//     .requests =  &wl_data_device_manager_requests,
//     .event_count = 0,
//     .events = null,
// };
// const wl_shell_requests = []types.wl_message{
//     .{ .name = "get_shell_surface", .signature = "no", .types = &iface_table[37] },
// };
// pub const wl_shell_interface = types.wl_interface{
//     .name = "wl_shell",
//     .version = 1,
//     .request_count = wl_shell_requests.len,
//     .requests = &wl_shell_requests,
//     .event_count = 0,
//     .events = null,
// };
// const wl_shell_surface_requests = [_]types.wl_message{
//     .{ .name = "pong", .signature = "u", .types = &iface_table[0] },
//     .{ .name = "move", .signature = "ou", .types = &iface_table[39] },
//     .{ .name = "resize", .signature="ouu", .types = &iface_table[41] },
//     .{ .name = "set_toplevel", .signature ="", .types = &iface_table[0] },
//     .{ .name = "set_transient", .signature = "oiiu", .types = &iface_table[44] },
//     .{ .name = "set_fullscreen", .signature = "uu?o", .types = &iface_table[48] },
//     .{ .name = "set_popup", .signature = "ouoiiu", .types = &iface_table[51] },
//     .{ .name = "set_maximized", .signature = "?o", .types = &iface_table[57] },
//     .{ .name = "set_title", .signature = "s", .types = &iface_table[0] },
//     .{ .name = "set_class", .signature = "s", .types = &iface_table[0] },
// };
// const wl_shell_surface_events = [_]types.wl_message {
//     .{ .name =  "ping", .signature = "u", .types = &iface_table[0] },
//     .{ .name =  "configure", .signature = "uii", .types = &iface_table[0] },
//     .{ .name =  "popup_done", .signature = "", .types = &iface_table[0] },
// };
// pub const wl_shell_surface_interface = types.wl_interface{
//     .name = "wl_shell_surface",
//     .version = 1,
//     .request_count = wl_shell_surface_requests.len,
//     .requests =  &wl_shell_surface_requests,
//     .event_count = wl_shell_surface_events.len,
//     .events = &wl_shell_surface_events,
// };
// const wl_seat_requests = [_]types.wl_message {
//     .{ .name = "get_pointer", .signature = "n", .types = &iface_table[66] },
//     .{ .name = "get_keyboard", .signature = "n", .types = &iface_table[67] },
//     .{ .name = "get_touch", .signature = "n", .types = &iface_table[68] },
//     .{ .name = "release", .signature = "5", .types = &iface_table[0] },
// };
// const wl_seat_events = [_]types.wl_message {
//     .{ .name =  "capabilities", .signature =  "u", .types = &iface_table[0] },
//     .{ .name =  "name", .signature = "2s", .types = &iface_table[0] },
// };
// pub const wl_seat_interface = types.wl_interface{
//     .name = "wl_seat",
//     .version = 7,
//     .request_count = wl_seat_requests.len,
//     .request = &wl_seat_requests,
//     .event_count = wl_seat_events.len,
//     .events = &wl_seat_events,
// };
// const wl_pointer_requests = [_]types.wl_message {
//     .{ .name = "set_cursor", .signature = "u?oii", .types = &iface_table[69] },
//     .{ .name = "release", .signature = "3", .types = &iface_table[0] },
// };
// const wl_pointer_events = [_]types.wl_message{
//     .{ .name = "enter", .signature = "uoff", .types = &iface_table[73] },
//     .{ .name = "leave", .signature = "uo", .types = &iface_table[77] },
//     .{ .name = "motion", .signature = "uff", .types = &iface_table[0] },
//     .{ .name = "button", .signature = "uuuu", .types = &iface_table[0] },
//     .{ .name = "axis", .signature = "uuf", .types = &iface_table[0] },
//     .{ .name = "frame", .signature = "5", .types = &iface_table[0] },
//     .{ .name = "axis_source", .signature = "5u", .types = &iface_table[0] },
//     .{ .name = "axis_stop", .signature = "5uu", .types = &iface_table[0] },
//     .{ .name = "axis_discrete", .signature = "5ui", .types = &iface_table[0] },
// };
// pub const wl_pointer_interface = types.wl_interface{
//     .name = "wl_pointer",
//     .version = 7,
//     .request_count = wl_pointer_requests.len,
//     .requests =  &wl_pointer_requests,
//     .event_count = wl_pointer_events.len,
//     .events = &wl_pointer_events,
// };
// const  wl_keyboard_requests = [_]types.wl_message {
//     .{.name = "release", .version = "3", .types = &iface_table[0] },
// };
// const wl_keyboard_events = []types.wl_message {
//     .{ .name = "keymap", .signature = "uhu", .types = &iface_table[0] },
//     .{ .name = "enter", .signature = "uoa", .types = &iface_table[79] },
//     .{ .name = "leave", .signature = "uo", .types = &iface_table[82] },
//     .{ .name = "key", .signature ="uuuu", .types = &iface_table[0] },
//     .{ .name = "modifiers", .signature ="uuuuu", .types = &iface_table[0] },
//     .{ .name = "repeat_info", .signature ="4ii", .types = &iface_table[0] },
// };
// pub const wl_keyboard_interface = types.wl_interface{
//     .name = "wl_keyboard",
//     .version = 7,
//     .request_count = wl_keyboard_requests.len,
//     .requests = &wl_keyboard_requests,
//     .event_count = wl_keyboard_events.len,
//     .events = &wl_keyboard_events,
// };
// const wl_touch_requests = [_]types.wl_message {
//     .{ .name =  "release", .signature = "3", .types = &iface_table[0] },
// };
// const wl_touch_events = [_]types.wl_message {
//     .{ .name = "down", .signature = "uuoiff", .types =&iface_table[84] },
//     .{ .name = "up", .signature = "uui", .types =&iface_table[0] },
//     .{ .name = "motion", .signature = "uiff", .types =&iface_table[0] },
//     .{ .name = "frame", .signature = "", .types =&iface_table[0] },
//     .{ .name = "cancel", .signature = "", .types =&iface_table[0] },
//     .{ .name = "shape", .signature = "6iff", .types =&iface_table[0] },
//     .{ .name = "orientation", .signature = "6if", .types =&iface_table[0] },
// };
// pub const wl_touch_interface = types.wl_interface{
//     .name = "wl_touch",
//     .version = 7,
//     .request_count = wl_touch_requests.len,
//     .requests = &wl_touch_requests,
//     .event_count = wl_touch_events.len,
//     .events = &wl_touch_events,
// };
// const wl_output_requests = [_]types.wl_message{
//     .{.name =  "release", .signature = "3", .types = &iface_table[0] },
// };
// const wl_output_events = [_] types.wl_message {
//     .{ .name = "geometry", .signature = "iiiiissi", .types = &iface_table[0] },
//     .{ .name = "mode", .signature = "uiii", .types = &iface_table[0] },
//     .{ .name = "done", .signature = "2", .types = &iface_table[0] },
//     .{ .name = "scale", .signature = "2i", .types = &iface_table[0] },
// };
// pub const wl_output_interface = types.wl_interface{
//     .name = "wl_output",
//     .version = 3,
//     .request_count = wl_output_requests.len,
//     .requests = &wl_output_requests,
//     .event_count = wl_output_events.len,
//     .events =  &wl_output_events,
// };
// const wl_region_requests = []types.wl_message{
//     .{ .name =  "destroy", .signature = "", .types = &iface_table[0] },
//     .{ .name =  "add", .signature = "iiii", .types = &iface_table[0] },
//     .{ .name =  "subtract", .signature = "iiii", .types = &iface_table[0] },
// };
// pub const  wl_region_interface = types.wl_interface{
//     .name = "wl_region",
//     .version = 1,
//     .request_count = wl_region_requests.len,
//     .requests = &wl_region_requests,
//     .event_count = 0,
//     .events = null,
// };
// const wl_subcompositor_requests = []types.wl_message{
//     .{ .name = "destroy", .signature = "", .types = &iface_table[0] },
//     .{ .name = "get_subsurface", .signature = "noo", .types = &iface_table[90] },
// };
// pub const wl_subcompositor_interface = types.wl_interface{
//     .name = "wl_subcompositor",
//     .version = 1,
//     .request_count = wl_subcompositor_requests.len,
//     .requests = &wl_subcompositor_requests,
//     .event_count = 0,
//     .events = null,
// };
// const wl_subsurface_requests = []types.wl_message{
//     .{ .name =  "destroy", .signature = "", .types = &iface_table[0] },
//     .{ .name =  "set_position",.signature = "ii", .types = &iface_table[0] },
//     .{ .name =  "place_above", .signature = "o", .types = &iface_table[93] },
//     .{ .name =  "place_below", .signature = "o", .types = &iface_table[94] },
//     .{ .name =  "set_sync", .signature = "", .types = &iface_table[0] },
//     .{ .name =  "set_desync", .signature = "", .types = &iface_table[0] },
// };
// pub const  wl_subsurface_interface = types.wl_interface{
//     .name = "wl_subsurface",
//     .version = 1,
//     .request_count = wl_surface_requests.len,
//     .requests = &wl_subsurface_requests,
//     .event_count = 0,
//     .events = null,
// };
