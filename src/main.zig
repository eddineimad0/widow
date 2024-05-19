const common = @import("common");
const cntxt = @import("context.zig");
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

pub const Event = common.event.Event;
pub const EventType = common.event.EventType;
pub const VideoMode = common.video_mode.VideoMode;
pub const WidowContext = cntxt.WidowContext;
pub const WindowBuilder = cntxt.WindowBuilder;
pub const initWidowPlatform = platform.initPlatform;
pub const deinitWidowPlatform = platform.deinitPlatform;
