const std = @import("std");
const common = @import("common");
const gl = @import("opengl");
const platform = @import("platform");

// Exports
pub const geometry = common.geometry;
pub const cursor = common.cursor;

pub const input = struct {
    pub const keyboard = struct {
        pub const KeyCode = common.keyboard_mouse.KeyCode;
        pub const ScanCode = common.keyboard_mouse.ScanCode;
        pub const KeyState = common.keyboard_mouse.KeyState;
        pub const KeyModifiers = common.keyboard_mouse.KeyModifiers;
    };
    pub const mouse = struct {
        pub const MouseButton = common.keyboard_mouse.MouseButton;
        pub const MouseButtonState = common.keyboard_mouse.MouseButtonState;
    };
};

pub const event = struct {
    pub const Event = common.event.Event;
    pub const EventType = common.event.EventType;
    pub const EventQueue = common.event.EventQueue;
};

pub const opengl = struct {
    /// platform specific function for fetching
    /// opengl functions after creating an opengl
    /// rendering context.
    pub const loaderFunc = platform.glLoaderFunc;
    pub const GLContext = platform.GLContext;
};

pub const WindowBuilder = @import("window.zig").WindowBuilder;
pub const Window = @import("window.zig").Window;
pub const WindowHandle = platform.WindowHandle;
pub const DisplayHandle = platform.DisplayHandle;

/// initialize a platform context.
/// this should be the first function you call before
/// using the library.
pub const createWidowContext = platform.createWidowContext;

/// destroys and frees the resources used by the platform context.
/// calling this function invalidates the context, therfore it should
/// only be called after destroying all the other widow objects, otherwise it will cause
/// undefined behaviour, alternatively you could not call it and let the os clean up
/// the resources.
pub const destroyWidowContext = platform.destroyWidowContext;

test "all_widow_unit_tests" {
    std.testing.refAllDeclsRecursive(common);
    std.testing.refAllDeclsRecursive(platform);
    std.testing.refAllDeclsRecursive(gl);
}
