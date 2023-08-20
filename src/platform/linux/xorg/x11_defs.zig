// pub const DestroyWindow = extern struct {
//     request_type: u8 = 4,
//     pad0: u8 = 0,
//     length: u16 = 8 >> 2,
//     id: WINDOW,
// };
//
// pub const MapWindow = extern struct {
//     request_type: u8 = 8,
//     pad0: u8 = 0,
//     length: u16 = 8 >> 2,
//     id: WINDOW,
// };
//
// pub const UnmapWindow = extern struct {
//     request_type: u8 = 10,
//     pad0: u8 = 0,
//     length: u16 = 8 >> 2,
//     id: WINDOW,
// };
//
// pub const ChangeProperty = extern struct {
//     request_type: u8 = 18,
//     mode: u8 = 0,
//     request_length: u16,
//     window: WINDOW,
//     property: u32,
//     property_type: u32,
//     format: u8,
//     pad0: [3]u8 = [3]u8{ 0, 0, 0 },
//     length: u32,
// };
//
// pub const DeleteProperty = extern struct {
//     request_type: u8 = 19,
//     pad0: u8 = 0,
//     request_length: u16 = 3,
//     window: u32,
//     property: u32,
// };
//
// pub const SizeHints = extern struct {
//     flags: u32 = 0,
//     pad0: [4]u32 = [_]u32{0} ** 4,
//     min: [2]u32 = [2]u32{ 0, 0 },
//     max: [2]u32 = [2]u32{ 0, 0 },
//     inc: [2]u32 = [2]u32{ 0, 0 },
//     aspect_min: [2]u32 = [2]u32{ 0, 0 },
//     aspect_max: [2]u32 = [2]u32{ 0, 0 },
//     base: [2]u32 = [2]u32{ 0, 0 },
//     win_gravity: u32 = 0,
// };
//
// pub const MotifHints = extern struct {
//     flags: u32,
//     functions: u32,
//     decorations: u32,
//     input_mode: i32,
//     status: u32,
// };
//
// pub const CreatePixmap = extern struct {
//     request_type: u8 = 53,
//     depth: u8,
//     request_length: u16 = 4,
//     pid: PIXMAP,
//     drawable: DRAWABLE,
//     width: u16,
//     height: u16,
// };
//
// pub const FreePixmap = extern struct {
//     request_type: u8 = 54,
//     pad0: u8 = 0,
//     request_length: u16 = 2,
//     pixmap: u32,
// };
//
// pub const CreateGC = extern struct {
//     request_type: u8 = 55,
//     unsued: u8 = 0,
//     request_length: u16,
//     cid: GCONTEXT,
//     drawable: DRAWABLE,
//     bitmask: u32,
// };
//
// pub const FreeGC = extern struct {
//     request_type: u8 = 60,
//     unsued: u8 = 0,
//     request_length: u16 = 2,
//     gc: GCONTEXT,
// };
//
// pub const CopyArea = extern struct {
//     request_type: u8 = 62,
//     pad0: u8 = 0,
//     request_length: u16 = 7,
//     src_drawable: DRAWABLE,
//     dst_drawable: DRAWABLE,
//     gc: GCONTEXT,
//     src_x: u16,
//     src_y: u16,
//     dst_x: u16,
//     dst_y: u16,
//     width: u16,
//     height: u16,
// };
//
// pub const PutImage = extern struct {
//     request_type: u8 = 72,
//     format: u8 = 2,
//     request_length: u16,
//     drawable: DRAWABLE,
//     gc: u32,
//     width: u16,
//     height: u16,
//     dst: [2]u16,
//     left_pad: u8 = 0,
//     depth: u8 = 24,
//     pad0: [2]u8 = [2]u8{ 0, 0 },
// };
//
// pub const PutImageBig = extern struct {
//     request_type: u8 = 72,
//     format: u8 = 2,
//     request_length_tag: u16 = 0,
//     request_length: u32,
//     drawable: DRAWABLE,
//     gc: u32,
//     width: u16,
//     height: u16,
//     dst: [2]u16,
//     left_pad: u8 = 0,
//     depth: u8 = 24,
//     pad0: [2]u8 = [2]u8{ 0, 0 },
// };
//
// pub const InternAtom = extern struct {
//     request_type: u8 = 16,
//     if_exists: u8,
//     request_length: u16,
//     name_length: u16,
//     pad0: u16 = 0,
// };
//
// pub const InternAtomReply = extern struct {
//     reply: u8,
//     pad0: u8,
//     seqence_number: u16,
//     reply_length: u32,
//     atom: u32,
//     pad1: [20]u8,
// };
//
// // BigRequests
//
// pub const BigReqEnable = extern struct {
//     opcode: u8,
//     pad0: u8 = 0,
//     length_request: u16 = 1,
// };
//
// pub const BigReqEnableReply = extern struct {
//     opcode: u8,
//     pad0: u8,
//     seqence_number: u16,
//     reply_length: u32,
//     max_req_len: u32,
//     pad1: u16,
// };
//
// // RandR
// pub const RRQueryVersion = extern struct {
//     opcode: u8,
//     minor: u8 = 0,
//     length_request: u16 = 3,
//     version_major: u32,
//     version_minor: u32,
// };
//
// pub const RRQueryVersionReply = extern struct {
//     opcode: u8,
//     pad0: u8,
//     seqence_number: u16,
//     reply_length: u32,
//     version_major: u32,
//     version_minor: u32,
// };
//
// pub const RRGetScreenResources = extern struct {
//     opcode: u8,
//     minor: u8 = 8,
//     length_request: u16 = 2,
//     window: u32,
// };
//
// pub const RRGetScreenResourcesCurrent = extern struct {
//     opcode: u8,
//     minor: u8 = 25,
//     length_request: u16 = 2,
//     window: u32,
// };
//
// pub const RRGetScreenResourcesReply = extern struct {
//     opcode: u8,
//     pad0: u8,
//     seqence_number: u16,
//     reply_length: u32,
//     timestamp: u32,
//     config_timestamp: u32,
//     crtcs: u16,
//     outputs: u16,
//     modes: u16,
//     names: u16,
// };
//
// pub const ModeInfo = extern struct {
//     id: u32,
//     width: u16,
//     height: u16,
//     dot_clock: u32,
//     hsync_start: u16,
//     hsync_end: u16,
//     htotal: u16,
//     hscew: u16,
//     vsync_start: u16,
//     vsync_end: u16,
//     vtotal: u16,
//     name_len: u16,
//     flags: u32,
// };
//
// // XFixes
//
// pub const XFixesQueryVersion = extern struct {
//     opcode: u8,
//     minor: u8 = 0,
//     length_request: u16 = 3,
//     version_major: u32,
//     version_minor: u32,
// };
//
// pub const XFixesQueryVersionReply = extern struct {
//     opcode: u8,
//     pad0: u8,
//     seqence_number: u16,
//     reply_length: u32,
//     version_major: u32,
//     version_minor: u32,
// };
//
// pub const CreateRegion = extern struct {
//     opcode: u8,
//     minor: u8 = 5,
//     length_request: u16,
//     region: REGION,
// };
//
// pub const DestroyRegion = extern struct {
//     opcode: u8,
//     minor: u8 = 10,
//     length_request: u16 = 2,
//     region: REGION,
// };
//
// pub const SetRegion = extern struct {
//     opcode: u8,
//     minor: u8 = 11,
//     length_request: u16,
//     region: REGION,
// };
//
// // Present
// pub const PresentQueryVersion = extern struct {
//     opcode: u8,
//     minor: u8 = 0,
//     length_request: u16 = 3,
//     version_major: u32,
//     version_minor: u32,
// };
//
// pub const PresentPixmap = extern struct {
//     opcode: u8,
//     minor: u8 = 1,
//     length: u16 = 18,
//     window: WINDOW,
//     pixmap: PIXMAP,
//     serial: u32,
//     valid_area: REGION,
//     update_area: REGION,
//     offset_x: i16 = 0,
//     offset_y: i16 = 0,
//     crtc: CRTC,
//     wait_fence: SyncFence,
//     idle_fence: SyncFence,
//     options: u32,
//     unused: u32 = 0,
//     target_msc: u64,
//     divisor: u64,
//     remainder: u64,
// };
//
// pub const PresentNotify = extern struct {
//     window: WINDOW,
//     serial: u32,
// };
//
// pub const PresentSelectInput = extern struct {
//     opcode: u8,
//     minor: u8 = 3,
//     length: u16 = 4,
//     event_id: EventID,
//     window: WINDOW,
//     mask: u32,
// };
//
// pub const PresentCompleteNotify = extern struct {
//     type: u8 = 35,
//     extension: u8,
//     seqnum: u16,
//     length: u32,
//     evtype: u16 = 1,
//     kind: u8,
//     mode: u8,
//     event_id: u32,
//     window: u32,
//     serial: u32,
//     ust: u64,
//     msc: u64,
// };
//
// /// MIT-SHM
// pub const MitShmQueryVersion = extern struct {
//     opcode: u8,
//     minor: u8 = 0,
//     length_request: u16 = 1,
// };
//
// /// Generic Event
// pub const GenericEvent = extern struct {
//     type: u8 = 35,
//     extension: u8,
//     seqnum: u16,
//     length: u32,
//     evtype: u16,
//     pad0: u16,
//     pad1: [5]u32,
// };
//
// /// Event generated when a key/button is pressed/released
// /// or when the input device moves
// pub const InputDeviceEvent = extern struct {
//     type: u8,
//     detail: KEYCODE,
//     sequence: u16,
//     time: u32,
//     root: WINDOW,
//     event: WINDOW,
//     child: WINDOW,
//     root_x: i16,
//     root_y: i16,
//     event_x: i16,
//     event_y: i16,
//     state: u16,
//     same_screen: u8,
//     pad: u8,
// };
//
// // XRANDR
// const XID = c_ulong;
// const RRCrtc = XID;
// const RROutput = XID;
// const RRMode = XID;
// const XRRModeFlags = c_ulong;
// const XRRModeInfo = extern struct {
//     id: RRMode,
//     width: c_uint,
//     height: c_uint,
//     dotClock: c_ulong,
//     hSyncStart: c_uint,
//     hSyncEnd: c_uint,
//     hTotal: c_uint,
//     hSkew: c_uint,
//     vSyncStart: c_uint,
//     vSyncEnd: c_uint,
//     vTotal: c_uint,
//     name: [*:0]u8,
//     nameLength: c_uint,
//     modeFlags: XRRModeFlags,
// };
//
// pub const XRRScreenResources = extern struct {
//     timestamp: c_ulong,
//     configtimestamp: c_ulong,
//     ncrtc: c_int,
//     crtcs: [*]RRCrtc,
//     noutput: c_int,
//     outputs: [*]RROutput,
//     nmode: c_int,
//     modes: [*]XRRModeInfo,
// };
//
