//! One of the major goals of this widow is to allow cross compilation of any project that
//! depends on it, for now cross compiling from linux targeting windows is achieved thanks to zig
//! To allow cross compilation from windows targeting linux we need to stop linking against
//! X11 system library and instead load it at runtime.
const std = @import("std");
const posix = @import("common").posix;
const types = @import("types.zig");
const defs = @import("defs.zig");

pub const XOpenDisplayProc = *const fn (display_name: ?[*:0]u8) callconv(.C) ?*types.Display;
pub const XCloseDisplayProc = *const fn (display: ?*types.Display) callconv(.C) c_int;
pub const XInitExtensionProc = *const fn (
    display: ?*types.Display,
    ext_name: ?[*:0]const u8,
) callconv(.C) ?[*]types.XExtCodes;
pub const XAddExtensionProc = *const fn (display: ?*types.Display) callconv(.C) ?[*]types.XExtCodes;

// Multithreading routines.
pub const XInitThreadsProc = *const fn () callconv(.C) c_int;
pub const XLockDisplayProc = *const fn (dispaly: ?*types.Display) callconv(.C) void;
pub const XUnlockDisplayProc = *const fn (display: ?*types.Display) callconv(.C) void;

// Ressource Manager
pub const XrmInitializeProc = *const fn () callconv(.C) void;
pub const XResourceManagerStringProc = *const fn (display: ?*types.Display) callconv(.C) ?[*:0]const u8;
pub const XrmGetStringDatabaseProc = *const fn (data: ?[*:0]const u8) callconv(.C) types.XrmDatabase;
pub const XrmDestroyDatabaseProc = *const fn (db: types.XrmDatabase) callconv(.C) void;
pub const XrmGetResourceProc = *const fn (
    db: types.XrmDatabase,
    str_name: [*:0]const u8,
    str_class: [*:0]const u8,
    str_type_return: *?[*:0]const u8,
    value_return: *types.XrmValue,
) callconv(.C) types.Bool;
pub const XrmUniqueQuarkProc = *const fn () callconv(.C) types.XrmQuark;

// Window Management
pub const XCreateSimpleWindowProc = *const fn (
    display: ?*types.Display,
    parent: types.Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border_width: c_uint,
    border: c_ulong,
    background: c_ulong,
) callconv(.C) types.Window;
pub const XCreateWindowProc = *const fn (
    display: ?*types.Display,
    parent: types.Window,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    border_width: c_uint,
    depth: c_int,
    class: c_uint,
    visual: ?[*]types.Visual,
    value_mask: c_ulong,
    attributes: ?[*]types.XSetWindowAttributes,
) callconv(.C) types.Window;
pub const XDestroyWindowProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
) callconv(.C) c_int;
pub const XMapWindowProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
) callconv(.C) c_int;
pub const XUnmapWindowProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
) callconv(.C) c_int;
pub const XMoveWindowProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
    x: c_int,
    y: c_int,
) callconv(.C) c_int;
pub const XResizeWindowProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
    width: c_uint,
    height: c_uint,
) callconv(.C) c_int;
pub const XIconifyWindowProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
    screen_number: c_int,
) callconv(.C) types.Status;

// Properties
pub const XSetWMProtocolsProc = *const fn (
    display: ?*types.Display,
    window: types.Window,
    atoms: ?[*]types.Atom,
    count: c_int,
) types.Status;
pub const XChangePropertyProc = *const fn (
    display: ?*types.Display,
    w: types.Window,
    property: types.Atom,
    prop_type: types.Atom,
    format: c_int,
    mode: c_int,
    data: [*]const u8,
    nelements: c_int,
) callconv(.C) void;
pub const XDeletePropertyProc = *const fn (
    display: ?*types.Display,
    w: types.Window,
    property: types.Atom,
) callconv(.C) void;
pub const XGetWindowPropertyProc = *const fn (
    display: ?*types.Display,
    w: types.Window,
    property: types.Atom,
    long_offset: c_long,
    long_lenght: c_long,
    delete: types.Bool,
    req_type: types.Atom,
    actual_type_return: *types.Atom,
    actual_format_return: *c_int,
    nitems_return: *c_ulong,
    bytes_after_return: *c_ulong,
    prop_return: ?[*]?[*]u8,
) callconv(.C) c_int;
pub const XInternAtomProc = *const fn (
    display: ?*types.Display,
    atom_name: [*:0]const u8,
    if_exist: types.Bool,
) callconv(.C) types.Atom;

// XUtil
pub const XUniqueContextProc = XrmUniqueQuarkProc;
pub const XSaveContextProc = *const fn (
    display: ?*types.Display,
    rid: types.XID,
    context: types.XContext,
    data: types.XPointer,
) callconv(.C) c_int;
pub const XFindContextProc = *const fn (
    display: ?*types.Display,
    rid: types.XID,
    context: types.XContext,
    data_return: *types.XPointer,
) callconv(.C) c_int;
pub const XDeleteContextProc = *const fn (
    display: ?*types.Display,
    rid: types.XID,
    context: types.XContext,
) callconv(.C) c_int;

