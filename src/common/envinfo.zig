const builtin = @import("builtin");
const cpu_info = @import("cpuinfo.zig");

const SystemInfo = struct {
    hostname: []const u8,
    cpu: struct {
        logical_cores_count: u32,
        spec: spec: {
            if (builtin.target.cpu.arch.isX86()) {
                break :spec cpu_info.CpuX86;
            } else if (builtin.target.cpu.arch.isARM() or builtin.target.cpu.arch.isAARCH64()) {
                break :spec cpu_info.CpuArm;
            } else {
                @compileError("Unsupported CPU Family\n");
            }
        },
    },
};

const ProcessInfo = struct {
    binary_path: []const u8,
    working_path: []const u8,
    user_home_path: ?[]const u8,
    user_temp_path: ?[]const u8,
    pid: u32,
};

pub const RuntimeEnv = struct {
    system: SystemInfo,
    process: ProcessInfo,
};
