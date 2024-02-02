const types = @import("../types.zig");

// Constants
pub const RANDR_NAME = "RANDR";
pub const RANDR_MAJOR: c_int = 1;
pub const RANDR_MINOR: c_int = 5;

pub const RRNumberErrors: c_int = 4;
pub const RRNumberEvents: c_int = 2;
pub const RRNumberRequests: c_int = 45;

pub const X_RRQueryVersion: c_int = 0;
pub const X_RROldGetScreenInfo: c_int = 1;
pub const X_RRSetScreenConfig: c_int = 2;
pub const X_RROldScreenChangeSelectInput: c_int = 3;
pub const X_RRSelectInput: c_int = 4;
pub const X_RRGetScreenInfo: c_int = 5;

pub const X_RRGetScreenSizeRange: c_int = 6;
pub const X_RRSetScreenSize: c_int = 7;
pub const X_RRGetScreenResources: c_int = 8;
pub const X_RRGetOutputInfo: c_int = 9;
pub const X_RRListOutputProperties: c_int = 10;
pub const X_RRQueryOutputProperty: c_int = 11;
pub const X_RRConfigureOutputProperty: c_int = 12;
pub const X_RRChangeOutputProperty: c_int = 13;
pub const X_RRDeleteOutputProperty: c_int = 14;
pub const X_RRGetOutputProperty: c_int = 15;
pub const X_RRCreateMode: c_int = 16;
pub const X_RRDestroyMode: c_int = 17;
pub const X_RRAddOutputMode: c_int = 18;
pub const X_RRDeleteOutputMode: c_int = 19;
pub const X_RRGetCrtcInfo: c_int = 20;
pub const X_RRSetCrtcConfig: c_int = 21;
pub const X_RRGetCrtcGammaSize: c_int = 22;
pub const X_RRGetCrtcGamma: c_int = 23;
pub const X_RRSetCrtcGamma: c_int = 24;

pub const X_RRGetScreenResourcesCurrent: c_int = 25;
pub const X_RRSetCrtcTransform: c_int = 26;
pub const X_RRGetCrtcTransform: c_int = 27;
pub const X_RRGetPanning: c_int = 28;
pub const X_RRSetPanning: c_int = 29;
pub const X_RRSetOutputPrimary: c_int = 30;
pub const X_RRGetOutputPrimary: c_int = 31;

pub const X_RRGetProviders: c_int = 32;
pub const X_RRGetProviderInfo: c_int = 33;
pub const X_RRSetProviderOffloadSink: c_int = 34;
pub const X_RRSetProviderOutputSource: c_int = 35;
pub const X_RRListProviderProperties: c_int = 36;
pub const X_RRQueryProviderProperty: c_int = 37;
pub const X_RRConfigureProviderProperty: c_int = 38;
pub const X_RRChangeProviderProperty: c_int = 39;
pub const X_RRDeleteProviderProperty: c_int = 40;
pub const X_RRGetProviderProperty: c_int = 41;

pub const X_RRGetMonitors: c_int = 42;
pub const X_RRSetMonitor: c_int = 43;
pub const X_RRDeleteMonitor: c_int = 44;

pub const RRTransformUnit: c_int = 1 << 0;
pub const RRTransformScaleUp: c_int = 1 << 1;
pub const RRTransformScaleDown: c_int = 1 << 2;
pub const RRTransformProjective: c_int = 1 << 3;

pub const RRScreenChangeNotifyMask: c_int = 1 << 0;
pub const RRCrtcChangeNotifyMask: c_int = 1 << 1;
pub const RROutputChangeNotifyMask: c_int = 1 << 2;
pub const RROutputPropertyNotifyMask: c_int = 1 << 3;
pub const RRProviderChangeNotifyMask: c_int = 1 << 4;
pub const RRProviderPropertyNotifyMask: c_int = 1 << 5;
pub const RRResourceChangeNotifyMask: c_int = 1 << 6;

pub const RRScreenChangeNotify: c_int = 0;
pub const RRNotify: c_int = 1;
pub const RRNotify_CrtcChange: c_int = 0;
pub const RRNotify_OutputChange: c_int = 1;
pub const RRNotify_OutputProperty: c_int = 2;
pub const RRNotify_ProviderChange: c_int = 3;
pub const RRNotify_ProviderProperty: c_int = 4;
pub const RRNotify_ResourceChange: c_int = 5;

pub const RR_Rotate_0: c_int = 1;
pub const RR_Rotate_90: c_int = 2;
pub const RR_Rotate_180: c_int = 4;
pub const RR_Rotate_270: c_int = 8;

pub const RR_Reflect_X: c_int = 16;
pub const RR_Reflect_Y: c_int = 32;

pub const RRSetConfigSuccess: c_int = 0;
pub const RRSetConfigInvalidConfigTime: c_int = 1;
pub const RRSetConfigInvalidTime: c_int = 2;
pub const RRSetConfigFailed: c_int = 3;

