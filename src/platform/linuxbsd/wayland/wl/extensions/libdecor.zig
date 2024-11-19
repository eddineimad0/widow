const wl_types = @import("../types.zig");
pub const libdecor_api = struct {

    // Create a new libdecor context for the given wl_display.
    pub var libdecor_new:*const fn(display:*wl_types.wl_display,iface:*const libdecor_interface) callconv(.C) ?* libdecor = undefined;
    // Remove a reference to the libdecor instance. When the reference count
    // reaches zero, it is freed.
    pub var libdecor_unref:*const fn(context:*libdecor) callconv(.C) void = undefined;
};
//     _glfw.wl.libdecor.handle = _glfwPlatformLoadModule("libdecor-0.so.0");
//
//         _glfw.wl.libdecor.libdecor_get_fd_ = (PFN_libdecor_get_fd)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_get_fd");
//         _glfw.wl.libdecor.libdecor_dispatch_ = (PFN_libdecor_dispatch)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_dispatch");
//         _glfw.wl.libdecor.libdecor_decorate_ = (PFN_libdecor_decorate)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_decorate");
//         _glfw.wl.libdecor.libdecor_frame_unref_ = (PFN_libdecor_frame_unref)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_unref");
//         _glfw.wl.libdecor.libdecor_frame_set_app_id_ = (PFN_libdecor_frame_set_app_id)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_app_id");
//         _glfw.wl.libdecor.libdecor_frame_set_title_ = (PFN_libdecor_frame_set_title)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_title");
//         _glfw.wl.libdecor.libdecor_frame_set_minimized_ = (PFN_libdecor_frame_set_minimized)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_minimized");
//         _glfw.wl.libdecor.libdecor_frame_set_fullscreen_ = (PFN_libdecor_frame_set_fullscreen)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_fullscreen");
//         _glfw.wl.libdecor.libdecor_frame_unset_fullscreen_ = (PFN_libdecor_frame_unset_fullscreen)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_unset_fullscreen");
//         _glfw.wl.libdecor.libdecor_frame_map_ = (PFN_libdecor_frame_map)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_map");
//         _glfw.wl.libdecor.libdecor_frame_commit_ = (PFN_libdecor_frame_commit)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_commit");
//         _glfw.wl.libdecor.libdecor_frame_set_min_content_size_ = (PFN_libdecor_frame_set_min_content_size)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_min_content_size");
//         _glfw.wl.libdecor.libdecor_frame_set_max_content_size_ = (PFN_libdecor_frame_set_max_content_size)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_max_content_size");
//         _glfw.wl.libdecor.libdecor_frame_set_maximized_ = (PFN_libdecor_frame_set_maximized)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_maximized");
//         _glfw.wl.libdecor.libdecor_frame_unset_maximized_ = (PFN_libdecor_frame_unset_maximized)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_unset_maximized");
//         _glfw.wl.libdecor.libdecor_frame_set_capabilities_ = (PFN_libdecor_frame_set_capabilities)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_capabilities");
//         _glfw.wl.libdecor.libdecor_frame_unset_capabilities_ = (PFN_libdecor_frame_unset_capabilities)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_unset_capabilities");
//         _glfw.wl.libdecor.libdecor_frame_set_visibility_ = (PFN_libdecor_frame_set_visibility)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_set_visibility");
//         _glfw.wl.libdecor.libdecor_frame_get_xdg_toplevel_ = (PFN_libdecor_frame_get_xdg_toplevel)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_frame_get_xdg_toplevel");
//         _glfw.wl.libdecor.libdecor_configuration_get_content_size_ = (PFN_libdecor_configuration_get_content_size)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_configuration_get_content_size");
//         _glfw.wl.libdecor.libdecor_configuration_get_window_state_ = (PFN_libdecor_configuration_get_window_state)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_configuration_get_window_state");
//         _glfw.wl.libdecor.libdecor_state_new_ = (PFN_libdecor_state_new)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_state_new");
//         _glfw.wl.libdecor.libdecor_state_free_ = (PFN_libdecor_state_free)
//             _glfwPlatformGetModuleSymbol(_glfw.wl.libdecor.handle, "libdecor_state_free");

