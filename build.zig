const std = @import("std");
const builting = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "widow",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (target.getOs().tag == .windows) {
        const win32api = b.createModule(.{
            .source_file = .{ .path = "libs/zigwin32/win32.zig" },
        });
        lib.addModule("win32", win32api);
    }
    lib.linkLibC();
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test_aggregator.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (target.getOs().tag == .windows) {
        const win32api = b.createModule(.{
            .source_file = .{ .path = "libs/zigwin32/win32.zig" },
        });
        main_tests.addModule("win32", win32api);
    }
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
