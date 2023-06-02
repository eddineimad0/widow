const VideoMode = @import("./video_mode.zig").VideoMode;
const WidowPoint2D = @import("./geometry.zig").WidowPoint2D;
const WidowSize = @import("./geometry.zig").WidowSize;
const InputState = @import("./input.zig").InputState;
pub const AspectRatio = @import("./geometry.zig").AspectRatio;

pub const WindowFlags = struct {
    is_visible: bool, // Does the window appear on screen or is it hidden from the user.
    is_maximized: bool, // Is the window maximized.
    is_minimized: bool, // Is the window minimized.
    is_resizable: bool, // Can the window be resized by draging the edges or maximzed.
    is_decorated: bool, // Does the window have a title bar.
    is_topmost: bool, // Should the window be always on top of all active windows.
    is_focused: bool, // Does the window have keyboard and input focus.
    cursor_in_client: bool, // Is the cursor currently in client area.
    allow_dpi_scaling: bool,
    accepts_raw_input: bool,
};

pub const FullScreenMode = enum(u8) {
    Borderless, // A fullScreen mode that simply resize the window.
    Exclusive, // A fullScreen mode with change in the display's video mode.
};

pub const CursorMode = enum(u8) {
    Normal, // Default cursor mode.
    Captured, // The cursor is restricted to the window area.
    Disabled, // The cursor is disabled and hidden from the user.
    const Self = @This();
    pub inline fn isCaptured(self: *const Self) bool {
        self.* == CursorMode.Captured;
    }

    pub inline fn isDisabled(self: *const Self) bool {
        self.* == CursorMode.Disabled;
    }
};

pub const CursorShape = enum(u8) {
    Default, // Platform Default cursor.
    Hand, // Hand with index pointing, used for links on web pages.
    Crosshair, // Crosshair.
    Help, // The `?` cursor.
    Wait, // Indicate that the user should wait for program.
    Loading, // Indicate that some processing is going on.
    NotAllowed, // Indicate that the attempted action is not allowed.
    Text, // Text input indicator.
};

pub const WindowData = struct {
    title: []const u8, // The window title.
    video: VideoMode, // The video mode of the window.
    position: ?WidowPoint2D, // The current Position of the top left corner of the
    restore_point: ?WidowPoint2D, // Keeps track of where to restore the window when exiting
    min_size: ?WidowSize, // The minimum limits of the window's size.
    max_size: ?WidowSize, // The maximum limits of the window's size.
    aspect_ratio: ?AspectRatio, // The (numerator,denominator) of the applied aspect ratio.
    fullscreen_mode: ?FullScreenMode,
    flags: WindowFlags,
    input: InputState, // Both the keyboard and mouse buttons states.
};