pub const RR_HSyncPositive: c_int = 0x00000001;
pub const RR_HSyncNegative: c_int = 0x00000002;
pub const RR_VSyncPositive: c_int = 0x00000004;
pub const RR_VSyncNegative: c_int = 0x00000008;
pub const RR_Interlace: c_int = 0x00000010;
pub const RR_DoubleScan: c_int = 0x00000020;
pub const RR_CSync: c_int = 0x00000040;
pub const RR_CSyncPositive: c_int = 0x00000080;
pub const RR_CSyncNegative: c_int = 0x00000100;
pub const RR_HSkewPresent: c_int = 0x00000200;
pub const RR_BCast: c_int = 0x00000400;
pub const RR_PixelMultiplex: c_int = 0x00000800;
pub const RR_DoubleClock: c_int = 0x00001000;
pub const RR_ClockDivideBy2: c_int = 0x00002000;

pub const RR_Connected: c_int = 0;
pub const RR_Disconnected: c_int = 1;
pub const RR_UnknownConnection: c_int = 2;

pub const BadRROutput: c_int = 0;
pub const BadRRCrtc: c_int = 1;
pub const BadRRMode: c_int = 2;
pub const BadRRProvider: c_int = 3;

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

pub const RRCrtc_None: types.XID = 0;
pub const RR_Capability_None: c_int = 0;
pub const RR_Capability_SourceOutput: c_int = 1;
pub const RR_Capability_SinkOutput: c_int = 2;
pub const RR_Capability_SourceOffload: c_int = 4;
pub const RR_Capability_SinkOffload: c_int = 8;
pub const RRMode_None: RRMode = 0;

// Types
pub const Connection = c_ushort;
pub const Rotation = c_ushort;
pub const SizeID = c_ushort;
pub const SubpixelOrder = c_ushort;
pub const XRRModeFlags = c_ulong;

pub const RROutput = types.XID;
pub const RRCrtc = types.XID;
pub const RRMode = types.XID;
pub const RRProvider = types.XID;

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
    timestamp: types.Time,
    configTimestamp: types.Time,
    ncrtc: c_int,
    crtcs: [*]RRCrtc,
    noutput: c_int,
    outputs: [*]RROutput,
    nmode: c_int,
    modes: [*]XRRModeInfo,
};

pub const XRROutputInfo = extern struct {
    timestamp: types.Time,
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
    timestamp: types.Time,
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
pub const XRRAllocGammaProc = *const fn (size: c_int) callconv(.C) ?*XRRCrtcGamma;
pub const XRRFreeGammaProc = *const fn (gamma: *XRRCrtcGamma) callconv(.C) void;
pub const XRRFreeCrtcInfoProc = *const fn (crtcInfo: *XRRCrtcInfo) callconv(.C) void;
pub const XRRFreeOutputInfoProc = *const fn (outputInfo: *XRROutputInfo) callconv(.C) void;
pub const XRRFreeScreenResourcesProc = *const fn (resources: *XRRScreenResources) callconv(.C) void;
pub const XRRGetCrtcInfoProc = *const fn (
    dpy: *types.Display,
    resources: ?*XRRScreenResources,
    crtc: RRCrtc,
) callconv(.C) *XRRCrtcInfo;
pub const XRRGetOutputInfoProc = *const fn (
    dpy: *types.Display,
    resources: *XRRScreenResources,
    output: RROutput,
) callconv(.C) *XRROutputInfo;
pub const XRRGetOutputPrimaryProc = *const fn (
    dpy: *types.Display,
    window: types.Window,
) callconv(.C) RROutput;
pub const XRRGetScreenResourcesCurrentProc = *const fn (
    dpy: *types.Display,
    window: types.Window,
) callconv(.C) *XRRScreenResources;
pub const XRRGetScreenResourcesProc = *const fn (
    dpy: *types.Display,
    window: types.Window,
) callconv(.C) *XRRScreenResources;
pub const XRRQueryExtensionProc = *const fn (
    dpy: *types.Display,
    event_base_return: *c_int,
    error_base_return: *c_int,
) callconv(.C) types.Bool;
pub const XRRQueryVersionProc = *const fn (
    dpy: *types.Display,
    major_version_return: *c_int,
    minor_version_return: *c_int,
) callconv(.C) types.Status;
pub const XRRSelectInputProc = *const fn (
    dpy: *types.Display,
    window: types.Window,
    mask: c_int,
) callconv(.C) void;
pub const XRRSetCrtcConfigProc = *const fn (
    dpy: *types.Display,
    resources: *XRRScreenResources,
    crtc: RRCrtc,
    timestamp: types.Time,
    x: c_int,
    y: c_int,
    mode: RRMode,
    rotation: Rotation,
    outputs: *RROutput,
    noutputs: c_int,
) callconv(.C) types.Status;
pub const XRRSetCrtcGammaProc = *const fn (
    dpy: *types.Display,
    crtc: RRCrtc,
    gamma: *XRRCrtcGamma,
) callconv(.C) void;
pub const XRRUpdateConfigurationProc = *const fn (event: *types.XEvent) callconv(.C) c_int;
pub const XRRGetCrtcGammaSizeProc = *const fn (dpy: *types.Display, crtc: RRCrtc) callconv(.C) c_int;
pub const XRRGetCrtcGammaProc = *const fn (dpy: *types.Display, crtc: RRCrtc) callconv(.C) *XRRCrtcGamma;
