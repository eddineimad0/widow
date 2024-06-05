const common = @import("common");
const window = @import("window.zig");
const gl = @import("gl");
const platform = @import("platform");

// Exports
pub const geometry = common.geometry;
pub const cursor = common.cursor;

pub const keyboard = struct {
    pub const KeyCode = common.keyboard_mouse.KeyCode;
    pub const ScanCode = common.keyboard_mouse.ScanCode;
    pub const KeyState = common.keyboard_mouse.KeyState;
    pub const KeyModifiers = common.keyboard_mouse.KeyModifiers;
};

pub const mouse = struct {
    pub const MouseButton = common.keyboard_mouse.MouseButton;
    pub const MouseWheel = common.keyboard_mouse.MouseWheel;
    pub const MouseButtonState = common.keyboard_mouse.MouseButtonState;
};

pub const event = struct {
    pub const Event = common.event.Event;
    pub const EventType = common.event.EventType;
    pub const EventQueue = common.event.EventQueue;
};

pub const opengl = struct {
    pub const loaderFunc = platform.glLoaderFunc;
    pub const GLconfig = gl.GLConfig;
};

pub const VideoMode = common.video_mode.VideoMode;
pub const WindowBuilder = window.WindowBuilder;
pub const initWidowPlatform = platform.initPlatform;
pub const deinitWidowPlatform = platform.deinitPlatform;
