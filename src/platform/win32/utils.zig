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

/// Returns a pointer to well formed Utf16 string for use with windows `Wide` api functions.
pub fn utf8_to_wide(allocator: std.mem.Allocator, utf8_string: []const u8) ![:0]u16 {
    return try std.unicode.utf8ToUtf16LeWithNull(allocator, utf8_string);
}

/// Replacement for the `MAKEINTATOM` macro in the windows api.
/// # Note
/// Some functions signature in the zigwin32 library needed modification
/// for this to work.
pub fn make_int_atom(comptime T: type, atom: T) ?[*:0]align(1) const T {
    return @intToPtr(?[*:0]align(1) const T, @as(usize, atom));
}
