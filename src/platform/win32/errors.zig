pub const WidowWin32Error = error{
    FailedToRegisterWNDCLASS,
    FailedToRegisterHELPCLASS,
    NtdllNotFound, // Couldn't load Ntdll library.
    ProcessHandleNotFound, // Couldn't retrieve the hinstance value.
    FailedToInitPlatform, // Platform initialization failed.
};
