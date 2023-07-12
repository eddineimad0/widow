const WidowPoint2D = @import("./geometry.zig").WidowPoint2D;
const WidowArea = @import("./geometry.zig").WidowArea;
const WidowSize = @import("./geometry.zig").WidowSize;
const AspectRatio = @import("./geometry.zig").AspectRatio;
const InputState = @import("./keyboard_and_mouse.zig").InputState;

pub const WindowFlags = packed struct {
    is_visible: bool, // Does the window appear on screen or is it hidden from the user.
    is_maximized: bool, // Is the window maximized.
    is_minimized: bool, // Is the window minimized.
    is_resizable: bool, // Can the window be resized by draging it's border.
    is_decorated: bool, // Does the window have a title bar(caption) and borders.
    is_topmost: bool, // Should the window be always on top of all active windows.
    is_focused: bool, // Does the window have keyboard and input focus.
    is_fullscreen: bool, // Is the Window in fullscreen mode.
    cursor_in_client: bool, // Is the cursor currently in client area.
    allow_dpi_scaling: bool, // Should the window dimensions be scaled by the dpi scale factor.
};

pub const WindowData = struct {
    id: u32,
    client_area: WidowArea, // The Size(non dpi scaled) and position(top left corner) of the client(content) area.
    aspect_ratio: ?AspectRatio, // The (numerator,denominator) of the applied aspect ratio.
    min_size: ?WidowSize, // The minimum limits of the window's size.
    max_size: ?WidowSize, // The maximum limits of the window's size.
    // fullscreen_mode: ?FullScreenMode,
    flags: WindowFlags,
    input: InputState, // Both the keyboard and mouse buttons states.
};
