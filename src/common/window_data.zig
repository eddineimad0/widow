const geometry = @import("./geometry.zig");

pub const WindowSize = struct {
    logical_width: i32,
    logical_height: i32,
    scale: f64,
    physical_width: i32,
    physical_height: i32,
};

pub const WindowDpiInfo = struct {
    scale_factor: f64,
    dpi_x: f64,
    dpi_y: f64,
};

pub const WindowId = usize;

pub const WindowFlags = packed struct {
    is_visible: bool, // Does the window appear on screen or is it hidden from the user.
    is_maximized: bool, // Is the window maximized.
    is_minimized: bool, // Is the window minimized.
    is_resizable: bool, // Can the window be resized by draging it's border.
    is_decorated: bool, // Does the window have a title bar(caption) and borders.
    is_topmost: bool, // Should the window be always on top of all active windows.
    is_focused: bool, // Does the window have keyboard and input focus.
    is_fullscreen: bool, // Is the window in fullscreen mode.
    is_dpi_aware: bool, // Should the window dimensions be scaled by the dpi scale factor
    cursor_in_client: bool, // Is the cursor currently in client area.
    has_raw_mouse: bool, // true if the window support raw mouse motion
};

pub const WindowData = struct {
    id: WindowId,
    client_area: geometry.Rect, // The Size and position of the client(content) area.
    aspect_ratio: ?geometry.AspectRatio, // The (numerator,denominator) of the applied aspect ratio.
    min_size: ?geometry.RectSize, // The minimum limits of the window's size.
    max_size: ?geometry.RectSize, // The maximum limits of the window's size.
    flags: WindowFlags,
};
