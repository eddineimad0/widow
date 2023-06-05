const std = @import("std");
const winapi = @import("win32");
const win32_system_data_exchange = winapi.system.data_exchange;
const win32_system_memory = winapi.system.memory;
const utf8ToWide = @import("utils.zig").utf8ToWide;
const wideToUtf8 = @import("utils.zig").wideToUtf8;
const HWND = winapi.foundation.HWND;
const CF_UNICODETEXT: u32 = 13;

pub const ClipboardError = error{
    FailedToOpenClipboard,
    FailedToAccessClipboardData,
    FailedToWriteToClipboard,
    FailedToAllocateClipboardMemory,
    FailedToGainClipboardOwnership,
};

/// Copy the string contained inside the system clipboard.
/// # Note
/// This function fails if the clipboard doesn't contain a proper unicode formatted string.
/// The caller is responsible for freeing the returned string.
pub fn clipboardText(allocator: std.mem.Allocator, window_handle: HWND) ![]u8 {
    if (win32_system_data_exchange.OpenClipboard(window_handle) != 0) {
        defer _ = win32_system_data_exchange.CloseClipboard();
        const handle = win32_system_data_exchange.GetClipboardData(CF_UNICODETEXT);
        if (handle != null) {
            // Pointers returned by windows do not respect data types alignment.
            // we'll fix the alignment for this one, so we can use it with our functions.
            const buffer = @ptrCast(?[*]const u8, win32_system_memory.GlobalLock(@bitCast(isize, @ptrToInt(handle))));
            if (buffer) |wide_buffer| {
                defer _ = win32_system_memory.GlobalUnlock(@bitCast(isize, @ptrToInt(handle)));
                var buffer_size: usize = 0;
                var null_flag: u16 = 1;
                while (null_flag != 0x0000) {
                    null_flag = @intCast(u16, wide_buffer[buffer_size]) << 8 | wide_buffer[buffer_size + 1];
                    buffer_size += 2;
                }
                var utf16_buffer = try allocator.alloc(u16, (buffer_size >> 1));
                defer allocator.free(utf16_buffer);
                var dest_buffer = @ptrCast([*]u8, utf16_buffer.ptr);
                for (0..buffer_size) |i| {
                    dest_buffer[i] = wide_buffer[i];
                }
                return wideToUtf8(allocator, utf16_buffer);
            }
        }
        return ClipboardError.FailedToAccessClipboardData;
    }
    return ClipboardError.FailedToOpenClipboard;
}

/// Paste the given `text` to the system clipboard.
pub fn setClipboardText(allocator: std.mem.Allocator, window_handle: HWND, text: []const u8) !void {
    if (win32_system_data_exchange.OpenClipboard(window_handle) == 0) {
        return ClipboardError.FailedToOpenClipboard;
    }

    if (win32_system_data_exchange.EmptyClipboard() == 0) {
        return ClipboardError.FailedToGainClipboardOwnership;
    }

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
    var wide_dest_ptr = @ptrCast([*]u8, buffer);
    var wide_src_ptr = @ptrCast([*]u8, wide_text.ptr);
    for (0..bytes_len) |i| {
        wide_dest_ptr[i] = wide_src_ptr[i];
    }
    _ = win32_system_memory.GlobalUnlock(alloc_mem);

    if (win32_system_data_exchange.SetClipboardData(CF_UNICODETEXT, @intToPtr(*anyopaque, @bitCast(usize, alloc_mem))) == null) {
        return ClipboardError.FailedToWriteToClipboard;
    }
    _ = win32_system_data_exchange.CloseClipboard();
}

test "clipboard_tests" {
    const Internals = @import("internals.zig").Internals;
    const string = "Clipboard Test String 👌.";
    var internals = try Internals.create(std.testing.allocator);
    defer internals.destroy(std.testing.allocator);
    try setClipboardText(std.testing.allocator, internals.win32.handles.helper_window, string);
    const copied_string = try clipboardText(std.testing.allocator, internals.win32.handles.helper_window);
    defer std.testing.allocator.free(copied_string);
    std.debug.print("\nclipboard value:{s}\n string length:{}\n", .{ copied_string, copied_string.len });
}
