const std = @import("std");
const common = @import("common");
const ole32 = @import("win32api/ole32.zig");
const kernl32 = @import("win32api/kernel32.zig");

const win32 = std.os.windows;
const mem = std.mem;
const unicode = std.unicode;
const dbg = std.debug;

const MAX_COMPUTERNAME_LENGTH = @as(u32, 15);
const SE_LOCK_MEMORY_NAME = "SeLockMemoryPrivilege";

const TOKEN_PRIVILEGES_ATTRIBUTES = packed struct(u32) {
    ENABLED_BY_DEFAULT: u1 = 0,
    ENABLED: u1 = 0,
    REMOVED: u1 = 0,
    _3: u1 = 0,
    _4: u1 = 0,
    _5: u1 = 0,
    _6: u1 = 0,
    _7: u1 = 0,
    _8: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    _16: u1 = 0,
    _17: u1 = 0,
    _18: u1 = 0,
    _19: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    _24: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    USED_FOR_ACCESS: u1 = 0,
};
const SE_PRIVILEGE_ENABLED = TOKEN_PRIVILEGES_ATTRIBUTES{ .ENABLED = 1 };
const SE_PRIVILEGE_ENABLED_BY_DEFAULT = TOKEN_PRIVILEGES_ATTRIBUTES{ .ENABLED_BY_DEFAULT = 1 };
const SE_PRIVILEGE_REMOVED = TOKEN_PRIVILEGES_ATTRIBUTES{ .REMOVED = 1 };
const SE_PRIVILEGE_USED_FOR_ACCESS = TOKEN_PRIVILEGES_ATTRIBUTES{ .USED_FOR_ACCESS = 1 };

const TOKEN_ACCESS_MASK = packed struct(u32) {
    ASSIGN_PRIMARY: u1 = 0,
    DUPLICATE: u1 = 0,
    IMPERSONATE: u1 = 0,
    QUERY: u1 = 0,
    QUERY_SOURCE: u1 = 0,
    ADJUST_PRIVILEGES: u1 = 0,
    ADJUST_GROUPS: u1 = 0,
    ADJUST_DEFAULT: u1 = 0,
    ADJUST_SESSIONID: u1 = 0,
    _9: u1 = 0,
    _10: u1 = 0,
    _11: u1 = 0,
    _12: u1 = 0,
    _13: u1 = 0,
    _14: u1 = 0,
    _15: u1 = 0,
    DELETE: u1 = 0,
    READ_CONTROL: u1 = 0,
    WRITE_DAC: u1 = 0,
    WRITE_OWNER: u1 = 0,
    _20: u1 = 0,
    _21: u1 = 0,
    _22: u1 = 0,
    _23: u1 = 0,
    ACCESS_SYSTEM_SECURITY: u1 = 0,
    _25: u1 = 0,
    _26: u1 = 0,
    _27: u1 = 0,
    _28: u1 = 0,
    _29: u1 = 0,
    _30: u1 = 0,
    _31: u1 = 0,
};
const TOKEN_DELETE = TOKEN_ACCESS_MASK{ .DELETE = 1 };
const TOKEN_READ_CONTROL = TOKEN_ACCESS_MASK{ .READ_CONTROL = 1 };
const TOKEN_WRITE_DAC = TOKEN_ACCESS_MASK{ .WRITE_DAC = 1 };
const TOKEN_WRITE_OWNER = TOKEN_ACCESS_MASK{ .WRITE_OWNER = 1 };
const TOKEN_ACCESS_SYSTEM_SECURITY = TOKEN_ACCESS_MASK{ .ACCESS_SYSTEM_SECURITY = 1 };
const TOKEN_ASSIGN_PRIMARY = TOKEN_ACCESS_MASK{ .ASSIGN_PRIMARY = 1 };
const TOKEN_DUPLICATE = TOKEN_ACCESS_MASK{ .DUPLICATE = 1 };
const TOKEN_IMPERSONATE = TOKEN_ACCESS_MASK{ .IMPERSONATE = 1 };
const TOKEN_QUERY = TOKEN_ACCESS_MASK{ .QUERY = 1 };
const TOKEN_QUERY_SOURCE = TOKEN_ACCESS_MASK{ .QUERY_SOURCE = 1 };
const TOKEN_ADJUST_PRIVILEGES = TOKEN_ACCESS_MASK{ .ADJUST_PRIVILEGES = 1 };
const TOKEN_ADJUST_GROUPS = TOKEN_ACCESS_MASK{ .ADJUST_GROUPS = 1 };
const TOKEN_ADJUST_DEFAULT = TOKEN_ACCESS_MASK{ .ADJUST_DEFAULT = 1 };
const TOKEN_ADJUST_SESSIONID = TOKEN_ACCESS_MASK{ .ADJUST_SESSIONID = 1 };
const TOKEN_READ = TOKEN_ACCESS_MASK{
    .QUERY = 1,
    .READ_CONTROL = 1,
};
const TOKEN_WRITE = TOKEN_ACCESS_MASK{
    .ADJUST_PRIVILEGES = 1,
    .ADJUST_GROUPS = 1,
    .ADJUST_DEFAULT = 1,
    .READ_CONTROL = 1,
};
const TOKEN_EXECUTE = TOKEN_ACCESS_MASK{ .READ_CONTROL = 1 };
const TOKEN_TRUST_CONSTRAINT_MASK = TOKEN_ACCESS_MASK{
    .QUERY = 1,
    .QUERY_SOURCE = 1,
    .READ_CONTROL = 1,
};
const TOKEN_ACCESS_PSEUDO_HANDLE_WIN8 = TOKEN_ACCESS_MASK{
    .QUERY = 1,
    .QUERY_SOURCE = 1,
};
const TOKEN_ACCESS_PSEUDO_HANDLE = TOKEN_ACCESS_MASK{
    .QUERY = 1,
    .QUERY_SOURCE = 1,
};
const TOKEN_ALL_ACCESS = TOKEN_ACCESS_MASK{
    .ASSIGN_PRIMARY = 1,
    .DUPLICATE = 1,
    .IMPERSONATE = 1,
    .QUERY = 1,
    .QUERY_SOURCE = 1,
    .ADJUST_PRIVILEGES = 1,
    .ADJUST_GROUPS = 1,
    .ADJUST_DEFAULT = 1,
    .DELETE = 1,
    .READ_CONTROL = 1,
    .WRITE_DAC = 1,
    .WRITE_OWNER = 1,
};

