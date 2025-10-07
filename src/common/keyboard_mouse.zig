pub const KeyState = enum(u8) {
    Released = 0,
    Pressed,

    const Self = @This();
    pub inline fn isPressed(self: *const Self) bool {
        return self.* == .Pressed;
    }

    pub inline fn isReleased(self: *const Self) bool {
        return self.* == .Released;
    }
};

pub const MouseButtonState = KeyState;

/// Represent what the hardware key maps to.
/// Depends on the current keyboard layout.
pub const KeyCode = enum(i32) {
    Unknown = -1, // Unknown key
    A = 0, // The A key
    B = 1, // The B key
    C, // The C key
    D, // The D key
    E, // The E key
    F, // The F key
    G, // The G key
    H, // The H key
    I, // The I key
    J, // The J key
    K, // The K key
    L, // The L key
    M, // The M key
    N, // The N key
    O, // The O key
    P, // The P key
    Q, // The Q key
    R, // The R key
    S, // The S key
    T, // The T key
    U, // The U key
    V, // The V key
    W, // The W key
    X, // The X key
    Y, // The Y key
    Z, // The Z key
    Num0, // The 0 key
    Num1, // The 1 key
    Num2, // The 2 key
    Num3, // The 3 key
    Num4, // The 4 key
    Num5, // The 5 key
    Num6, // The 6 key
    Num7, // The 7 key
    Num8, // The 8 key
    Num9, // The 9 key
    Escape, // The Escape key
    Control, // The Control key (left or right)
    Shift, // The Shift key (left or right)
    Alt, // The Alt key (left or right)
    Super, // The OS specific key (left or right): window (Windows and Linux), apple (MacOS X), ...
    LBracket, // The [ and { key
    RBracket, // The ] and } key
    Semicolon, // The ; and : key
    Comma, // The , key
    Period, // The . key
    Quote, // The ' and " key
    Slash, // The / and ? key
    Backslash, // The \ and | key
    Grave, // The ` and ~ key
    Equal, // The = key
    Hyphen, // The - key (hyphen)
    Space, // The Space key
    Return, // The Enter/Return keys
    Backspace, // The Backspace key
    Tab, // The Tabulation key
    CapsLock, // The Caps Lock Key
    PageUp, // The Page up key
    PageDown, // The Page down key
    PrintScreen, // The Print Page key
    End, // The End key
    Home, // The Home key
    Insert, // The Insert key
    Delete, // The Delete key
    Pause, // The Pause Key
    Menu, // The Menu key
    Left, // Left arrow
    Right, // Right arrow
    Up, // Up arrow
    Down, // Down arrow
    Numpad0, // The numpad 0 key
    Numpad1, // The numpad 1 key
    Numpad2, // The numpad 2 key
    Numpad3, // The numpad 3 key
    Numpad4, // The numpad 4 key
    Numpad5, // The numpad 5 key
    Numpad6, // The numpad 6 key
    Numpad7, // The numpad 7 key
    Numpad8, // The numpad 8 key
    Numpad9, // The numpad 9 key
    Add, // The numpad + key
    Subtract, // The numpad - key
    Multiply, // The Numpad * key
    Divide, // The Numpad / key
    NumLock, // The Num Lock key
    ScrollLock, // The ScrLk key
    F1, // The F1 key
    F2, // The F2 key
    F3, // The F3 key
    F4, // The F4 key
    F5, // The F5 key
    F6, // The F6 key
    F7, // The F7 key
    F8, // The F8 key
    F9, // The F9 key
    F10, // The F10 key
    F11, // The F11 key
    F12, // The F12 key
    VolumeUp, // The Volume Up Key
    VolumeDown, // The Volume Down Key
    VolumeMute, // The Volume Mute key
    NextTrack, // The >>| key
    PrevTrack, // The |<< key
    PlayPause, // The play/pause key
};

