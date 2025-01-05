//! One of the major goals of this widow is to allow cross compilation of any project that
//! depends on it, for now cross compiling from linux targeting windows is achieved thanks to zig
//! To allow cross compilation from windows targeting linux we need to stop linking against
//! X11 system library and instead load it at runtime.
const std = @import("std");
const unix = @import("common").unix;
const types = @import("types.zig");
const defs = @import("constants.zig");
const xkb = @import("extensions/xkb.zig");

pub const dyn_api = struct {
    // Functions Types:
    const XOpenDisplayProc = *const fn (display_name: ?[*:0]u8) callconv(.C) ?*types.Display;
    const XCloseDisplayProc = *const fn (display: ?*types.Display) callconv(.C) c_int;
    const XInitExtensionProc = *const fn (
        display: ?*types.Display,
        ext_name: ?[*:0]const u8,
    ) callconv(.C) ?[*]types.XExtCodes;
    const XAddExtensionProc = *const fn (display: ?*types.Display) callconv(.C) ?[*]types.XExtCodes;

    // Multithreading routines.
    const XInitThreadsProc = *const fn () callconv(.C) c_int;
    const XLockDisplayProc = *const fn (dispaly: ?*types.Display) callconv(.C) void;
    const XUnlockDisplayProc = *const fn (display: ?*types.Display) callconv(.C) void;

    // Ressource Manager
    const XrmInitializeProc = *const fn () callconv(.C) void;
    const XResourceManagerStringProc = *const fn (display: ?*types.Display) callconv(.C) ?[*:0]const u8;
    const XrmGetStringDatabaseProc = *const fn (data: ?[*:0]const u8) callconv(.C) types.XrmDatabase;
    const XrmDestroyDatabaseProc = *const fn (db: types.XrmDatabase) callconv(.C) void;
    const XrmGetResourceProc = *const fn (
        db: types.XrmDatabase,
        str_name: [*:0]const u8,
        str_class: [*:0]const u8,
        str_type_return: *?[*:0]const u8,
        value_return: *types.XrmValue,
    ) callconv(.C) types.Bool;
    const XrmUniqueQuarkProc = *const fn () callconv(.C) types.XrmQuark;

    // Window Management
    const XCreateSimpleWindowProc = *const fn (
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
    const XCreateWindowProc = *const fn (
        display: ?*types.Display,
        parent: types.Window,
        x: c_int,
        y: c_int,
        width: c_uint,
        height: c_uint,
        border_width: c_uint,
        depth: c_int,
        class: c_uint,
        visual: ?*types.Visual,
        value_mask: c_ulong,
        attributes: ?[*]types.XSetWindowAttributes,
    ) callconv(.C) types.Window;
    const XCreateColormapProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
        visual: ?*types.Visual,
        alloc: c_int,
    ) callconv(.C) types.Colormap;
    const XDestroyWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
    ) callconv(.C) c_int;
    const XMapWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
    ) callconv(.C) c_int;
    const XUnmapWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
    ) callconv(.C) c_int;
    const XMoveWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        x: c_int,
        y: c_int,
    ) callconv(.C) c_int;
    const XResizeWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        width: c_uint,
        height: c_uint,
    ) callconv(.C) c_int;
    const XMoveResizeWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        x: c_int,
        y: c_int,
        width: c_uint,
        height: c_uint,
    ) callconv(.C) c_int;
    const XIconifyWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        screen_number: c_int,
    ) callconv(.C) types.Status;
    // Properties
    const XSetWMProtocolsProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        atoms: ?[*]types.Atom,
        count: c_int,
    ) types.Status;
    const XChangePropertyProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
        property: types.Atom,
        prop_type: types.Atom,
        format: c_int,
        mode: c_int,
        data: [*]const u8,
        nelements: c_int,
    ) callconv(.C) void;
    const XDeletePropertyProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
        property: types.Atom,
    ) callconv(.C) void;
    const XGetWindowPropertyProc = *const fn (
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
    const XInternAtomProc = *const fn (
        display: ?*types.Display,
        atom_name: [*:0]const u8,
        if_exist: types.Bool,
    ) callconv(.C) types.Atom;

    // XUtil
    const XUniqueContextProc = XrmUniqueQuarkProc;
    const XSaveContextProc = *const fn (
        display: ?*types.Display,
        rid: types.XID,
        context: types.XContext,
        data: types.XPointer,
    ) callconv(.C) c_int;
    const XFindContextProc = *const fn (
        display: ?*types.Display,
        rid: types.XID,
        context: types.XContext,
        data_return: *types.XPointer,
    ) callconv(.C) c_int;
    const XDeleteContextProc = *const fn (
        display: ?*types.Display,
        rid: types.XID,
        context: types.XContext,
    ) callconv(.C) c_int;
    const XGetScreenSaverProc = *const fn (
        display: ?*types.Display,
        timout: *c_int,
        interval: *c_int,
        prefer_blanking: *c_int,
        allow_exposures: *c_int,
    ) callconv(.C) c_int;
    const XSetScreenSaverProc = *const fn (
        display: ?*types.Display,
        timout: c_int,
        interval: c_int,
        prefer_blanking: c_int,
        allow_exposures: c_int,
    ) callconv(.C) c_int;

    // Events
    const XNextEventProc = *const fn (
        display: *types.Display,
        x_event: *types.XEvent,
    ) callconv(.C) c_int;
    const XPeekEventProc = *const fn (
        display: *types.Display,
        x_event: *types.XEvent,
    ) callconv(.C) c_int;
    const XPendingProc = *const fn (display: *types.Display) callconv(.C) c_int;
    const XQLengthProc = *const fn (display: *types.Display) callconv(.C) c_int;
    const XSendEventProc = *const fn (
        display: *types.Display,
        w: types.Window,
        propagate: types.Bool,
        event_mask: c_long,
        event: *types.XEvent,
    ) callconv(.C) types.Status;
    const XSyncProc = *const fn (
        display: *types.Display,
        discard: types.Bool,
    ) callconv(.C) void;
    const XFlushProc = *const fn (display: *types.Display) callconv(.C) c_int;
    const XEventsQueuedProc = *const fn (display: ?*types.Display, mode: c_int) callconv(.C) c_int;
    const XGetEventDataProc = *const fn (display: ?*types.Display, cookie: *types.XGenericEventCookie) callconv(.C) types.Bool;
    const XFreeEventDataProc = *const fn (display: ?*types.Display, cookie: *types.XGenericEventCookie) callconv(.C) void;

    // Errors
    const XSetErrorHandlerProc = *const fn (
        handler: ?*const types.XErrorHandlerFunc,
    ) ?*const types.XErrorHandlerFunc;

    // Misc
    const XFreeProc = *const fn (data: *anyopaque) callconv(.C) c_int;
    const XAllocWMHintsProc = *const fn () callconv(.C) ?*types.XWMHints;
    const XAllocClassHintProc = *const fn () callconv(.C) ?*types.XClassHint;
    const XAllocSizeHintsProc = *const fn () callconv(.C) ?*types.XSizeHints;
    // const XAllocIconSize = *const fn () ?*XIconSize;
    // const XAllocStandardColormap = *const fn () ?*XStandardColormap;
    const XSetWMHintsProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        hints: ?[*]types.XSizeHints,
    ) callconv(.C) void;
    const XSetWMNormalHintsProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        hints: ?[*]types.XWMHints,
    ) callconv(.C) void;
    const XSetClassHintProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        hints: ?[*]types.XClassHint,
    ) callconv(.C) c_int;

    // Keyboard.
    const XDisplayKeycodesProc = *const fn (
        display: ?*types.Display,
        min_keycodes_return: *c_int,
        max_keycodes_return: *c_int,
    ) callconv(.C) c_int;

    const XGetKeyboardMappingProc = *const fn (
        display: ?*types.Display,
        first_keycode: types.KeyCode,
        keycode_count: c_int,
        keysyms_per_keycode_return: *c_int,
    ) callconv(.C) ?[*]types.KeySym;

    const XLookupStringProc = *const fn (
        event_struct: *types.XKeyEvent,
        buffer_return: ?[*:0]u8,
        bytes_buffer: c_int,
        keysym_return: ?*types.KeySym,
        status_in_out: ?*types.XComposeStatus,
    ) callconv(.C) c_int;

    const XQueryPointerProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
        root: ?*types.Window,
        child_ret: ?*types.Window,
        root_x_ret: ?*c_int,
        root_y_ret: ?*c_int,
        win_x_ret: ?*c_int,
        win_y_ret: ?*c_int,
        mask_ret: ?*c_uint,
    ) callconv(.C) types.Bool;

    const XWarpPointerProc = *const fn (
        display: ?*types.Display,
        src_w: types.Window,
        dest_w: types.Window,
        src_x: c_int,
        src_y: c_int,
        src_width: c_uint,
        src_height: c_uint,
        dest_x: c_int,
        dest_y: c_int,
    ) callconv(.C) c_int;

    const XGetWindowAttributesProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
        attribs_return: *types.XWindowAttributes,
    ) callconv(.C) types.Status;

    const XCreateFontCursorProc = *const fn (
        display: ?*types.Display,
        shape: c_uint,
    ) callconv(.C) types.Cursor;

    const XFreeCursorProc = *const fn (
        display: ?*types.Display,
        cursor: types.Cursor,
    ) callconv(.C) c_int;

    const XDefineCursorProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
        cursor: types.Cursor,
    ) callconv(.C) c_int;

    const XUndefineCursorProc = *const fn (
        display: ?*types.Display,
        w: types.Window,
    ) callconv(.C) c_int;

    const XGrabPointerProc = *const fn (
        display: ?*types.Display,
        grab_window: types.Window,
        owner_event: types.Bool,
        event_mask: c_uint,
        pointer_mode: c_int,
        keyboard_mode: c_int,
        confine_to: types.Window,
        cursor: types.Cursor,
        time: types.Time,
    ) callconv(.C) c_int;

    const XUngrabPointerProc = *const fn (
        display: ?*types.Display,
        time: types.Time,
    ) callconv(.C) void;

    const XRaiseWindowProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
    ) callconv(.C) void;

    const XSetInputFocusProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        revert_to: c_int,
        time: types.Time,
    ) callconv(.C) void;

    const XGetWMNormalHintsProc = *const fn (
        display: ?*types.Display,
        window: types.Window,
        hints_return: *types.XSizeHints,
        supplied_return: *c_long,
    ) callconv(.C) types.Status;

    const XConvertSelectionProc = *const fn (
        display: ?*types.Display,
        selection: types.Atom,
        target: types.Atom,
        property: types.Atom,
        requestor: types.Window,
        time: types.Time,
    ) callconv(.C) void;

    const XTranslateCoordinatesProc = *const fn (
        display: ?*types.Display,
        src_w: types.Window,
        dest_w: types.Window,
        src_x: c_int,
        src_y: c_int,
        dest_x: *c_int,
        dest_y: *c_int,
        child_ret: *types.Window,
    ) callconv(.C) types.Bool;

    const XQueryExtensionProc = *const fn (
        display: ?*types.Display,
        name: [*:0]const u8,
        major_opcode: *c_int,
        first_event_code: *c_int,
        first_error_code: *c_int,
    ) callconv(.C) types.Bool;

    // function pointers
    pub var XOpenDisplay: XOpenDisplayProc = undefined;
    pub var XCloseDisplay: XCloseDisplayProc = undefined;

    // Multithreading routines.
    pub var XInitThreads: XInitThreadsProc = undefined;

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
    pub var XCreateColormap: XCreateColormapProc = undefined;
    pub var XDestroyWindow: XDestroyWindowProc = undefined;
    pub var XMapWindow: XMapWindowProc = undefined;
    pub var XUnmapWindow: XUnmapWindowProc = undefined;
    pub var XMoveWindow: XMoveWindowProc = undefined;
    pub var XMoveResizeWindow: XMoveResizeWindowProc = undefined;
    pub var XResizeWindow: XResizeWindowProc = undefined;
    pub var XIconifyWindow: XIconifyWindowProc = undefined;

    // XUtil
    pub var XSaveContext: XSaveContextProc = undefined;
    pub var XFindContext: XFindContextProc = undefined;
    pub var XDeleteContext: XDeleteContextProc = undefined;
    pub var XGetScreenSaver: XGetScreenSaverProc = undefined;
    pub var XSetScreenSaver: XSetScreenSaverProc = undefined;

    // Events
    pub var XNextEvent: XNextEventProc = undefined;
    pub var XPeekEvent: XPeekEventProc = undefined;
    pub var XPending: XPendingProc = undefined;
    pub var XQLength: XQLengthProc = undefined;
    pub var XSendEvent: XSendEventProc = undefined;
    pub var XSync: XSyncProc = undefined;
    pub var XFlush: XFlushProc = undefined;
    pub var XEventsQueued: XEventsQueuedProc = undefined;
    pub var XGetEventData: XGetEventDataProc = undefined;
    pub var XFreeEventData: XFreeEventDataProc = undefined;

    // Properties
    pub var XSetWMProtocols: XSetWMProtocolsProc = undefined;
    pub var XChangeProperty: XChangePropertyProc = undefined;
    pub var XDeleteProperty: XDeletePropertyProc = undefined;
    pub var XGetWindowProperty: XGetWindowPropertyProc = undefined;
    pub var XGetWindowAttributes: XGetWindowAttributesProc = undefined;
    pub var XInternAtom: XInternAtomProc = undefined;

    // Errors
    pub var XSetErrorHandler: XSetErrorHandlerProc = undefined;

    // Misc
    pub var XFree: XFreeProc = undefined;
    pub var XAllocWMHints: XAllocWMHintsProc = undefined;
    pub var XAllocSizeHints: XAllocSizeHintsProc = undefined;
    pub var XAllocClassHint: XAllocClassHintProc = undefined;
    pub var XSetWMHints: XSetWMHintsProc = undefined;
    pub var XSetWMNormalHints: XSetWMNormalHintsProc = undefined;
    pub var XSetClassHint: XSetClassHintProc = undefined;

    // xkb
    pub var XkbLibraryVersion: xkb.XkbLibraryVersionProc = undefined;
    pub var XkbQueryExtension: xkb.XkbQueryExtensionProc = undefined;
    pub var XkbGetDetectableAutoRepeat: xkb.XkbGetDetectableAutorepeatProc = undefined;
    pub var XkbSetDetectableAutoRepeat: xkb.XkbSetDetectableAutorepeatProc = undefined;
    pub var XkbGetNames: xkb.XkbGetNamesProc = undefined;
    pub var XkbFreeNames: xkb.XkbFreeNamesProc = undefined;
    pub var XkbGetState: xkb.XkbGetStateProc = undefined;
    pub var XkbGetMap: xkb.XkbGetMapProc = undefined;
    pub var XkbFreeClientMap: xkb.XkbFreeClientMapProc = undefined;
    pub var XkbKeycodeToKeysym: xkb.XkbKeycodeToKeysymProc = undefined;
    pub var XkbAllocKeyboard: xkb.XkbAllocKeyboardProc = undefined;
    pub var XkbFreeKeyboard: xkb.XkbFreeKeyboardProc = undefined;
    pub var XkbSelectEventDetails: xkb.XkbSelectEventDetailsProc = undefined;
    pub var XkbGetKeyboard: xkb.XkbGetKeyboardProc = undefined;

    // keyboard
    pub var XDisplayKeycodes: XDisplayKeycodesProc = undefined;
    pub var XGetKeyboardMapping: XGetKeyboardMappingProc = undefined;
    pub var XLookupString: XLookupStringProc = undefined;
    pub var XQueryPointer: XQueryPointerProc = undefined;
    pub var XWarpPointer: XWarpPointerProc = undefined;

    // cursor
    pub var XCreateFontCursor: XCreateFontCursorProc = undefined;
    pub var XFreeCursor: XFreeCursorProc = undefined;
    pub var XDefineCursor: XDefineCursorProc = undefined;
    pub var XUndefineCursor: XUndefineCursorProc = undefined;
    pub var XGrabPointer: XGrabPointerProc = undefined;
    pub var XUngrabPointer: XUngrabPointerProc = undefined;

    pub var XRaiseWindow: XRaiseWindowProc = undefined;
    pub var XSetInputFocus: XSetInputFocusProc = undefined;
    pub var XGetWMNormalHints: XGetWMNormalHintsProc = undefined;
    pub var XConvertSelection: XConvertSelectionProc = undefined;

    pub var XQueryExtension: XQueryExtensionProc = undefined;

    pub var XTranslateCoordinates: XTranslateCoordinatesProc = undefined;
};

var __libx11_module: ?*anyopaque = null;

pub fn initDynamicApi() unix.ModuleError!void {
    // Easy shortcut but require the field.name to be 0 terminated
    // since it will be passed to a c function.
    const MAX_NAME_LENGTH = 256;
    const info = @typeInfo(dyn_api);
    var field_name: [MAX_NAME_LENGTH]u8 = undefined;

    if (__libx11_module != null) {
        return;
    }

    __libx11_module = unix.loadPosixModule(
        defs.XORG_LIBS_NAME[defs.LIB_X11_SONAME_INDEX],
    );
    if (__libx11_module) |m| {
        inline for (info.Struct.decls) |*d| {
            if (comptime d.name.len > MAX_NAME_LENGTH - 1) {
                @compileError(
                    "Libx11 function name is greater than the maximum buffer length",
                );
            }
            std.mem.copyForwards(u8, &field_name, d.name);
            field_name[d.name.len] = 0;
            const symbol = unix.moduleSymbol(m, @ptrCast(&field_name)) orelse
                return unix.ModuleError.UndefinedSymbol;
            @field(dyn_api, d.name) = @ptrCast(symbol);
        }
    } else {
        return unix.ModuleError.NotFound;
    }
}
