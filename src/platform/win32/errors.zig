pub const WidowWin32Error = error{
    FailedToRegisterWNDCLASS,
    FailedToRegisterHELPCLASS,
    NtdllNotFound, // Couldn't load Ntdll library.
    ProcessHandleNotFound, // Couldn't retrieve the hinstance value.
    FailedToInitPlatform, // Platform initialization failed.
};

pub const ClipboardError = error{
    FailedToOpen, // Failed to open the system's clipboard.
    AccessDenied, // Couldn't gain access to the clipboard data.
    FailedToUpdate, // Failed to write to the clipboard
    OwnershipDenied, // Couldn't gain ownership of the clipboard (required before we can write to it)
    FailedToRegisterViewer, //Couldn't add the window to the viewer chain.
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
};