/// Represent the codes emitted by the keybaard hardware to the OS.
pub const ScanCode = enum(i32) {
    Unknown = -1, // Unknown key
    A = 0, // The A key
    B = 1, // The B key
    C, // The C key
    D, // The D key
    E, // The E key
    F, // The F key
    G, // The G key
    H, // The H key
    I, // The I key
    J, // The J key
    K, // The K key
    L, // The L key
    M, // The M key
    N, // The N key
    O, // The O key
    P, // The P key
    Q, // The Q key
    R, // The R key
    S, // The S key
    T, // The T key
    U, // The U key
    V, // The V key
    W, // The W key
    X, // The X key
    Y, // The Y key
    Z, // The Z key
    Num0, // The 0 key
    Num1, // The 1 key
    Num2, // The 2 key
    Num3, // The 3 key
    Num4, // The 4 key
    Num5, // The 5 key
    Num6, // The 6 key
    Num7, // The 7 key
    Num8, // The 8 key
    Num9, // The 9 key
    Escape, // The Escape key
    LControl, // The left Control key
    LShift, // The left Shift key
    LAlt, // The left Alt key
    LSuper, // The left OS specific key: window (Windows and Linux), apple (MacOS X), ...
    RControl, // The right Control key
    RShift, // The right Shift key
    RAlt, // The right Alt key
    RSuper, // The right OS specific key: window (Windows and Linux), apple (MacOS X), ...
    LBracket, // The [ and { key
    RBracket, // The ] and } key
    Semicolon, // The ; and : key
    Comma, // The , key
    Period, // The . key
    Quote, // The ' and " key
    Slash, // The / and ? key
    Backslash, // The \ and | key
    Grave, // The ` and ~ key
    Equal, // The = key
    Hyphen, // The - key (hyphen)
    Space, // The Space key
    Return, // The Enter/Return keys
    Backspace, // The Backspace key
    Tab, // The Tabulation key
    CapsLock, // The Caps Lock Key
    PageUp, // The Page up key
    PageDown, // The Page down key
    PrintScreen, // The Print Page key
    End, // The End key
    Home, // The Home key
    Insert, // The Insert key
    Delete, // The Delete key
    Pause, // The Pause Key
    Menu, // The Menu key
    Left, // Left arrow
    Right, // Right arrow
    Up, // Up arrow
    Down, // Down arrow
    Numpad0, // The numpad 0 key
    Numpad1, // The numpad 1 key
    Numpad2, // The numpad 2 key
    Numpad3, // The numpad 3 key
    Numpad4, // The numpad 4 key
    Numpad5, // The numpad 5 key
    Numpad6, // The numpad 6 key
    Numpad7, // The numpad 7 key
    Numpad8, // The numpad 8 key
    Numpad9, // The numpad 9 key
    NumpadReturn, // The numpad Enter/Return key
    NumpadAdd, // The numpad + key
    NumpadSubtract, // The numpad - key
    NumpadMultiply, // The Numpad * key
    NumpadDivide, // The Numpad / key
    NumpadEqual, // The Numpad = key
    NumpadDecimal, // The numpad period(.) key
    NumLock, // The Num Lock key
    ScrollLock, // The ScrLk key
    F1, // The F1 key
    F2, // The F2 key
    F3, // The F3 key
    F4, // The F4 key
    F5, // The F5 key
    F6, // The F6 key
    F7, // The F7 key
    F8, // The F8 key
    F9, // The F9 key
    F10, // The F10 key
    F11, // The F11 key
    F12, // The F12 key
    Key102nd, // Unlabeled usually backslash on non us keyboards
    VolumeUp, // The Volume Up Key
    VolumeDown, // The Volume Down Key
    VolumeMute, // The Volume Mute key
    NextTrack, // The >>| key
    PrevTrack, // The |<< key
    PlayPause, // The play/pause key
    // END
    pub const COUNT: u32 = @intCast(@intFromEnum(ScanCode.PlayPause) -
        @intFromEnum(ScanCode.Unknown));
};

pub const KeyModifiers = packed struct {
    shift: bool,
    ctrl: bool,
    alt: bool,
    meta: bool,
    caps_lock: bool,
    num_lock: bool,
};

pub const MouseButton = enum(u8) {
    Left = 0, // Left Mouse Button.
    Right, // Right Mouse Button.
    Middle, // Middle Mouse Button.
    ExtraButton1, // Additional Mouse Button 1 (backward navigation).
    ExtraButton2, // Additional Mouse Button 2 (forward navigation).
    pub const COUNT = @intFromEnum(MouseButton.ExtraButton2) -
        @intFromEnum(MouseButton.Left);
};

const WindowId = usize;
// Events.
pub const KeyEvent = struct {
    window_id: WindowId, // the window with keyboard focus
    keycode: KeyCode, // current layout symbol
    scancode: ScanCode, // hardware key symbol
    state: KeyState, // Pressed or Released
    mods: KeyModifiers, // state of mod keys (shift,ctrl,capslock...)
};

pub const MouseButtonEvent = struct {
    window_id: WindowId,
    button: MouseButton,
    state: MouseButtonState, // Pressed or Released
    mods: KeyModifiers, // state of mod keys (shift,ctrl,capslock...)
};

pub const ScrollEvent = struct {
    window_id: WindowId,
    x_offset: f64, // mouse horizontal scroll offset
    y_offset: f64, // mouse vertical scroll offset
};
