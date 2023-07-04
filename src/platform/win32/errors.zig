pub const WidowWin32Error = error{
    FailedToRegisterWNDCLASS,
    NtdllNotFound,
    ProcessHandleNotFound,
    User32DLLNotFound,
    FailedToInitPlatform,
};

pub const ClipboardError = error{
    FailedToOpen,
    AccessDenied,
    FailedToUpdate,
    AllocationFailure,
    OwnershipDenied,
    FailedToRegisterViewer,
};

pub const IconError = error{
    FailedToCreateIcon,
    NullColorMask,
    NullMonochromeMask,
};

pub const MonitorError = error{
    MonitorHandleNotFound,
    BadVideoMode,
    MonitorNotFound,
};

pub const WindowError = error{
    FailedToCreate,
    NullMonitorHandle,
};

pub const XInputError = error{
    FailedToLoadDLL,
    FailedToLoadLibraryFunc,
    FailedToSetState,
    UnsupportedFunctionality,
    NonCapableDevice,
};