pub const xdg_toplevel = opaque{};
pub const libdecor = opaque{};
pub const libdecor_frame = opaque{};
pub const libdecor_configuration = opaque{};
pub const libdecor_state = opaque{};

pub const libdecor_error = enum (c_int) {
	LIBDECOR_ERROR_COMPOSITOR_INCOMPATIBLE,
	LIBDECOR_ERROR_INVALID_FRAME_CONFIGURATION,
};

pub const libdecor_window_state = enum (c_int) {
    LIBDECOR_WINDOW_STATE_NONE = 0,
    LIBDECOR_WINDOW_STATE_ACTIVE = 1 << 0,
    LIBDECOR_WINDOW_STATE_MAXIMIZED = 1 << 1,
    LIBDECOR_WINDOW_STATE_FULLSCREEN = 1 << 2,
    LIBDECOR_WINDOW_STATE_TILED_LEFT = 1 << 3,
    LIBDECOR_WINDOW_STATE_TILED_RIGHT = 1 << 4,
    LIBDECOR_WINDOW_STATE_TILED_TOP = 1 << 5,
    LIBDECOR_WINDOW_STATE_TILED_BOTTOM = 1 << 6,
    LIBDECOR_WINDOW_STATE_SUSPENDED = 1 << 7,
    LIBDECOR_WINDOW_STATE_RESIZING = 1 << 8,
};

pub const libdecor_resize_edge = enum (c_int) {
    LIBDECOR_RESIZE_EDGE_NONE,
    LIBDECOR_RESIZE_EDGE_TOP,
    LIBDECOR_RESIZE_EDGE_BOTTOM,
    LIBDECOR_RESIZE_EDGE_LEFT,
    LIBDECOR_RESIZE_EDGE_TOP_LEFT,
    LIBDECOR_RESIZE_EDGE_BOTTOM_LEFT,
    LIBDECOR_RESIZE_EDGE_RIGHT,
    LIBDECOR_RESIZE_EDGE_TOP_RIGHT,
    LIBDECOR_RESIZE_EDGE_BOTTOM_RIGHT,
};

pub const libdecor_capabilities = enum (c_int) {
    LIBDECOR_ACTION_MOVE = 1 << 0,
    LIBDECOR_ACTION_RESIZE = 1 << 1,
    LIBDECOR_ACTION_MINIMIZE = 1 << 2,
    LIBDECOR_ACTION_FULLSCREEN = 1 << 3,
    LIBDECOR_ACTION_CLOSE = 1 << 4,
};

pub const libdecor_wm_capabilities = enum (c_int) {
    LIBDECOR_WM_CAPABILITIES_WINDOW_MENU = 1 << 0,
    LIBDECOR_WM_CAPABILITIES_MAXIMIZE = 1 << 1,
    LIBDECOR_WM_CAPABILITIES_FULLSCREEN = 1 << 2,
    LIBDECOR_WM_CAPABILITIES_MINIMIZE = 1 << 3
};

pub const libdecor_interface = extern struct {
    error_func:*const fn(context:?*libdecor,err:libdecor_error,message:[*:0]const u8) callconv(.C) void,
    // reserved
    reserved0:*const fn() callconv(.C) void,
    reserved1:*const fn() callconv(.C) void,
    reserved2:*const fn() callconv(.C) void,
    reserved3:*const fn() callconv(.C) void,
    reserved4:*const fn() callconv(.C) void,
    reserved5:*const fn() callconv(.C) void,
    reserved6:*const fn() callconv(.C) void,
    reserved7:*const fn() callconv(.C) void,
    reserved8:*const fn() callconv(.C) void,
    reserved9:*const fn() callconv(.C) void,
};

