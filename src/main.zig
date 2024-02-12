const common = @import("common");
const cntxt = @import("context.zig");
const platform = @import("platform");
// Exports
pub const geometry = common.geometry;
pub const cursor = common.cursor;
pub const keyboard_and_mouse = common.keyboard_and_mouse;
pub const Event = common.event.Event;
pub const EventType = common.event.EventType;
pub const VideoMode = common.video_mode.VideoMode;
pub const DrawingBackend = common.gfx.DrawingBackend;
pub const WidowContext = cntxt.WidowContext;
pub const WindowBuilder = cntxt.WindowBuilder;
pub const initWidowPlatform = platform.initPlatform;
pub const deinitWidowPlatform = platform.deinitPlatform;
