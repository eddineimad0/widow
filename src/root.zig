const std = @import("std");
const common = @import("common");
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
};

pub const time = struct {
    /// Get the ticks count per second of the platform high resolution counter.
    pub const getMonoClockFreq = platform.time.getMonotonicClockFrequency;

    /// Get the current value of the platform high resolution counter.
    /// diffrence between values can be converted to times by using
    /// getMonoClockFreq().
    pub const getMonoClockTicks = platform.time.getMonotonicClockTicks;

    /// blocks thread and wait *at least* for the specified number of nanoseconds.
    pub const waitForNs = platform.time.waitForNs;
};

pub const gfx = struct {
    pub const Canvas = @import("window.zig").Canvas;
    pub const RenderApi = common.fb.RenderApi;
    pub const FramebufferConfig = common.fb.FBConfig;
    pub const PixelFormat = common.pixel.PixelFormat;
    pub const PixelFormatInfo = common.pixel.PixelFormatInfo;
};

pub const WindowBuilder = @import("window.zig").WindowBuilder;
pub const Window = @import("window.zig").Window;
pub const WindowHandle = platform.WindowHandle;
pub const DisplayHandle = platform.DisplayHandle;
pub const WidowContext = platform.WidowContext;

/// initialize a platform context.
/// this should be the first function you call before
/// using the library.
/// # Side effects
/// on windows:
///  * we initialize COM
///  * we set Console code page to UTF8 (allows printing of utf8 strings correctly)
///  * we enable virtual console (enables extra features in the terminal)
pub const createWidowContext = platform.createWidowContext;

/// destroys and frees the resources used by the platform context.
/// calling this function invalidates the context, therfore it should
/// only be called after destroying all the other widow objects, otherwise it will cause
/// undefined behaviour, alternatively you could not call it and let the os clean up
/// the resources.
pub const destroyWidowContext = platform.destroyWidowContext;

// WARN: because Displays(monitors) can be unplugged at any
// moment by the user from the system. the identifiers returned
// by these functions may get invalidated at any moment, so use with caution
// TODO: add an event for when monitors gets unplugged
pub const getPrimaryDisplay = platform.getPrimaryDisplay;
pub const getDisplayFromWindow = platform.getDisplayFromWindow;
pub const getDisplayInfo = platform.getDisplayInfo;

/// returns a string identifier for the current os
/// we are running on.
pub const getOsName = platform.getOsName;

/// returns a struct containing informations about the current
/// execution environement.
/// notably:
/// * cpu identifier and extensions support
/// * hostname
/// * user *home* and *temp* paths
/// * process id, binary path, and current workind directory
/// for more see [common.sysinfo.CommonInfo]
pub const getCommonPlatformInfo = platform.getCommonPlatformInfo;

test "all_widow_unit_tests" {
    std.testing.refAllDeclsRecursive(common);
    std.testing.refAllDeclsRecursive(platform);
}
