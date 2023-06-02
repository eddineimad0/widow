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

pub const CursorShape = enum(u8) {
    Default, // Platform Default cursor.
    PointingHand, // Hand with index pointing, used for links on web pages.
    Crosshair, // Crosshair.
    Help, // The `?` cursor.
    Wait, // Indicate that the user should wait for program.
    Busy, // Indicate that some processing is going on.
    Forbidden, // Indicate that the attempted action is not allowed.
    Text, // Text input indicator.
};
