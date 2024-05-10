pub const CursorMode = enum(u8) {
    Normal, // Default cursor mode.
    Captured, // The cursor is restricted to the window area.
    Hidden, // The cursor is disabled and hidden from the user.
};

pub const StandardCursorShape = enum(u8) {
    Default, // Platform Default cursor.
    Move, // <-|-> Cursor for moving around.
    PointingHand, // Hand with index pointing, used for links on web pages.
    Crosshair, // Crosshair.
    Help, // The `?` cursor.
    BkgrndTask, // Indicate that a task is running in background.
    Busy, // Indicate that the user should wait for program to finish.
    Forbidden, // Indicate that the action is not allowed.
    Text, // Text input indicator.
};