pub const libdecor_frame_interface = extern struct {
    configure:*const fn(frame:?*libdecor_frame,configuration:?*libdecor_configuration, user_data:?*anyopaque) callconv(.C) void,
    close:*const fn(frame:?*libdecor_frame, user_data:?*anyopaque) callconv(.C) void,
    commit:*const fn(frame:?*libdecor_frame, user_data:?*anyopaque) callconv(.C) void,
    dismiss_popup:*const fn(frame:?*libdecor_frame, seat_name:[*:0]const u8, user_data:?*anyopaque) callconv(.C) void,

    // reserved
    reserved0:*const fn() callconv(.C) void,
    reserved1:*const fn() callconv(.C) void,
    reserved2:*const fn() callconv(.C) void,
    reserved3:*const fn() callconv(.C) void,
    reserved4:*const fn() callconv(.C) void,
    reserved5:*const fn() callconv(.C) void,
    reserved6:*const fn() callconv(.C) void,
    reserved7:*const fn() callconv(.C) void,
    reserved8:*const fn() callconv(.C) void,
    reserved9:*const fn() callconv(.C) void,
};

// /**
//  * Create a new libdecor context for the given wl_display and attach user data.
//  */
// struct libdecor *
// libdecor_new_with_user_data(struct wl_display *display,
// 	     const struct libdecor_interface *iface,
// 	     void *user_data);
//
// /**
//  * Get the user data associated with this libdecor context.
//  */
// void *
// libdecor_get_user_data(struct libdecor *context);
//
// /**
//  * Set the user data associated with this libdecor context.
//  */
// void
// libdecor_set_user_data(struct libdecor *context, void *user_data);
//
// /**
//  * Get the file descriptor used by libdecor. This is similar to
//  * wl_display_get_fd(), thus should be polled, and when data is available,
//  * libdecor_dispatch() should be called.
//  */
// int
// libdecor_get_fd(struct libdecor *context);
//
// /**
//  * Dispatch events. This function should be called when data is available on
//  * the file descriptor returned by libdecor_get_fd(). If timeout is zero, this
//  * function will never block.
//  */
// int
// libdecor_dispatch(struct libdecor *context,
// 		  int timeout);
//
// /**
//  * Decorate the given content wl_surface.
//  *
//  * This will create an xdg_surface and an xdg_toplevel, and integrate it
//  * properly with the windowing system, including creating appropriate
//  * decorations when needed, as well as handle windowing integration events such
//  * as resizing, moving, maximizing, etc.
//  *
//  * The passed wl_surface should only contain actual application content,
//  * without any window decoration.
//  */
// struct libdecor_frame *
// libdecor_decorate(struct libdecor *context,
// 		  struct wl_surface *surface,
// 		  const struct libdecor_frame_interface *iface,
// 		  void *user_data);
//
// /**
//  * Add a reference to the frame object.
//  */
// void
// libdecor_frame_ref(struct libdecor_frame *frame);
//
// /**
//  * Remove a reference to the frame object. When the reference count reaches
//  * zero, the frame object is destroyed.
//  */
// void
// libdecor_frame_unref(struct libdecor_frame *frame);
//
// /**
//  * Get the user data associated with this libdecor frame.
//  */
// void *
// libdecor_frame_get_user_data(struct libdecor_frame *frame);
//
// /**
//  * Set the user data associated with this libdecor frame.
//  */
// void
// libdecor_frame_set_user_data(struct libdecor_frame *frame, void *user_data);
//
// /**
//  * Set the visibility of the frame.
//  *
//  * If an application wants to be borderless, it can set the frame visibility to
//  * false.
//  */
// void
// libdecor_frame_set_visibility(struct libdecor_frame *frame,
// 			      bool visible);
//
// /**
//  * Get the visibility of the frame.
//  */
// bool
// libdecor_frame_is_visible(struct libdecor_frame *frame);
//
//
// /**
//  * Set the parent of the window.
//  *
//  * This can be used to stack multiple toplevel windows above or under each
//  * other.
//  */
//
