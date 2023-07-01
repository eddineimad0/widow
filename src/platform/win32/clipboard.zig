const std = @import("std");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const win32_system_data_exchange = zigwin32.system.data_exchange;
const win32_system_memory = zigwin32.system.memory;
const HWND = win32.HWND;

pub const ClipboardError = error{
    FailedToOpen,
    AccessDenied,
    FailedToUpdate,
    AllocationFailure,
    OwnershipDenied,
    FailedToRegisterViewer,
};

/// Copy the string contained inside the system clipboard.
/// # Note
/// This function fails if the clipboard doesn't contain a proper unicode formatted string.
/// The caller is responsible for freeing the returned string.
pub fn clipboardText(allocator: std.mem.Allocator, window_handle: HWND) ![]u8 {
    if (win32_system_data_exchange.OpenClipboard(window_handle) != 0) {
        defer _ = win32_system_data_exchange.CloseClipboard();
        // Might Fail if the data format is different than CF_UNICODETEXT.
        const handle = win32_system_data_exchange.GetClipboardData(win32.CF_UNICODETEXT);
        if (handle != null) {
            // Pointer returned by windows do not respect data types alignment.
            // we'll copy the data to an aligned ptr for this one, so we can use it with std functions.
            const buffer = @ptrCast(?[*]const u8, win32_system_memory.GlobalLock(@bitCast(isize, @ptrToInt(handle))));
            if (buffer) |wide_buffer| {
                defer _ = win32_system_memory.GlobalUnlock(@bitCast(isize, @ptrToInt(handle)));
                var buffer_size: usize = 0;
                var null_flag: u16 = 1;
                while (null_flag != 0x0000) {
                    null_flag = @intCast(u16, wide_buffer[buffer_size]) << 8 | wide_buffer[buffer_size + 1];
                    buffer_size += 2;
                }
                // no null terminator;
                var utf16_buffer = try allocator.alloc(u16, (buffer_size >> 1) - 1);
                defer allocator.free(utf16_buffer);
                var dest_buffer = @ptrCast([*]u8, utf16_buffer.ptr);
                for (0..buffer_size - 2) |i| {
                    dest_buffer[i] = wide_buffer[i];
                }
                return utils.wideToUtf8(allocator, utf16_buffer);
            }
        }
        return ClipboardError.AccessDenied;
    }
    return ClipboardError.FailedToOpen;
}

/// Paste the given `text` to the system clipboard.
pub fn setClipboardText(allocator: std.mem.Allocator, window_handle: HWND, text: []const u8) !void {
    if (win32_system_data_exchange.OpenClipboard(window_handle) == 0) {
        return ClipboardError.FailedToOpen;
    }

    if (win32_system_data_exchange.EmptyClipboard() == 0) {
        return ClipboardError.OwnershipDenied;
    }

    const wide_text = try utils.utf8ToWideZ(allocator, text);
    defer allocator.free(wide_text);
    const bytes_len = (wide_text.len + 1) << 1; // + 1 for the null terminator.
    const alloc_mem = win32_system_memory.GlobalAlloc(win32_system_memory.GMEM_MOVEABLE, bytes_len);
    if (alloc_mem == 0) {
        return ClipboardError.AllocationFailure;
    }

    var buffer = win32_system_memory.GlobalLock(alloc_mem);
    if (buffer == null) {
        return ClipboardError.AllocationFailure;
    }

    // Hack to deal with alignement BS.
    var wide_dest_ptr = @ptrCast([*]u8, buffer);
    var wide_src_ptr = @ptrCast([*]u8, wide_text.ptr);
    for (0..bytes_len) |i| {
        wide_dest_ptr[i] = wide_src_ptr[i];
    }
    _ = win32_system_memory.GlobalUnlock(alloc_mem);

    if (win32_system_data_exchange.SetClipboardData(win32.CF_UNICODETEXT, @intToPtr(*anyopaque, @bitCast(usize, alloc_mem))) == null) {
        return ClipboardError.FailedToUpdate;
    }
    _ = win32_system_data_exchange.CloseClipboard();
}

/// Register a window as clipboard viewer, so it can be notified on
/// clipboard value changes.
/// # Note
/// This api is supported by all versions of window, it's messages are nonqueued
/// and deliverd immediately by the system.
pub fn registerClipboardViewer(viewer: HWND) ClipboardError!?HWND {
    utils.clearThreadError();
    const next_viewer = win32_system_data_exchange.SetClipboardViewer(viewer);
    if (next_viewer == null) {
        if (utils.getLastError() != win32.WIN32_ERROR.NO_ERROR) {
            return ClipboardError.FailedToRegisterViewer;
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
    var internals = try Internals.init();
    defer internals.deinit(std.testing.allocator);
    try setClipboardText(std.testing.allocator, internals.helper_window, string1);
    const copied_string = try clipboardText(std.testing.allocator, internals.helper_window);
    defer std.testing.allocator.free(copied_string);
    std.debug.print("\n 1st clipboard value:{s}\n string length:{}\n", .{ copied_string, copied_string.len });
    const copied_string2 = try clipboardText(std.testing.allocator, internals.helper_window);
    defer std.testing.allocator.free(copied_string2);
    std.debug.print("\n 2nd clipboard value:{s}\n string length:{}\n", .{ copied_string2, copied_string2.len });
    try setClipboardText(std.testing.allocator, internals.helper_window, string2);
    const copied_string3 = try clipboardText(std.testing.allocator, internals.helper_window);
    defer std.testing.allocator.free(copied_string3);
    std.debug.print("\n 3rd clipboard value:{s}\n string length:{}\n", .{ copied_string3, copied_string2.len });
}
