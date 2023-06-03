const std = @import("std");
const winapi = @import("win32");
const win32_system_data_exchange = winapi.system.data_exchange;
const win32_system_memory = winapi.system.memory;
const win32_globalization = winapi.globalization;
const Internals = @import("internals.zig").Internals;
const utf8ToWide = @import("utils.zig").utf8ToWide;
const HWND = winapi.foundation.HWND;
const CF_UNICODETEXT: u32 = 13;

pub const ClipboardError = error{
    FailedToCopyClipboardText,
    FailedToOpenClipboard,
    FailedToAccessClipboardData,
    FailedToWriteToClipboard,
    FailedToAllocateClipboardMemory,
};

/// Copy the string contained inside the system clipboard.
/// # Note
/// This function fails if the clipboard doesn't contain a proper unicode formatted string.
/// The caller is responsible for freeing the returned string.
pub fn clipboardText(allocator: std.mem.Allocator, window_handle: HWND) ![:0]u8 {
    if (win32_system_data_exchange.OpenClipboard(window_handle) != 0) {
        defer _ = win32_system_data_exchange.CloseClipboard();
        const handle = win32_system_data_exchange.GetClipboardData(CF_UNICODETEXT);
        if (handle != null) {
            const buffer = @ptrCast(?[*:0]align(1) const u16, win32_system_memory.GlobalLock(@bitCast(isize, @ptrToInt(handle))));
            if (buffer) |wide_buffer| {
                defer _ = win32_system_memory.GlobalUnlock(@bitCast(isize, @ptrToInt(handle)));
                var vec_size = win32_globalization.WideCharToMultiByte(
                    win32_globalization.CP_UTF8,
                    0,
                    wide_buffer,
                    -1,
                    null,
                    0,
                    null,
                    null,
                );
                if (vec_size > 0) {
                    var utf8_buffer = try allocator.allocSentinel(u8, @intCast(usize, vec_size - 1), 0);
                    if (win32_globalization.WideCharToMultiByte(
                        win32_globalization.CP_UTF8,
                        0,
                        wide_buffer,
                        -1,
                        @ptrCast([*:0]u8, utf8_buffer.ptr),
                        vec_size,
                        null,
                        null,
                    ) != 0) {
                        return utf8_buffer;
                    } else {
                        // Error
                        allocator.free(utf8_buffer);
                    }
                }
                return ClipboardError.FailedToCopyClipboardText;
            }
        }
        return ClipboardError.FailedToAccessClipboardData;
    }
    return ClipboardError.FailedToOpenClipboard;
}

/// Paste the given `text` to the system clipboard.
pub fn setClipboardText(allocator: std.mem.Allocator, window_handle: HWND, text: []const u8) !void {
    const wide_text = try utf8ToWide(allocator, text);
    defer allocator.free(wide_text);
    const bytes_len = (wide_text.len + 1) << 1; // + 1 for the null terminator.
    const alloc_mem = win32_system_memory.GlobalAlloc(win32_system_memory.GMEM_MOVEABLE, bytes_len);
    if (alloc_mem == 0) {
        return ClipboardError.FailedToAllocateClipboardMemory;
    }

    var buffer = win32_system_memory.GlobalLock(alloc_mem);
    if (buffer == null) {
        return ClipboardError.FailedToAllocateClipboardMemory;
    }
    // Hack to deal with alignement BS.
    var wide_dest: []u8 = undefined;
    wide_dest.ptr = @ptrCast([*:0]u8, buffer);
    wide_dest.len = bytes_len;
    var wide_src: []u8 = undefined;
    wide_src.ptr = @ptrCast([*:0]u8, wide_text.ptr);
    wide_src.len = bytes_len;
    std.mem.copy(u8, wide_dest, wide_src);
    _ = win32_system_memory.GlobalUnlock(alloc_mem);

    if (win32_system_data_exchange.OpenClipboard(window_handle) == 0) {
        return ClipboardError.FailedToOpenClipboard;
    }
    _ = win32_system_data_exchange.EmptyClipboard();
    if (win32_system_data_exchange.SetClipboardData(CF_UNICODETEXT, @intToPtr(*anyopaque, @bitCast(usize, alloc_mem))) == null) {
        return ClipboardError.FailedToWriteToClipboard;
    }
    _ = win32_system_data_exchange.CloseClipboard();
}

test "clipboard_tests" {
    const string = "Clipboard.Test.String.";
    var internals = try Internals.create(std.testing.allocator);
    defer internals.destroy(std.testing.allocator);
    try setClipboardText(std.testing.allocator, internals.win32.handles.helper_window, string);
    const copied_string = try clipboardText(std.testing.allocator, internals.win32.handles.helper_window);
    defer std.testing.allocator.free(copied_string);
    std.debug.print("clipboard value:{s}\n string length:{}\n", .{ copied_string, copied_string.len });
}
