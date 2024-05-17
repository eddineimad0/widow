const std = @import("std");
const zigwin32 = @import("zigwin32");
const win32 = @import("win32_defs.zig");
const utils = @import("utils.zig");
const mem = std.mem;
const sys_data_exchg = zigwin32.system.data_exchange;
const sys_mem = zigwin32.system.memory;
const HWND = win32.HWND;

pub const Clipboard = struct {
    updated: bool, // So we can cache the clipboard value until it changes.
    next_viewer: ?win32.HWND, // we're using the old api to watch the clipboard.
    value_cache: ?[]u8,
    const Self = @This();
    pub fn init() Self {
        return .{
            .updated = false,
            .next_viewer = null,
            .value_cache = null,
        };
    }
};

pub const ClipboardError = error{
    AccessDenied, // Couldn't gain access to the clipboard data.
    BadDataFormat, // Clipboard data doesn't meet ther required format.
    OutOfMem, // Couldn't allocate system memory
    CopyFailed, // Failed to write to the clipboard
    OwnershipDenied, // Couldn't gain ownership of the clipboard (required before we can write to it)
    SubscriptionFailed, //Couldn't add the window to the viewer chain.
};

/// Returns the string contained inside the system clipboard.
/// # Parameters
/// `allocator`: used when to allocate memory for the clipboard data.
/// `window_handle`: used to gain access(ownership) of the clipboard.
/// # Notes
/// This function fails if the clipboard doesn't contain a proper unicode
/// formatted string. The caller is responsible for freeing the returned
/// string.
pub fn clipboardText(allocator: mem.Allocator, window_handle: HWND) ![]u8 {
    if (sys_data_exchg.OpenClipboard(window_handle) == win32.FALSE) {
        return ClipboardError.AccessDenied;
    }

    defer _ = sys_data_exchg.CloseClipboard();

    // Might Fail if the data in the clipboard has different format.
    const handle = sys_data_exchg.GetClipboardData(win32.CF_UNICODETEXT);
    if (handle) |h| {
        // The pointer returned by windows is point to utf-16 data however
        // on x86 platform they do not respect data types alignment.
        // since zig is strict about alignment we'll copy the data to an
        // aligned memory block so we can use it with std library.
        // TODO: does windows respect alignment on ARM platform ?
        const buffer: ?[*]const u8 = @ptrCast(
            sys_mem.GlobalLock(@bitCast(@intFromPtr(h))),
        );
        if (buffer) |b| {
            defer _ = sys_mem.GlobalUnlock(
                @bitCast(@intFromPtr(h)),
            );
            var buffer_size: usize = 0;
            var null_flag: u16 = 1;
            while (null_flag != 0x0000) {
                const upper_byte: u16 = b[buffer_size];
                null_flag = upper_byte << 8 | b[buffer_size + 1];
                buffer_size += 2;
            }
            // allocate with no null terminator;
            const aligned_buf = try allocator.alloc(u16, (buffer_size >> 1) - 1);
            defer allocator.free(aligned_buf);
            var dest_buffer: [*]u8 = @ptrCast(aligned_buf.ptr);
            for (0..buffer_size - 2) |i| {
                dest_buffer[i] = b[i];
            }
            return utils.wideToUtf8(allocator, aligned_buf);
        } else {
            return ClipboardError.AccessDenied;
        }
    }
    return ClipboardError.BadDataFormat;
}

