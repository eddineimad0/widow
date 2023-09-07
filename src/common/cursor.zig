pub const CursorMode = enum(u8) {
    Normal, // Default cursor mode.
    Captured, // The cursor is restricted to the window area.
    Disabled, // The cursor is disabled and hidden from the user.
    const Self = @This();
    pub inline fn is_captured(self: *const Self) bool {
        return self.* == CursorMode.Captured;
    }

    pub inline fn is_disabled(self: *const Self) bool {
        return self.* == CursorMode.Disabled;
    }
};

pub const StandardCursorShape = enum(u8) {
    Default, // Platform Default cursor.
    Move, // <-|-> Cursor for moving around.
    PointingHand, // Hand with index pointing, used for links on web pages.
    Crosshair, // Crosshair.
    Help, // The `?` cursor.
    BkgrndTask, // Indicate that a task is running in background.
    Busy, // Indicate that the user should wait for program.
    Forbidden, // Indicate that the attempted action is not allowed.
    Text, // Text input indicator.
};
