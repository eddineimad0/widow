const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "widow",
        .root_source_file = .{ .path = "src/widow.zig" },
        .target = target,
        .optimize = optimize,
    });

    // common module
    const common = b.createModule(.{ .source_file = .{ .path = "src/common/common.zig" } });

    var platform_module: *std.build.Module = undefined;
    switch (target.getOs().tag) {
        .windows => {
            var win32api = b.createModule(.{
                .source_file = .{ .path = "libs/zigwin32/win32.zig" },
            });
            var deps: [2]std.build.ModuleDependency = undefined;
            deps[0] = std.build.ModuleDependency{ .name = "common", .module = common };
            deps[1] = std.build.ModuleDependency{ .name = "win32", .module = win32api };
            platform_module = b.createModule(.{ .source_file = .{ .path = "src/platform/win32/platform.zig" }, .dependencies = &deps });
        },
        else => {
            @panic("Unsupported platform");
        },
    }
    lib.addModule("platform", platform_module);

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/widow.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addModule("platform", platform_module);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