/// Writes the given `text` to the system clipboard.
/// # Parameters
/// `allocator`: used when to allocate memory when utf16-encoding the clipboard
/// data.
/// `window_handle`: used to gain access to the clipboard.
/// `text`: the string slice to copy.
pub fn setClipboardText(
    allocator: mem.Allocator,
    window_handle: HWND,
    text: []const u8,
) !void {
    if (sys_data_exchg.OpenClipboard(window_handle) == win32.FALSE) {
        return ClipboardError.AccessDenied;
    }
    defer _ = sys_data_exchg.CloseClipboard();

    if (sys_data_exchg.EmptyClipboard() == win32.FALSE) {
        return ClipboardError.OwnershipDenied;
    }

    const wide_text = try utils.utf8ToWideZ(allocator, text);
    defer allocator.free(wide_text);

    const bytes_len = (wide_text.len + 1) << 1; // + 1 for the null terminator.
    const alloc_mem = sys_mem.GlobalAlloc(sys_mem.GMEM_MOVEABLE, bytes_len);
    if (alloc_mem == 0) {
        return ClipboardError.OutOfMem;
    }

    const buffer = sys_mem.GlobalLock(alloc_mem);
    if (buffer) |b| {
        // Hack to deal with alignement BS.
        var wide_dest_ptr: [*]u8 = @ptrCast(b);
        const wide_src_ptr: [*]u8 = @ptrCast(wide_text.ptr);
        for (0..bytes_len) |i| {
            wide_dest_ptr[i] = wide_src_ptr[i];
        }
        _ = sys_mem.GlobalUnlock(alloc_mem);
    } else {
        return ClipboardError.CopyFailed;
    }

    const ualloc_mem: usize = @bitCast(alloc_mem);
    if (sys_data_exchg.SetClipboardData(
        win32.CF_UNICODETEXT,
        @ptrFromInt(ualloc_mem),
    ) == null) {
        return ClipboardError.CopyFailed;
    }
}

/// Register a window as clipboard viewer, so it can be notified on
/// clipboard value changes.
/// On success it returns a handle to the window that's next
/// in the viewer(subscriber) chain, or null if we are the only viewer.
/// # Parameters
/// `viewer`: the window to be notified.
/// # Notes
/// This API is supported by older versions of windows, it's messages are nonqueued
/// and deliverd immediately by the system, which makes it perfect for our hidden window.
pub fn registerClipboardViewer(viewer: HWND) ClipboardError!?HWND {
    utils.clearThreadError();
    const next_viewer = sys_data_exchg.SetClipboardViewer(viewer);
    if (next_viewer == null) {
        if (utils.getLastError() != win32.WIN32_ERROR.NO_ERROR) {
            return ClipboardError.SubscriptionFailed;
        }
    }
    return next_viewer;
}

/// Unsubscribe from the clipboard's viewer list.
/// # Parameters
/// `viewer`: a handle to a window that was already registered in the viewer chain.
/// `next_viewer`: a handle to the winodw that's next in the viewer chain.
pub inline fn unregisterClipboardViewer(viewer: HWND, next_viewer: ?HWND) void {
    _ = sys_data_exchg.ChangeClipboardChain(viewer, next_viewer);
}

// test "clipboard_read_and_write" {
//     const testing = std.testing;
//     // preapre the console for unicode output.
//     _ = zigwin32.system.console.SetConsoleOutputCP(zigwin32.globalization.CP_UTF8);
//     const Internals = @import("internals.zig").Internals;
//     const Win32Context = @import("driver.zig").Win32Driver;
//     const string1 = "Clipboard Test String👌.";
//     const string2 = "Another Clipboard Test String👌.";
//     try Win32Context.initSingleton("Clipboard Test", null);
//     var internals = try Internals.create(testing.allocator);
//     defer internals.destroy(testing.allocator);
//     try setClipboardText(std.testing.allocator, internals.helper_window, string1);
//     const copied_string = try clipboardText(
//         std.testing.allocator,
//         internals.helper_window,
//     );
//     defer std.testing.allocator.free(copied_string);
//     std.debug.print(
//         "\n 1st clipboard value:{s}\n string length:{}\n",
//         .{ copied_string, copied_string.len },
//     );
//     const copied_string2 = try clipboardText(
//         std.testing.allocator,
//         internals.helper_window,
//     );
//     defer std.testing.allocator.free(copied_string2);
//     std.debug.print(
//         "\n 2nd clipboard value:{s}\n string length:{}\n",
//         .{ copied_string2, copied_string2.len },
//     );
//     try setClipboardText(
//         std.testing.allocator,
//         internals.helper_window,
//         string2,
//     );
//     const copied_string3 = try clipboardText(
//         std.testing.allocator,
//         internals.helper_window,
//     );
//     defer std.testing.allocator.free(copied_string3);
//     std.debug.print(
//         "\n 3rd clipboard value:{s}\n string length:{}\n",
//         .{ copied_string3, copied_string2.len },
//     );
// }
