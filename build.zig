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

    var platform_module: *std.build.Module = switch (target.getOs().tag) {
        .windows => windows: {
            var win32api = b.createModule(.{
                .source_file = .{ .path = "libs/zigwin32/win32.zig" },
            });
            var deps: [2]std.build.ModuleDependency = undefined;
            deps[0] = std.build.ModuleDependency{ .name = "common", .module = common };
            deps[1] = std.build.ModuleDependency{ .name = "win32", .module = win32api };
            break :windows b.createModule(.{ .source_file = .{ .path = "src/platform/win32/platform.zig" }, .dependencies = &deps });
        },
        else => {
            @panic("Unsupported platform");
        },
    };
    lib.addModule("platform", platform_module);

    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/window.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addModule("platform", platform_module);
    main_tests.addModule("common", common);
    const run_main_test = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_test.step);

    const example_step = b.step("example", "Compile example");
    const example = b.addExecutable(.{
        .name = "simple_window",
        .root_source_file = .{ .path = "test/simple_window.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.linkLibrary(lib);
    b.installArtifact(example);
    example_step.dependOn(&example.step);
}
