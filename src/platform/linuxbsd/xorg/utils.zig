//! This file contains helper function to use on the linux platforms
const std = @import("std");
const common = @import("common");
const libx11 = @import("x11/xlib.zig");
const mem = std.mem;
const debug = std.debug;
const math = std.math;

const maxInt = math.maxInt;
const Rect = common.geometry.Rect;

pub const DEFAULT_SCREEN_DPI: f32 = @as(f32, 96);

pub inline fn strNCpy(
    noalias dst: [*]u8,
    noalias src: [*:0]const u8,
    count: usize,
) void {
    if (common.IS_DEBUG_BUILD) {
        const len = std.mem.len(src);
        debug.assert(len >= count);
    }

    for (0..count) |i| {
        dst[i] = src[i];
    }
}

/// returns the length of a null terminated string.
pub inline fn strZLen(src: [*:0]const u8) usize {
    return std.mem.len(src);
}

/// returns true if both strings are equals.
pub inline fn strZEquals(
    noalias a: [*:0]const u8,
    noalias b: [*:0]const u8,
) bool {
    return (std.mem.orderZ(u8, a, b) == std.math.Order.eq);
}

/// Takes 2 many-items-pointers and compares the first `n` items
/// the caller should make sure that n isn't outside the pointers bounds.
pub inline fn bytesNCmp(
    noalias a: [*]const u8,
    noalias b: [*]const u8,
    n: usize,
) bool {
    for (0..n) |i| {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

pub const WindowPropError = error{
    BadPropType,
    PropNotFound,
};

pub fn x11WindowProperty(
    display: *libx11.Display,
    w: libx11.Window,
    property: libx11.Atom,
    prop_type: libx11.Atom,
    value: ?[*]?[*]u8,
) WindowPropError!u32 {
    var actual_type: libx11.Atom = undefined;
    var actual_format: c_int = undefined;
    var nitems: c_ulong = 0;
    var bytes_after: c_ulong = undefined;
    const result = libx11.XGetWindowProperty(
        display,
        w,
        property,
        0, // offset into the data
        maxInt(c_long), // expected length of the data
        libx11.False, // don't delete the property.
        prop_type, // expected property type.
        &actual_type,
        &actual_format,
        &nitems,
        &bytes_after,
        value,
    );

    if (result != libx11.Success) {
        if (actual_type != libx11.None and actual_type != prop_type) {
            return WindowPropError.BadPropType;
        }
        return WindowPropError.PropNotFound;
    }
    // make sure no bytes are left behind.
    debug.assert(bytes_after == 0);
    return @intCast(nitems);
}

/// Returns the state of the Key Modifiers for the current event,
/// by decoding the state field.
pub fn decodeKeyMods(state: c_uint) common.keyboard_mouse.KeyModifiers {
    return .{
        .shift = ((state & libx11.ShiftMask != 0)),
        .ctrl = ((state & libx11.ControlMask != 0)),
        .alt = ((state & libx11.Mod1Mask != 0)),
        .num_lock = ((state & libx11.Mod2Mask != 0)),
        .meta = ((state & libx11.Mod4Mask != 0)),
        .caps_lock = ((state & libx11.LockMask != 0)),
    };
}

pub fn fixKeyMods(
    mods: *common.keyboard_mouse.KeyModifiers,
    keycode: common.keyboard_mouse.KeyCode,
    key_state: common.keyboard_mouse.KeyState,
) void {
    // INFO:
    // Whenever a modifier key is pressed it's bit in the modifiers state
    // won't be set when the event is reported by x11 and when it's released
    // it's bit will still be set in the modifiers state that we receieve from
    // the event it's like some kind of lag, this differs from the behaviour
    // found on windows in order to have matching behaviour on both platforms
    // we check the keycode and set the flags accordingly.
    if (key_state == .Pressed) {
        mods.shift = (mods.shift or keycode == .Shift);
        mods.ctrl = (mods.ctrl or keycode == .Control);
        mods.alt = (mods.alt or keycode == .Alt);
        mods.meta = (mods.meta or keycode == .Meta);
    } else {
        mods.shift = (mods.shift and keycode != .Shift);
        mods.ctrl = (mods.ctrl and keycode != .Control);
        mods.alt = (mods.alt and keycode != .Alt);
        mods.meta = (mods.meta and keycode != .Meta);
    }
}

pub fn parseDroppedFilesURI(
    data: [:0]const u8,
    output: *std.ArrayList([]const u8),
) mem.Allocator.Error!void {
    try output.ensureTotalCapacity(4);
    var iter = mem.tokenizeSequence(u8, data, "\r\n");
    while (iter.next()) |tok| {
        if (tok[0] == '#') {
            continue;
        }

        var start: usize = 0;
        if (mem.eql(u8, tok[0..7], "file://")) {
            start = 7;
        }

        try output.append(tok[start..]);
    }
}

/// returns the ratio of overlap between the display area and the window area.
/// if the window and the display don't overlap it returns 0 and if the window is fully contained
/// in the display it returns 1.0
pub fn getDisplayOverlapRatio(display_area: *const Rect, window_area: *const Rect) f32 {
    const overlap_top_left = common.geometry.Point2D{
        .x = @max(display_area.top_left.x, window_area.top_left.x),
        .y = @max(display_area.top_left.y, window_area.top_left.y),
    };
    const overlap_bottom_right = common.geometry.Point2D{
        .x = @min(display_area.top_left.x + display_area.size.width, window_area.top_left.x + window_area.size.width),
        .y = @min(display_area.top_left.y + display_area.size.height, window_area.top_left.y + window_area.size.height),
    };
    var overlap_ratio: f32 = 0.0;
    const width: i32, const height: i32 = .{
        overlap_bottom_right.x - overlap_top_left.x,
        overlap_bottom_right.y - overlap_top_left.y,
    };
    if (width > 0 and height > 0) {
        const overlap_area = width * height;
        const w_area = window_area.size.width * window_area.size.height;
        overlap_ratio = @as(f32, @floatFromInt(overlap_area)) / @as(f32, @floatFromInt(w_area));
    }
    debug.assert(overlap_ratio >= 0.0 - math.floatEps(f32) and overlap_ratio <= 1.0 + math.floatEps(f32));
    return overlap_ratio;
}

test "dislay_window_intersection" {
    const testing = std.testing;

    const display_area = Rect.init(0, 0, 1920, 1080);
    const window_area_1 = Rect.init(0, 0, 1920, 1080);
    const window_area_2 = Rect.init(400, 400, 800, 600);
    const window_area_3 = Rect.init(-200, -200, 800, 600);
    const window_area_4 = Rect.init(-200, 800, 800, 600);
    const window_area_5 = Rect.init(1200, 800, 800, 600);
    const window_area_6 = Rect.init(1200, -200, 800, 600);

    try testing.expect(getDisplayOverlapRatio(&display_area, &window_area_1) == 1.0);
    try testing.expect(getDisplayOverlapRatio(&display_area, &window_area_2) == 1.0);
    try testing.expect(getDisplayOverlapRatio(&display_area, &window_area_3) > 0.4);
    try testing.expect(getDisplayOverlapRatio(&display_area, &window_area_4) > 0.0);
    try testing.expect(getDisplayOverlapRatio(&display_area, &window_area_5) > 0.0);
    try testing.expect(getDisplayOverlapRatio(&display_area, &window_area_6) > 0.0);

    const out_window_area_1 = Rect.init(400, -800, 800, 600);
    const out_window_area_2 = Rect.init(-1000, 400, 800, 600);
    const out_window_area_3 = Rect.init(400, 1200, 800, 600);
    const out_window_area_4 = Rect.init(2000, 400, 800, 600);
    try testing.expectApproxEqAbs(
        getDisplayOverlapRatio(&display_area, &out_window_area_1),
        0.0,
        math.floatEps(f32),
    );
    try testing.expectApproxEqAbs(
        getDisplayOverlapRatio(&display_area, &out_window_area_2),
        0.0,
        math.floatEps(f32),
    );
    try testing.expectApproxEqAbs(
        getDisplayOverlapRatio(&display_area, &out_window_area_3),
        0.0,
        math.floatEps(f32),
    );
    try testing.expectApproxEqAbs(
        getDisplayOverlapRatio(&display_area, &out_window_area_4),
        0.0,
        math.floatEps(f32),
    );
}
