const std = @import("std");
const builting = @import("builtin");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "widow",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (builting.os.tag == .windows) {
        const win32api = b.createModule(.{
            .source_file = .{ .path = "libs/zigwin32/win32.zig" },
        });
        lib.addModule("win32", win32api);
    }
    lib.linkLibC();
    lib.install();

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test_aggregator.zig" },
        .target = target,
        .optimize = optimize,
    });

    if (builting.os.tag == .windows) {
        const win32api = b.createModule(.{
            .source_file = .{ .path = "libs/zigwin32/win32.zig" },
        });
        main_tests.addModule("win32", win32api);
    }
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
