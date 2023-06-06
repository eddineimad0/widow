const std = @import("std");
const winapi = @import("win32");
const utils = @import("utils.zig");
const win32_system_data_exchange = winapi.system.data_exchange;
const win32_system_memory = winapi.system.memory;
const HWND = winapi.foundation.HWND;
const CF_UNICODETEXT: u32 = 13;

pub const ClipboardError = error{
    FailedToOpenClipboard,
    FailedToAccessClipboardData,
    FailedToWriteToClipboard,
    FailedToAllocateClipboardMemory,
    FailedToGainClipboardOwnership,
    FailedToRegisterClipboardViewer,
};

/// Copy the string contained inside the system clipboard.
/// # Note
/// This function fails if the clipboard doesn't contain a proper unicode formatted string.
/// The caller is responsible for freeing the returned string.
pub fn clipboardText(allocator: std.mem.Allocator, window_handle: HWND) ClipboardError![]u8 {
    if (win32_system_data_exchange.OpenClipboard(window_handle) != 0) {
        defer _ = win32_system_data_exchange.CloseClipboard();
        const handle = win32_system_data_exchange.GetClipboardData(CF_UNICODETEXT);
        if (handle != null) {
            // Pointer returned by windows do not respect data types alignment.
            // we'll copy the data to an aligned ptr for this one, so we can use it with std function.
            const buffer = @ptrCast(?[*]const u8, win32_system_memory.GlobalLock(@bitCast(isize, @ptrToInt(handle))));
            if (buffer) |wide_buffer| {
                defer _ = win32_system_memory.GlobalUnlock(@bitCast(isize, @ptrToInt(handle)));
                var buffer_size: usize = 0;
                var null_flag: u16 = 1;
                while (null_flag != 0x0000) {
                    null_flag = @intCast(u16, wide_buffer[buffer_size]) << 8 | wide_buffer[buffer_size + 1];
                    buffer_size += 2;
                }
                var utf16_buffer = try allocator.alloc(u16, (buffer_size >> 1) - 1); // no null terminator;
                defer allocator.free(utf16_buffer);
                var dest_buffer = @ptrCast([*]u8, utf16_buffer.ptr);
                for (0..buffer_size - 2) |i| {
                    dest_buffer[i] = wide_buffer[i];
                }
                return utils.wideToUtf8(allocator, utf16_buffer);
            }
        }
        return ClipboardError.FailedToAccessClipboardData;
    }
    return ClipboardError.FailedToOpenClipboard;
}

/// Paste the given `text` to the system clipboard.
pub fn setClipboardText(allocator: std.mem.Allocator, window_handle: HWND, text: []const u8) ClipboardError!void {
    if (win32_system_data_exchange.OpenClipboard(window_handle) == 0) {
        return ClipboardError.FailedToOpenClipboard;
    }

    if (win32_system_data_exchange.EmptyClipboard() == 0) {
        return ClipboardError.FailedToGainClipboardOwnership;
    }

    const wide_text = try utils.utf8ToWide(allocator, text);
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

/// Register a window as clipboard viewer, so it can be notified on
/// clipboard value changes.
/// # Notes
/// This api is supported by all versions of window, it's messages are nonqueued
/// and deliverd immediately by the system.
pub fn registerClipboardViewer(viewer: HWND) ClipboardError!?HWND {
    utils.clearThreadError();
    const next_viewer = win32_system_data_exchange.SetClipboardViewer(viewer);
    if (next_viewer == null) {
        if (utils.getLastError() != 0) {
            return ClipboardError.FailedToRegisterClipboardViewer;
        }
    }
    return next_viewer;
}

/// Unsubscribe from clipboard viewer list.
pub inline fn unregisterClipboardViewer(viewer: HWND, next_viewer: ?HWND) void {
    _ = win32_system_data_exchange.ChangeClipboardChain(viewer, next_viewer);
}

test "clipboard_tests" {
    const Internals = @import("internals.zig").Internals;
    const string1 = "Clipboard Test String👌.";
    const string2 = "Another Clipboard Test String👌.";
    var internals = try Internals.create(std.testing.allocator);
    defer internals.destroy(std.testing.allocator);
    try setClipboardText(std.testing.allocator, internals.win32.handles.helper_window, string1);
    const copied_string = try clipboardText(std.testing.allocator, internals.win32.handles.helper_window);
    defer std.testing.allocator.free(copied_string);
    std.debug.print("\n 1st clipboard value:{s}\n string length:{}\n", .{ copied_string, copied_string.len });
    const copied_string2 = try clipboardText(std.testing.allocator, internals.win32.handles.helper_window);
    defer std.testing.allocator.free(copied_string2);
    std.debug.print("\n 2nd clipboard value:{s}\n string length:{}\n", .{ copied_string2, copied_string2.len });
    try setClipboardText(std.testing.allocator, internals.win32.handles.helper_window, string2);
    const copied_string3 = try clipboardText(std.testing.allocator, internals.win32.handles.helper_window);
    defer std.testing.allocator.free(copied_string3);
    std.debug.print("\n 3rd clipboard value:{s}\n string length:{}\n", .{ copied_string3, copied_string2.len });
}
