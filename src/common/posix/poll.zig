const std = @import("std");
const posix = std.posix;
const NS_PER_SEC = std.time.ns_per_s;

pub const PollFlag = enum(u1) {
    IORead = 0x0,
    IOWrite = 0x1,
};

pub fn poll(fd: c_int, flag: PollFlag, timeout_ns: i64, ready_count: *u32) bool {
    var count: c_int = 0;
    const events: i16 = switch (flag) {
        .IORead => posix.POLL.IN | posix.POLL.PRI,
        .IOWrite => posix.POLL.OUT,
    };
    var pfd = posix.pollfd{ .fd = fd, .events = events, .revents = 0 };
    while (true) {
        if (timeout_ns < 0) {
            count = std.c.poll(@ptrCast(&pfd), 1, -1);
            if (count > 0) {
                ready_count.* = @intCast(count);
                return true;
            } else if (count == -1) {
                // On some other UNIX systems, poll() can fail with the error EAGAIN
                // if the system fails to allocate kernel-internal resources, rather
                // than ENOMEM as Linux does.  POSIX permits this behavior.
                // Portable programs may wish to check for EAGAIN and loop, just as
                // with EINTR.
                const e = posix.errno(count);
                if (e != posix.E.INTR and e != posix.E.AGAIN) {
                    return false;
                }
            }
        } else {
            const seconds = @divTrunc(timeout_ns, NS_PER_SEC);
            const nanoseconds = timeout_ns - (seconds * NS_PER_SEC);
            const t = posix.timespec{ .tv_sec = seconds, .tv_nsec = nanoseconds };
            count = std.c.ppoll(@ptrCast(&pfd), 1, &t, null);

            if (count > 0) {
                ready_count.* = @intCast(count);
                return true;
            } else if (count == -1) {
                const e = posix.errno(count);
                if (e != posix.E.INTR and e != posix.E.AGAIN) {
                    return false;
                }
            }
        }
    }
}