const LUID = extern struct {
    LowPart: win32.DWORD,
    HighPart: win32.LONG,
};

const TOKEN_PRIVILEGES = extern struct {
    PrivilegeCount: u32,
    Privileges: [1]LUID_AND_ATTRIBUTES,
};

const LUID_AND_ATTRIBUTES = extern struct {
    Luid: LUID,
    Attributes: TOKEN_PRIVILEGES_ATTRIBUTES,
};

const SYSTEM_INFO = extern struct {
    Anonymous: extern union {
        dwOemId: u32,
        Anonymous: extern struct {
            wProcessorArchitecture: PROCESSOR_ARCHITECTURE,
            wReserved: u16,
        },
    },
    dwPageSize: u32,
    lpMinimumApplicationAddress: ?*anyopaque,
    lpMaximumApplicationAddress: ?*anyopaque,
    dwActiveProcessorMask: usize,
    dwNumberOfProcessors: u32,
    dwProcessorType: u32,
    dwAllocationGranularity: u32,
    wProcessorLevel: u16,
    wProcessorRevision: u16,
};

const PROCESSOR_ARCHITECTURE = enum(u16) {
    AMD64 = 9,
    IA64 = 6,
    INTEL = 0,
    ARM = 5,
    UNKNOWN = 65535,
};

extern "advapi32" fn OpenProcessToken(
    ProcessHandle: ?win32.HANDLE,
    DesiredAccess: TOKEN_ACCESS_MASK,
    TokenHandle: ?*?win32.HANDLE,
) callconv(.winapi) win32.BOOL;

extern "advapi32" fn LookupPrivilegeValueA(
    lpSystemName: ?[*:0]const u8,
    lpName: ?[*:0]const u8,
    lpLuid: ?*LUID,
) callconv(.winapi) win32.BOOL;

