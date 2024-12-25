const std = @import("std");
const mem = std.mem;

pub const GLProfile = enum(u1) {
    Compat,
    Core,
};

/// Holds configuration for customizing created
/// opengl context.
pub const GLConfig = struct {
    ver: struct {
        major: u8 = 4,
        minor: u8 = 2,
    } = .{},
    profile: GLProfile = .Core,
};

/// Returns true if the `target` extension is in the `ext_list` string
pub fn glHasExtension(noalias target: [*:0]const u8, noalias ext_list: [:0]const u8) bool {
    var haystack = ext_list;
    while (true) {
        const start = mem.indexOf(u8, haystack, mem.span(target));
        if (start) |s| {
            const end = s + mem.len(target);
            if (s == 0 or haystack[s - 1] == ' ') {
                if (haystack[end] == ' ' or haystack[end] == 0) {
                    return true;
                }
            }
            haystack = ext_list[end..];
        } else {
            return false;
        }
    }
}
