const std = @import("std");
const info = @import("../envinfo.zig");
const proc = @import("process.zig");

const posix = std.posix;
const mem = std.mem;
const unicode = std.unicode;

//---------------------
// Types
//---------------------
pub const UnixEnvInfo = struct {
    common: info.RuntimeEnv,

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

        pinfo.common.process = undefined;
        pinfo.common.system = undefined;
    }
};

//---------------------
// Functions
//---------------------

fn getHostName(allocator: mem.Allocator) mem.Allocator.Error![]const u8 {
    const hostname_buffer = try allocator.alloc(u8, posix.HOST_NAME_MAX);
    const hostname = posix.gethostname(@ptrCast(hostname_buffer)) catch return &.{};
    if (allocator.resize(hostname_buffer, hostname.len)) {
        return hostname_buffer;
    } else {
        const dupe_hostname = try allocator.dupe(u8, hostname);
        allocator.free(hostname_buffer);
        return dupe_hostname;
    }
}

fn getCWD(allocator: mem.Allocator) mem.Allocator.Error![]const u8 {
    var buffers: [4][]u8 = undefined;
    var ret_buffer_idx: usize = undefined;
    var cwd: ?[]u8 = null;
    for (1..1 + buffers.len) |i| {
        const buffer_size: usize = i * 4096;
        ret_buffer_idx = i - 1;
        buffers[ret_buffer_idx] = try allocator.alloc(u8, buffer_size);
        cwd = posix.getcwd(buffers[ret_buffer_idx]) catch continue;
    }

    for (0..ret_buffer_idx) |i| {
        allocator.free(buffers[i]);
    }

    if (cwd) |dir| {
        if (allocator.resize(buffers[ret_buffer_idx], dir.len)) {
            return buffers[ret_buffer_idx];
        } else {
            const dup_cwd = try allocator.dupe(u8, buffers[ret_buffer_idx][0..dir.len]);
            allocator.free(buffers[ret_buffer_idx]);
            return dup_cwd;
        }
    } else {
        allocator.free(buffers[ret_buffer_idx]);
        return &.{};
    }
}

fn getBinPath(allocator: mem.Allocator) mem.Allocator.Error![]const u8 {
    var buffers: [4][]u8 = undefined;
    var ret_buffer_idx: usize = undefined;
    var bin_path: ?[]u8 = null;
    for (1..1 + buffers.len) |i| {
        const buffer_size: usize = i * 4096;
        ret_buffer_idx = i - 1;
        buffers[ret_buffer_idx] = try allocator.alloc(u8, buffer_size);
        bin_path = posix.readlink("/proc/self/exe", buffers[ret_buffer_idx]) catch continue;
    }

    for (0..ret_buffer_idx) |i| {
        allocator.free(buffers[i]);
    }

    if (bin_path) |path| {
        if (allocator.resize(buffers[ret_buffer_idx], path.len)) {
            return buffers[ret_buffer_idx];
        } else {
            const dupe_bin_path = try allocator.dupe(u8, buffers[ret_buffer_idx][0..path.len]);
            allocator.free(buffers[ret_buffer_idx]);
            return dupe_bin_path;
        }
    } else {
        allocator.free(buffers[ret_buffer_idx]);
        return &.{};
    }
}

pub fn getPlatformInfo(allocator: mem.Allocator) mem.Allocator.Error!UnixEnvInfo {
    var pinfo = UnixEnvInfo{
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
    };
    // copy system informations
    pinfo.common.system.cpu.logical_cores_count = @intCast(proc.get_nprocs());

    // get computer name
    pinfo.common.system.hostname = try getHostName(allocator);

    // get the current working directory
    pinfo.common.process.working_path = try getCWD(allocator);

    // get the pid
    pinfo.common.process.pid = @intCast(proc.getpid());

    // get the binary name
    pinfo.common.process.binary_path = try getBinPath(allocator);

    // get user home path
    {
        const env_home = posix.getenvZ("HOME");
        if (env_home) |home| {
            pinfo.common.process.user_home_path = try allocator.dupe(u8, home);
        }

        if (pinfo.common.process.user_home_path) |path| {
            // make sure it exist
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

    // get user temp path
    {
        const search_env_vars: [2][*:0]const u8 = .{ "XDG_RUNTIME_DIR", "TMPDIR" };
        var env_tmp_path: ?[:0]const u8 = null;
        var path_found = false;
        for (search_env_vars) |v| {
            env_tmp_path = posix.getenvZ(v);
            if (env_tmp_path) |p| {
                // TODO: we can possibly just create it instead of this
                var dir: std.fs.Dir = std.fs.openDirAbsoluteZ(p, .{}) catch {
                    continue;
                };
                dir.close();

                path_found = true;
                pinfo.common.process.user_temp_path = try allocator.dupe(u8, p);
                break;
            }
        }

        if (!path_found) {
            pinfo.common.process.user_temp_path = try allocator.dupe(u8, "/tmp");
        }
    }

    pinfo.common.system.cpu.spec.fetchCPUFeatures();

    return pinfo;
}