extern "advapi32" fn AdjustTokenPrivileges(
    TokenHandle: ?win32.HANDLE,
    DisableAllPrivileges: win32.BOOL,
    NewState: ?*TOKEN_PRIVILEGES,
    BufferLength: u32,
    PreviousState: ?*TOKEN_PRIVILEGES,
    ReturnLength: ?*u32,
) callconv(.winapi) win32.BOOL;
extern "kernel32" fn GetSystemInfo(
    lpSystemInfo: ?*SYSTEM_INFO,
) callconv(.winapi) void;

extern "userenv" fn GetUserProfileDirectoryW(
    hToken: win32.HANDLE,
    lpProfileDir: ?win32.LPWSTR,
    lpcchSize: *win32.DWORD,
) callconv(.winapi) win32.BOOL;

//---------------------
// Types
//---------------------
pub const Win32EnvInfo = struct {
    common: common.envinfo.RuntimeEnv,
    input_cp: win32.UINT,
    output_cp: win32.UINT,
    orig_console_mode: win32.DWORD,
    com_supported: bool,

    pub fn deinit(pinfo: *@This(), allocator: mem.Allocator) void {
        allocator.free(pinfo.common.process.binary_path);
        allocator.free(pinfo.common.process.working_path);
        allocator.free(pinfo.common.system.hostname);
        if (pinfo.common.process.user_home_path) |path| {
            allocator.free(path);
        }
        if (pinfo.common.process.user_temp_path) |path| {
            allocator.free(path);
        }

        if (pinfo.com_supported) {
            ole32.CoUninitialize();
        }
        _ = kernl32.SetConsoleCP(pinfo.input_cp);
        _ = kernl32.SetConsoleOutputCP(pinfo.output_cp);

        if (pinfo.orig_console_mode != 0) {
            const console_handle = win32.GetStdHandle(win32.STD_OUTPUT_HANDLE) catch return;
            const ok = kernl32.SetConsoleMode(console_handle, pinfo.orig_console_mode);
            dbg.assert(ok == win32.TRUE);
        }

        pinfo.common.process = undefined;
        pinfo.common.system = undefined;
    }
};

