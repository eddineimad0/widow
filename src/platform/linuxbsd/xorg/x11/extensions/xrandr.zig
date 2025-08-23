const libx11 = @import("../xlib.zig");

// Constants
pub const RANDR_NAME = "RANDR";
pub const RANDR_MAJOR = 1;
pub const RANDR_MINOR = 5;

pub const RRNumberErrors = 4;
pub const RRNumberEvents = 2;
pub const RRNumberRequests = 45;

pub const X_RRQueryVersion = 0;
pub const X_RROldGetScreenInfo = 1;
pub const X_RRSetScreenConfig = 2;
pub const X_RROldScreenChangeSelectInput = 3;
pub const X_RRSelectInput = 4;
pub const X_RRGetScreenInfo = 5;

pub const X_RRGetScreenSizeRange = 6;
pub const X_RRSetScreenSize = 7;
pub const X_RRGetScreenResources = 8;
pub const X_RRGetOutputInfo = 9;
pub const X_RRListOutputProperties = 10;
pub const X_RRQueryOutputProperty = 11;
pub const X_RRConfigureOutputProperty = 12;
pub const X_RRChangeOutputProperty = 13;
pub const X_RRDeleteOutputProperty = 14;
pub const X_RRGetOutputProperty = 15;
pub const X_RRCreateMode = 16;
pub const X_RRDestroyMode = 17;
pub const X_RRAddOutputMode = 18;
pub const X_RRDeleteOutputMode = 19;
pub const X_RRGetCrtcInfo = 20;
pub const X_RRSetCrtcConfig = 21;
pub const X_RRGetCrtcGammaSize = 22;
pub const X_RRGetCrtcGamma = 23;
pub const X_RRSetCrtcGamma = 24;

pub const X_RRGetScreenResourcesCurrent = 25;
pub const X_RRSetCrtcTransform = 26;
pub const X_RRGetCrtcTransform = 27;
pub const X_RRGetPanning = 28;
pub const X_RRSetPanning = 29;
pub const X_RRSetOutputPrimary = 30;
pub const X_RRGetOutputPrimary = 31;

pub const X_RRGetProviders = 32;
pub const X_RRGetProviderInfo = 33;
pub const X_RRSetProviderOffloadSink = 34;
pub const X_RRSetProviderOutputSource = 35;
pub const X_RRListProviderProperties = 36;
pub const X_RRQueryProviderProperty = 37;
pub const X_RRConfigureProviderProperty = 38;
pub const X_RRChangeProviderProperty = 39;
pub const X_RRDeleteProviderProperty = 40;
pub const X_RRGetProviderProperty = 41;

pub const X_RRGetMonitors = 42;
pub const X_RRSetMonitor = 43;
pub const X_RRDeleteMonitor = 44;

pub const RRTransformUnit = 1 << 0;
pub const RRTransformScaleUp = 1 << 1;
pub const RRTransformScaleDown = 1 << 2;
pub const RRTransformProjective = 1 << 3;

pub const RRScreenChangeNotifyMask = 1 << 0;
pub const RRCrtcChangeNotifyMask = 1 << 1;
pub const RROutputChangeNotifyMask = 1 << 2;
pub const RROutputPropertyNotifyMask = 1 << 3;
pub const RRProviderChangeNotifyMask = 1 << 4;
pub const RRProviderPropertyNotifyMask = 1 << 5;
pub const RRResourceChangeNotifyMask = 1 << 6;

pub const RRScreenChangeNotify = 0;
pub const RRNotify = 1;
pub const RRNotify_CrtcChange = 0;
pub const RRNotify_OutputChange = 1;
pub const RRNotify_OutputProperty = 2;
pub const RRNotify_ProviderChange = 3;
pub const RRNotify_ProviderProperty = 4;
pub const RRNotify_ResourceChange = 5;

pub const RR_Rotate_0 = 1;
pub const RR_Rotate_90 = 2;
pub const RR_Rotate_180 = 4;
pub const RR_Rotate_270 = 8;

pub const RR_Reflect_X = 16;
pub const RR_Reflect_Y = 32;

