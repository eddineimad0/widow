const std = @import("std");
const win32_gfx = @import("win32api/graphics.zig");

const dbg = std.debug;

pub fn showMessageDialog(message: [:0]const u8) void {
    const result = win32_gfx.MessageBoxA(
        null,
        message,
        "CAPTION",
        win32_gfx.MB_OK | win32_gfx.MB_ICONINFORMATION | win32_gfx.MB_TASKMODAL | win32_gfx.MB_TOPMOST,
    );
    dbg.assert(result != 0);
}
