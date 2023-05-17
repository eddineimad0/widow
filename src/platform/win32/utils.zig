const std = @import("std");

/// For comparing c strings.
pub fn wide_strz_cmp(str_a: [*:0]const u16, str_b: [*:0]const u16) bool {
    var i: usize = 0;
    while (str_a[i] != 0 and str_b[i] != 0) {
        if (str_a[i] != str_b[i]) {
            return false;
        }
        i += 1;
    }
    // assert that we reached the end of both strings.
    if (str_a[i] != str_b[i]) {
        return false;
    }
    return true;
}

pub fn str_cmp(str_a: []const u8, str_b: []const u8) bool {
    return std.mem.eql(u8, str_a, str_b);
}

/// Returns a slice to well formed Utf16 null terminated string.
/// for use with windows `Wide` api functions.
/// # Note
/// The returned slice should be freed by the caller.
pub fn utf8_to_wide(allocator: std.mem.Allocator, utf8_str: []const u8) ![:0]u16 {
    return std.unicode.utf8ToUtf16LeWithNull(allocator, utf8_str);
}

/// Returns a slice to a well formed utf8 string.
/// # Note
/// The returned slice should be freed by the caller.
pub fn wide_to_utf8(allocator: std.mem.Allocator, wide_str: []const u16) ![]u8 {
    var zero_idx: usize = 0;
    while (wide_str[zero_idx] != 0) {
        zero_idx += 1;
    }
    // utf16leToUtf8Alloc will allocate space for the null terminator,
    // and anything that comes after it in the slice
    // to save some memory indicate the new start and end of the slice
    return std.unicode.utf16leToUtf8Alloc(allocator, wide_str.ptr[0..zero_idx]);
}

/// Replacement for the `MAKEINTATOM` macro in the windows api.
/// # Note
/// Some functions signature in the zigwin32 library needed modification
/// for this to work.
pub fn make_int_atom(comptime T: type, atom: T) ?[*:0]align(1) const T {
    return @intToPtr(?[*:0]align(1) const T, @as(usize, atom));
}
