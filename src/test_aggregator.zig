const monitor_impl = @import("platform/win32/monitor_impl.zig");
const module = @import("platform/win32/module.zig");
const internals = @import("platform/win32/internals.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