// Events
pub const XNextEventProc = *const fn (
    display: *types.Display,
    x_event: *types.XEvent,
) callconv(.C) c_int;
pub const XPendingProc = *const fn (display: *types.Display) callconv(.C) c_int;
pub const XQLengthProc = *const fn (display: *types.Display) callconv(.C) c_int;
pub const XSendEventProc = *const fn (
    display: *types.Display,
    w: types.Window,
    propagate: types.Bool,
    event_mask: c_long,
    event: *types.XEvent,
) callconv(.C) types.Status;
pub const XSyncProc = *const fn (
    display: *types.Display,
    discard: types.Bool,
) callconv(.C) void;
pub const XFlushProc = *const fn (Display: *types.Display) callconv(.C) c_int;

// Errors
pub const XSetErrorHandlerProc = *const fn (
    handler: ?*const types.XErrorHandlerFunc,
) ?*const types.XErrorHandlerFunc;

// Misc
pub const XFreeProc = *const fn (data: *anyopaque) callconv(.C) c_int;

pub const dyn_api = struct {
    pub var XOpenDisplay: XOpenDisplayProc = undefined;
    pub var XCloseDisplay: XCloseDisplayProc = undefined;
    // pub var XInitExtension: XInitExtensionProc = undefined;
    // pub var XAddExtension: XAddExtensionProc = undefined;
    // Multithreading routines.
    pub var XInitThreads: XInitThreadsProc = undefined;
    // XLockDisplay: XLockDisplayProc,
    // XUnlockDisplay: XUnlockDisplayProc,
    // Ressource Manager
    pub var XrmInitialize: XrmInitializeProc = undefined;
    pub var XResourceManagerString: XResourceManagerStringProc = undefined;
    pub var XrmGetStringDatabase: XrmGetStringDatabaseProc = undefined;
    pub var XrmDestroyDatabase: XrmDestroyDatabaseProc = undefined;
    pub var XrmGetResource: XrmGetResourceProc = undefined;
    pub var XrmUniqueQuark: XrmUniqueQuarkProc = undefined;
    // Window Management.
    pub var XCreateSimpleWindow: XCreateSimpleWindowProc = undefined;
    pub var XCreateWindow: XCreateWindowProc = undefined;
    pub var XDestroyWindow: XDestroyWindowProc = undefined;
    pub var XMapWindow: XMapWindowProc = undefined;
    pub var XUnmapWindow: XUnmapWindowProc = undefined;
    pub var XMoveWindow: XMoveWindowProc = undefined;
    pub var XResizeWindow: XResizeWindowProc = undefined;
    pub var XIconifyWindow: XIconifyWindowProc = undefined;
    // XUtil
    pub var XSaveContext: XSaveContextProc = undefined;
    pub var XFindContext: XFindContextProc = undefined;
    pub var XDeleteContext: XDeleteContextProc = undefined;
    // Events
    pub var XNextEvent: XNextEventProc = undefined;
    pub var XPending: XPendingProc = undefined;
    pub var XQLength: XQLengthProc = undefined;
    pub var XSendEvent: XSendEventProc = undefined;
    pub var XSync: XSyncProc = undefined;
    pub var XFlush: XFlushProc = undefined;
    // Properties
    pub var XSetWMProtocols: XSetWMProtocolsProc = undefined;
    pub var XChangeProperty: XChangePropertyProc = undefined;
    pub var XDeleteProperty: XDeletePropertyProc = undefined;
    pub var XGetWindowProperty: XGetWindowPropertyProc = undefined;
    pub var XInternAtom: XInternAtomProc = undefined;
    // Errors
    pub var XSetErrorHandler: XSetErrorHandlerProc = undefined;
    // Misc
    pub var XFree: XFreeProc = undefined;
};

var __libx11_module: ?*anyopaque = null;

pub fn initDynamicApi() posix.ModuleError!void {
    // Easy shortcut but require the field.name to be 0 terminated
    // since it will be passed to a c function.
    const MAX_NAME_LENGTH = 256;
    const info = @typeInfo(dyn_api);
    var field_name: [MAX_NAME_LENGTH]u8 = undefined;

    if (__libx11_module != null) {
        return;
    }

    __libx11_module = posix.loadPosixModule(defs.XORG_LIBS_NAME[defs.LIB_X11_INDEX]);
    if (__libx11_module) |m| {
        inline for (info.Struct.decls) |*d| {
            if (comptime d.name.len > MAX_NAME_LENGTH - 1) {
                @compileError("Libx11 function name is greater than the maximum buffer length");
            }
            std.mem.copyForwards(u8, &field_name, d.name);
            field_name[d.name.len] = 0;
            const symbol = posix.moduleSymbol(m, @ptrCast(&field_name)) orelse return posix.ModuleError.UndefinedSymbol;
            @field(dyn_api, d.name) = @ptrCast(symbol);
        }
    } else {
        return posix.ModuleError.NotFound;
    }
}

pub fn deinitDynamicApi() void {
    if (__libx11_module) |m| {
        posix.freePosixModule(m);
    }
}