//---------------------
// Functions
//---------------------
pub fn getPlatformInfo(allocator: mem.Allocator) !Win32EnvInfo {
    var pinfo = Win32EnvInfo{
        .common = .{
            .system = .{
                .hostname = &.{},
                .cpu = .{
                    .logical_cores_count = 0,
                    .spec = undefined,
                },
            },
            .process = .{
                .binary_path = undefined,
                .working_path = undefined,
                .user_home_path = null,
                .user_temp_path = null,
                .pid = 0,
            },
        },
        .input_cp = 0,
        .output_cp = 0,
        .orig_console_mode = 0,
        .com_supported = false,
    };

    // get the pid
    pinfo.common.process.pid = win32.GetCurrentProcessId();

    // copy system informations
    var sys_info = mem.zeroes(SYSTEM_INFO);
    GetSystemInfo(&sys_info);

    pinfo.common.system.cpu.logical_cores_count = sys_info.dwNumberOfProcessors;

    // get computer name
    var name_buffer = mem.zeroes([MAX_COMPUTERNAME_LENGTH + 1:0]u8);
    var name_buff_size: u32 = MAX_COMPUTERNAME_LENGTH + 1;
    if (kernl32.GetComputerNameA(&name_buffer, &name_buff_size) == win32.TRUE) {
        dbg.assert(name_buff_size < MAX_COMPUTERNAME_LENGTH + 1);
        pinfo.common.system.hostname = try allocator.dupe(u8, name_buffer[0..name_buff_size]);
    }

    // get the current working directory
    const path_size: u32 = kernl32.GetCurrentDirectoryW(0, null);
    var path_u16 = try allocator.allocSentinel(u16, path_size, 0);
    defer allocator.free(path_u16);
    const path_length = kernl32.GetCurrentDirectoryW(path_size, path_u16.ptr);
    dbg.assert(path_length <= path_size);
    pinfo.common.process.working_path = try unicode.utf16LeToUtf8Alloc(
        allocator,
        path_u16[0..path_length],
    );

    // get the binary name.
    const MAX_BINARY_PATH_NAME = @as(usize, 4096);
    const bin_name_u16 = try allocator.allocSentinel(u16, MAX_BINARY_PATH_NAME, 0);
    defer allocator.free(bin_name_u16);
    const bin_name_size = kernl32.GetModuleFileNameW(null, bin_name_u16.ptr, MAX_BINARY_PATH_NAME);
    dbg.assert(bin_name_size <= MAX_BINARY_PATH_NAME);
    pinfo.common.process.binary_path = try unicode.utf16LeToUtf8Alloc(
        allocator,
        bin_name_u16[0..bin_name_size],
    );

    // get the user home path.
    {
        var token: win32.HANDLE = undefined;
        if (OpenProcessToken(
            win32.GetCurrentProcess(),
            TOKEN_ACCESS_MASK{ .QUERY = 1 },
            @ptrCast(&token),
        ) == win32.TRUE) {
            defer win32.CloseHandle(token);

            var user_home_path_u16_length: u32 = 0;
            _ = GetUserProfileDirectoryW(token, null, &user_home_path_u16_length);
            const user_home_path_u16 = try allocator.alloc(u16, user_home_path_u16_length); // null terminator included
            defer allocator.free(user_home_path_u16);
            const ok = GetUserProfileDirectoryW(token, @ptrCast(user_home_path_u16.ptr), &user_home_path_u16_length);
            if (ok == win32.TRUE) {
                pinfo.common.process.user_home_path = try unicode.utf16LeToUtf8Alloc(
                    allocator,
                    user_home_path_u16[0 .. user_home_path_u16_length - 1],
                );
            }

            if (pinfo.common.process.user_home_path) |path| {
                // we need to make sure this path exist
                var dir: ?std.fs.Dir = std.fs.openDirAbsolute(path, .{}) catch dir: {
                    allocator.free(path);
                    pinfo.common.process.user_home_path = null;
                    break :dir null;
                };
                if (dir) |*d| {
                    d.close();
                }
            }
        }
    }

    // get the user temp path
    {
        const user_tmp_path_u16_length = kernl32.GetTempPathW(0, null);
        dbg.assert(user_tmp_path_u16_length > 0);
        const user_tmp_path_u16 = try allocator.alloc(u16, user_tmp_path_u16_length);
        defer allocator.free(user_tmp_path_u16);
        const bytes_copied = kernl32.GetTempPathW(user_tmp_path_u16_length, @ptrCast(user_tmp_path_u16.ptr));
        dbg.assert(bytes_copied == user_tmp_path_u16_length - 1);
        pinfo.common.process.user_temp_path = try unicode.utf16LeToUtf8Alloc(
            allocator,
            user_tmp_path_u16[0..bytes_copied],
        );

        // we need to make sure this path exist since windows doesn't check for us
        if (pinfo.common.process.user_temp_path) |path| {
            var dir: ?std.fs.Dir = std.fs.openDirAbsolute(path, .{}) catch dir: {
                allocator.free(path);
                pinfo.common.process.user_temp_path = null;
                break :dir null;
            };
            if (dir) |*d| {
                d.close();
            }
        }
    }

    // cpu features query
    pinfo.common.system.cpu.spec.fetchCPUFeatures();

    // COM intialize
    const result = ole32.CoInitializeEx(null, win32.COINIT.MULTITHREADED);
    if (result == win32.S_OK or result == win32.S_FALSE) {
        pinfo.com_supported = true;
    }

    // save current console page
    pinfo.input_cp = kernl32.GetConsoleCP();
    pinfo.output_cp = kernl32.GetConsoleOutputCP();

    // set console page
    var ok = kernl32.SetConsoleCP(kernl32.CP_UTF8);
    dbg.assert(ok == win32.TRUE);
    ok = kernl32.SetConsoleOutputCP(kernl32.CP_UTF8);
    dbg.assert(ok == win32.TRUE);

    // set virtual console
    const console_handle = win32.GetStdHandle(win32.STD_OUTPUT_HANDLE) catch unreachable;
    var orig_console_mode: win32.DWORD = 0;
    ok = kernl32.GetConsoleMode(console_handle, &orig_console_mode);
    dbg.assert(ok == win32.TRUE);
    pinfo.orig_console_mode = orig_console_mode;
    const ENABLE_VIRTUAL_TERMINAL_PROCESSING: win32.DWORD = 0x0004;
    ok = kernl32.SetConsoleMode(console_handle, orig_console_mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
    dbg.assert(ok == win32.TRUE);

    return pinfo;
}
