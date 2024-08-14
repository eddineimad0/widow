const types = @import("../types.zig");

pub const XI_2_Major = 2;
pub const XI_2_Minor = 0;

// Property event flags
pub const XIPropertyDeleted = 0;
pub const XIPropertyCreated = 1;
pub const XIPropertyModified = 2;

// Enter/Leave and Focus In/Out modes
pub const XINotifyNormal = 0;
pub const XINotifyGrab = 1;
pub const XINotifyUngrab = 2;
pub const XINotifyWhileGrabbed = 3;
pub const XINotifyPassiveGrab = 4;
pub const XINotifyPassiveUngrab = 5;

// Enter/Leave and focus In/out detail */
pub const XINotifyAncestor = 0;
pub const XINotifyVirtual = 1;
pub const XINotifyInferior = 2;
pub const XINotifyNonlinear = 3;
pub const XINotifyNonlinearVirtual = 4;
pub const XINotifyPointer = 5;
pub const XINotifyPointerRoot = 6;
pub const XINotifyDetailNone = 7;

// Passive grab types */
pub const XIGrabtypeButton = 0;
pub const XIGrabtypeKeycode = 1;
pub const XIGrabtypeEnter = 2;
pub const XIGrabtypeFocusIn = 3;

// Passive grab modifier */
pub const XIAnyModifier = (@as(c_ulong, 1) << 31);
pub const XIAnyButton = 0;
pub const XIAnyKeycode = 0;

// XIAllowEvents event-modes */
pub const XIAsyncDevice = 0;
pub const XISyncDevice = 1;
pub const XIReplayDevice = 2;
pub const XIAsyncPairedDevice = 3;
pub const XIAsyncPair = 4;
pub const XISyncPair = 5;

// DeviceChangedEvent change reasons */
pub const XISlaveSwitch = 1;
pub const XIDeviceChange = 2;

// Hierarchy flags */
pub const XIMasterAdded = (1 << 0);
pub const XIMasterRemoved = (1 << 1);
pub const XISlaveAdded = (1 << 2);
pub const XISlaveRemoved = (1 << 3);
pub const XISlaveAttached = (1 << 4);
pub const XISlaveDetached = (1 << 5);
pub const XIDeviceEnabled = (1 << 6);
pub const XIDeviceDisabled = (1 << 7);

// ChangeHierarchy constants */
pub const XIAddMaster = 1;
pub const XIRemoveMaster = 2;
pub const XIAttachSlave = 3;
pub const XIDetachSlave = 4;

pub const XIAttachToMaster = 1;
pub const XIFloating = 2;

// Valuator modes */
pub const XIModeRelative = 0;
pub const XIModeAbsolute = 1;

// Device types */
pub const XIMasterPointer = 1;
pub const XIMasterKeyboard = 2;
pub const XISlavePointer = 3;
pub const XISlaveKeyboard = 4;
pub const XIFloatingSlave = 5;

// Device classes */
pub const XIKeyClass = 0;
pub const XIButtonClass = 1;
pub const XIValuatorClass = 2;

// Device event flags (common) */
// Device event flags (key events only) */
pub const XIKeyRepeat = (1 << 16);
// Device event flags (pointer events only) */

// XI2 event mask macros */
pub inline fn XISetMask(ptr: [*]u8, event: i32) void {
    ptr[maskIndex(event)] |= (1 << (event & 7));
}

pub inline fn XIClearMask(ptr: [*]u8, event: i32) void {
    ptr[maskIndex(event)] &= ~(1 << (event & 7));
}

pub inline fn XIMaskIsSet(ptr: [*]const u8, event: i32) bool {
    return (ptr[maskIndex(event)] & (1 << (event & 7))) != 0;
}

pub inline fn XIMaskLen(event: i32) usize {
    return maskIndex(event) + 1;
}

pub inline fn maskIndex(event: i32) usize {
    return @intCast(event >> 3);
}

// Fake device ID's for event selection */
pub const XIAllDevices = 0;
pub const XIAllMasterDevices = 1;

// Event types */
pub const XI_DeviceChanged = 1;
pub const XI_KeyPress = 2;
pub const XI_KeyRelease = 3;
pub const XI_ButtonPress = 4;
pub const XI_ButtonRelease = 5;
pub const XI_Motion = 6;
pub const XI_Enter = 7;
pub const XI_Leave = 8;
pub const XI_FocusIn = 9;
pub const XI_FocusOut = 10;
pub const XI_HierarchyChanged = 11;
pub const XI_PropertyEvent = 12;
pub const XI_RawKeyPress = 13;
pub const XI_RawKeyRelease = 14;
pub const XI_RawButtonPress = 15;
pub const XI_RawButtonRelease = 16;
pub const XI_RawMotion = 17;
pub const XI_LASTEVENT = XI_RawMotion;

// Event masks.
//   Note: the protocol spec defines a mask to be of (1 << type). Clients are
//   free to create masks by bitshifting instead of using these defines.
//
pub const XI_DeviceChangedMask = (1 << XI_DeviceChanged);
pub const XI_KeyPressMask = (1 << XI_KeyPress);
pub const XI_KeyReleaseMask = (1 << XI_KeyRelease);
pub const XI_ButtonPressMask = (1 << XI_ButtonPress);
pub const XI_ButtonReleaseMask = (1 << XI_ButtonRelease);
pub const XI_MotionMask = (1 << XI_Motion);
pub const XI_EnterMask = (1 << XI_Enter);
pub const XI_LeaveMask = (1 << XI_Leave);
pub const XI_FocusInMask = (1 << XI_FocusIn);
pub const XI_FocusOutMask = (1 << XI_FocusOut);
pub const XI_HierarchyChangedMask = (1 << XI_HierarchyChanged);
pub const XI_PropertyEventMask = (1 << XI_PropertyEvent);
pub const XI_RawKeyPressMask = (1 << XI_RawKeyPress);
pub const XI_RawKeyReleaseMask = (1 << XI_RawKeyRelease);
pub const XI_RawButtonPressMask = (1 << XI_RawButtonPress);
pub const XI_RawButtonReleaseMask = (1 << XI_RawButtonRelease);
pub const XI_RawMotionMask = (1 << XI_RawMotion);

// Structs

pub const XIEventMask = extern struct {
    deviceid: c_int,
    mask_len: c_int,
    mask: [*]u8,
};

pub const XIValuatorState = extern struct {
    mask_len: c_int,
    mask: [*]u8,
    values: [*]f64,
};

pub const XIRawEvent = extern struct {
    type: c_int, // GenericEvent
    serial: c_ulong, // # of last request processed by server
    send_event: types.Bool, // true if this came from a SendEvent request
    display: ?*types.Display, // Display the event was read from
    extension: c_int, // XI extension offset
    evtype: c_int, // XI_RawKeyPress, XI_RawKeyRelease, etc.
    time: types.Time,
    deviceid: c_int,
    sourceid: c_int, // Bug: Always 0. https://bugs.freedesktop.org//show_bug.cgi?id=34240
    detail: c_int,
    flags: c_int,
    valuators: XIValuatorState,
    raw_values: [*]f64,
};

// Functions
pub const XIQueryVersionProc = *const fn (
    display: ?*types.Display,
    maj_version: *c_int,
    min_version: *c_int,
) callconv(.C) types.Status;

pub const XISelectEventsProc = *const fn (
    display: ?*types.Display,
    win: types.Window,
    masks: [*]XIEventMask,
    num_masks: c_int,
) callconv(.C) types.Status;
