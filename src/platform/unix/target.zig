const b = @import("builtin");

const UnixTarget = enum {
    FreeBSD,
    NetBSD,
    Linux,
};

pub const target = switch (b.target.os.tag) {
    .linux => UnixTarget.Linux,
    .freebsd => UnixTarget.FreeBSD,
    .netbsd => UnixTarget.NetBSD,
};
