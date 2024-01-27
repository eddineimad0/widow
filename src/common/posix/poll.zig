const std = @import("std");
const libc = std.c;
const c = @cImport({
    @cInclude("poll.h");
    @cInclude("time.h");
});

const NS_PER_SEC = std.time.ns_per_s;

pub const PollFlag = enum(u1) {
    IORead = 0x0,
    IOWrite = 0x1,
};

// timeout variable should be in nanoseconds.
pub fn poll(fd: c_int, flag: PollFlag, timeout: i64, ready_count: *u32) bool {
    var count: c_int = 0;
    const events = switch (flag) {
        .IORead => c.POLLIN | c.POLLPRI,
        .IOWrite => c.POLLOUT,
    };
    var pfd = libc.pollfd{ .fd = fd, .events = @intCast(events), .revents = 0 };
    while (true) {
        if (timeout < 0) {
            count = libc.poll(@ptrCast(&pfd), 1, -1);
            if (count > 0) {
                ready_count.* = @intCast(count);
                return true;
            } else if (count == -1) {
                // On some other UNIX systems, poll() can fail with the error EAGAIN
                // if the system fails to allocate kernel-internal resources, rather
                // than ENOMEM as Linux does.  POSIX permits this behavior.
                // Portable programs may wish to check for EAGAIN and loop, just as
                // with EINTR.
                const e = libc.getErrno(count);
                if (e != libc.E.INTR and e != libc.E.AGAIN) {
                    return false;
                }
            }
        } else {
            const seconds = @divTrunc(timeout, NS_PER_SEC);
            const nanoseconds = timeout - (seconds * NS_PER_SEC);
            const t = libc.timespec{ .tv_sec = seconds, .tv_nsec = nanoseconds };
            count = libc.ppoll(@ptrCast(&pfd), 1, &t, null);

            if (count > 0) {
                ready_count.* = @intCast(count);
                return true;
            } else if (count == -1) {
                // On some other UNIX systems, poll() can fail with the error EAGAIN
                // if the system fails to allocate kernel-internal resources, rather
                // than ENOMEM as Linux does.  POSIX permits this behavior.
                // Portable programs may wish to check for EAGAIN and loop, just as
                // with EINTR.
                const e = libc.getErrno(count);
                if (e != libc.E.INTR and e != libc.E.AGAIN) {
                    return false;
                }
            }
        }
    }
}

pub fn systemTimerValue() u64 {
    var t: c.timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_REALTIME, &t);
    const result: u64 = @as(u64, @intCast(t.tv_sec)) * NS_PER_SEC + @as(u64, @intCast(t.tv_nsec));
    return result;
}
