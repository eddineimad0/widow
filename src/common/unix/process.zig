const std = @import("std");

const c = @cImport({
    @cInclude("unistd.h");
});

const posix = std.posix;
pub const getpid = c.getpid;

pub extern "C" fn get_nprocs() c_int;

pub fn getOsName(wr: *std.io.Writer) bool {
    const buffer = posix.uname();
    wr.print(
        "{s} ({s}), {s}",
        .{ buffer.sysname, buffer.release, buffer.version },
    ) catch return false;

    return true;
}
