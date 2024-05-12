pub const WidowWin32Error = error{
    FailedToRegisterWNDCLASS,
    FailedToRegisterHELPCLASS,
    NtdllNotFound, // Couldn't load Ntdll library.
    ProcessHandleNotFound, // Couldn't retrieve the hinstance value.
    FailedToInitPlatform, // Platform initialization failed.
};

pub const IconError = error{
    FailedToCreate, // Couldn't create the icon.
    NullColorMask, // Couldn't create the DIB color mask
    NullMonochromeMask, // Couldn't create The DIB monocrhome mask
};

pub const MonitorError = error{
    MonitorHandleNotFound,
    BadVideoMode,
    MonitorNotFound,
};

pub const WindowError = error{
    FailedToCreate,
    FailedToCopyTitle,
    UsupportedDrawingContext,
    DrawingContextReinit,
};
