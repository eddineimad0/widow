const std = @import("std");
const win32 = @import("std").os.windows;

const dbg = std.debug;

const CREATE_WAITABLE_TIMER_MANUAL_RESET = @as(u32, 0x00000001);
const CREATE_WAITABLE_TIMER_HIGH_RESOLUTION = @as(u32, 0x00000002);
const TIMER_MODIFY_STATE = @as(u32, 0x0002);
const TIMER_QUERY_STATE = @as(u32, 0x0001);
const TIMER_ALL_ACCESS = @as(u32, 0x1f0003);

extern "kernel32" fn QueryPerformanceFrequency(
    lpFrequency: *win32.LARGE_INTEGER,
) callconv(.winapi) win32.BOOL;

extern "kernel32" fn QueryPerformanceCounter(
    lpPerformanceCount: *win32.LARGE_INTEGER,
) callconv(.winapi) win32.BOOL;

extern "kernel32" fn CreateWaitableTimerExW(
    lpTimerAttributes: ?*win32.SECURITY_ATTRIBUTES,
    lpTimerName: ?win32.LPCWSTR,
    dwFlags: win32.DWORD,
    dwDesiredAccess: win32.DWORD,
) callconv(.winapi) win32.HANDLE;

extern "kernel32" fn SetWaitableTimerEx(
    hTimer: win32.HANDLE,
    lpDueTime: *const win32.LARGE_INTEGER,
    lPeriod: win32.LONG,
    pfnCompletionRoutine: ?*const anyopaque, // the actual type is PTIMERAPCROUTINE
    lpArgToCompletionRoutine: ?win32.LPVOID,
    wakeContext: ?*const anyopaque, // the actual type is REASON_CONTEXT, however we are giving it null.
    tolerableDelay: win32.ULONG,
) callconv(.winapi) win32.BOOL;

pub inline fn getMonotonicClockFrequency() u64 {
    var f: win32.LARGE_INTEGER = undefined;
    _ = QueryPerformanceFrequency(&f);
    return @intCast(f);
}

pub inline fn getMonotonicClockTicks() u64 {
    var c: win32.LARGE_INTEGER = undefined;
    _ = QueryPerformanceCounter(&c);
    return @intCast(c);
}

pub fn waitForNs(timeout_ns: u64) void {
    if (use_waitable_timer) {
        if (timer == null) {
            timer = CreateWaitableTimerExW(
                null,
                null,
                CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
                TIMER_ALL_ACCESS,
            );
            if (timer == null) {
                use_waitable_timer = false;
                std.Thread.sleep(timeout_ns);
                return;
            }
        }
        const wait_time: win32.LARGE_INTEGER = -1 * (@as(i64, @intCast(timeout_ns / 100)));
        const ok = SetWaitableTimerEx(timer.?, &wait_time, 0, null, null, null, 0);
        if (ok == win32.TRUE) {
            const result = win32.kernel32.WaitForSingleObject(timer.?, win32.INFINITE);
            dbg.assert(result == 0); // object was signaled
            return;
        }
    }

    if (wait_event == null) {
        wait_event = win32.CreateEventExW(
            null,
            null,
            0,
            win32.DELETE | win32.SYNCHRONIZE | win32.EVENT_MODIFY_STATE,
        ) catch null;
    }

    if (wait_event) |e| {
        const timeout_ms = timeout_ns / std.time.ns_per_ms;
        const wait_time = std.math.cast(win32.DWORD, timeout_ms) orelse
            @as(win32.DWORD, @truncate(timeout_ms));
        const result = win32.kernel32.WaitForSingleObjectEx(e, wait_time, win32.FALSE);
        dbg.assert(result == 0x102); // timeout reached
    } else {
        @branchHint(.cold);
        // call kernel sleep
        std.Thread.sleep(timeout_ns);
    }
}

threadlocal var timer: ?win32.HANDLE = null;
threadlocal var wait_event: ?win32.HANDLE = null;
threadlocal var use_waitable_timer: bool = true;