pub const RRSetConfigSuccess = 0;
pub const RRSetConfigInvalidConfigTime = 1;
pub const RRSetConfigInvalidTime = 2;
pub const RRSetConfigFailed = 3;

pub const RR_HSyncPositive = 0x00000001;
pub const RR_HSyncNegative = 0x00000002;
pub const RR_VSyncPositive = 0x00000004;
pub const RR_VSyncNegative = 0x00000008;
pub const RR_Interlace = 0x00000010;
pub const RR_DoubleScan = 0x00000020;
pub const RR_CSync = 0x00000040;
pub const RR_CSyncPositive = 0x00000080;
pub const RR_CSyncNegative = 0x00000100;
pub const RR_HSkewPresent = 0x00000200;
pub const RR_BCast = 0x00000400;
pub const RR_PixelMultiplex = 0x00000800;
pub const RR_DoubleClock = 0x00001000;
pub const RR_ClockDivideBy2 = 0x00002000;

pub const RR_Connected = 0;
pub const RR_Disconnected = 1;
pub const RR_UnknownConnection = 2;

pub const BadRROutput = 0;
pub const BadRRCrtc = 1;
pub const BadRRMode = 2;
pub const BadRRProvider = 3;

pub const RR_PROPERTY_BACKLIGHT = "Backlight";
pub const RR_PROPERTY_RANDR_EDID = "EDID";
pub const RR_PROPERTY_SIGNAL_FORMAT = "SignalFormat";
pub const RR_PROPERTY_SIGNAL_PROPERTIES = "SignalProperties";
pub const RR_PROPERTY_CONNECTOR_TYPE = "ConnectorType";
pub const RR_PROPERTY_CONNECTOR_NUMBER = "ConnectorNumber";
pub const RR_PROPERTY_COMPATIBILITY_LIST = "CompatibilityList";
pub const RR_PROPERTY_CLONE_LIST = "CloneList";
pub const RR_PROPERTY_BORDER = "Border";
pub const RR_PROPERTY_BORDER_DIMENSIONS = "BorderDimensions";
pub const RR_PROPERTY_GUID = "GUID";
pub const RR_PROPERTY_RANDR_TILE = "TILE";

pub const RRCrtc_None = 0;
pub const RR_Capability_None = 0;
pub const RR_Capability_SourceOutput = 1;
pub const RR_Capability_SinkOutput = 2;
pub const RR_Capability_SourceOffload = 4;
pub const RR_Capability_SinkOffload = 8;
pub const RRMode_None = 0;

// Types
pub const Connection = c_ushort;
pub const Rotation = c_ushort;
pub const SizeID = c_ushort;
pub const SubpixelOrder = c_ushort;
pub const XRRModeFlags = c_ulong;

pub const RROutput = libx11.XID;
pub const RRCrtc = libx11.XID;
pub const RRMode = libx11.XID;
pub const RRProvider = libx11.XID;

pub const XRRScreenSize = extern struct {
    width: c_int,
    height: c_int,
    mwidth: c_int,
    mheight: c_int,
};

pub const XRRScreenConfiguration = opaque {};

pub const XRRModeInfo = extern struct {
    id: RRMode,
    width: c_uint,
    height: c_uint,
    dotClock: c_ulong,
    hSyncStart: c_uint,
    hSyncEnd: c_uint,
    hTotal: c_uint,
    hSkew: c_uint,
    vSyncStart: c_uint,
    vSyncEnd: c_uint,
    vTotal: c_uint,
    name: [*:0]u8,
    nameLength: c_uint,
    modeFlags: XRRModeFlags,
};

pub const XRRScreenResources = extern struct {
    timestamp: libx11.Time,
    configTimestamp: libx11.Time,
    ncrtc: c_int,
    crtcs: [*]RRCrtc,
    noutput: c_int,
    outputs: [*]RROutput,
    nmode: c_int,
    modes: [*]XRRModeInfo,
};

pub const XRROutputInfo = extern struct {
    timestamp: libx11.Time,
    crtc: RRCrtc,
    name: [*:0]u8,
    nameLen: c_int,
    mm_width: c_ulong,
    mm_height: c_ulong,
    connection: Connection,
    subpixel_order: SubpixelOrder,
    ncrtc: c_int,
    crtcs: *RRCrtc,
    nclone: c_int,
    clones: *RROutput,
    nmode: c_int,
    npreferred: c_int,
    modes: [*]RRMode,
};

pub const XRRCrtcInfo = extern struct {
    timestamp: libx11.Time,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    mode: RRMode,
    rotation: Rotation,
    noutput: c_int,
    outputs: *RROutput,
    rotations: Rotation,
    npossible: c_int,
    possible: *RROutput,
};

pub const XRRCrtcGamma = extern struct {
    size: c_int,
    red: *c_ushort,
    green: *c_ushort,
    blue: *c_ushort,
};

// Functions signatures.
pub const XRRAllocGammaProc = *const fn (size: c_int) callconv(.c) ?*XRRCrtcGamma;
pub const XRRFreeGammaProc = *const fn (gamma: *XRRCrtcGamma) callconv(.c) void;
pub const XRRFreeCrtcInfoProc = *const fn (crtcInfo: *XRRCrtcInfo) callconv(.c) void;
pub const XRRFreeOutputInfoProc = *const fn (outputInfo: *XRROutputInfo) callconv(.c) void;
pub const XRRFreeScreenResourcesProc = *const fn (resources: *XRRScreenResources) callconv(.c) void;
pub const XRRGetCrtcInfoProc = *const fn (
    dpy: *libx11.Display,
    resources: ?*XRRScreenResources,
    crtc: RRCrtc,
) callconv(.c) *XRRCrtcInfo;
pub const XRRGetOutputInfoProc = *const fn (
    dpy: *libx11.Display,
    resources: *XRRScreenResources,
    output: RROutput,
) callconv(.c) *XRROutputInfo;
pub const XRRGetOutputPrimaryProc = *const fn (
    dpy: *libx11.Display,
    window: libx11.Window,
) callconv(.c) RROutput;
pub const XRRGetScreenResourcesCurrentProc = *const fn (
    dpy: *libx11.Display,
    window: libx11.Window,
) callconv(.c) *XRRScreenResources;
pub const XRRGetScreenResourcesProc = *const fn (
    dpy: *libx11.Display,
    window: libx11.Window,
) callconv(.c) *XRRScreenResources;
pub const XRRQueryExtensionProc = *const fn (
    dpy: *libx11.Display,
    event_base_return: *c_int,
    error_base_return: *c_int,
) callconv(.c) libx11.Bool;
pub const XRRQueryVersionProc = *const fn (
    dpy: *libx11.Display,
    major_version_return: *c_int,
    minor_version_return: *c_int,
) callconv(.c) libx11.Status;
pub const XRRSelectInputProc = *const fn (
    dpy: *libx11.Display,
    window: libx11.Window,
    mask: c_int,
) callconv(.c) void;
pub const XRRSetCrtcConfigProc = *const fn (
    dpy: *libx11.Display,
    resources: *XRRScreenResources,
    crtc: RRCrtc,
    timestamp: libx11.Time,
    x: c_int,
    y: c_int,
    mode: RRMode,
    rotation: Rotation,
    outputs: *RROutput,
    noutputs: c_int,
) callconv(.c) libx11.Status;
pub const XRRSetCrtcGammaProc = *const fn (
    dpy: *libx11.Display,
    crtc: RRCrtc,
    gamma: *XRRCrtcGamma,
) callconv(.c) void;
pub const XRRUpdateConfigurationProc = *const fn (event: *libx11.XEvent) callconv(.c) c_int;
pub const XRRGetCrtcGammaSizeProc = *const fn (dpy: *libx11.Display, crtc: RRCrtc) callconv(.c) c_int;
pub const XRRGetCrtcGammaProc = *const fn (dpy: *libx11.Display, crtc: RRCrtc) callconv(.c) *XRRCrtcGamma;
