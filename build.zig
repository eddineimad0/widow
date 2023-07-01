const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // common module
    const common_module = b.createModule(.{ .source_file = .{ .path = "src/common/common.zig" } });

    var platform_module: *std.build.Module = switch (target.getOs().tag) {
        .windows => windows: {
            var zigwin32 = b.createModule(.{
                .source_file = .{ .path = "libs/zigwin32/win32.zig" },
            });
            var deps: [2]std.build.ModuleDependency = undefined;
            deps[0] = std.build.ModuleDependency{ .name = "common", .module = common_module };
            deps[1] = std.build.ModuleDependency{ .name = "zigwin32", .module = zigwin32 };
            break :windows b.createModule(.{ .source_file = .{ .path = "src/platform/win32/platform.zig" }, .dependencies = &deps });
        },
        else => {
            @panic("Unsupported platform");
        },
    };

    const deps = [2]std.build.ModuleDependency{
        std.build.ModuleDependency{ .name = "common", .module = common_module },
        std.build.ModuleDependency{ .name = "platform", .module = platform_module },
    };

    const widow = b.createModule(.{ .source_file = .{ .path = "src/widow.zig" }, .dependencies = &deps });

    const test_step = b.step("test", "Run all library tests");
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/widow.zig" },
        .target = target,
        .optimize = optimize,
    });

    main_tests.addModule("common", common_module);
    main_tests.addModule("platform", platform_module);
    const run_main_test = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_test.step);

    const example_step = b.step("example", "Compile example");

    const examples = [_][]const u8{
        "simple_window",
        "playing_with_inputs",
        "cursor_and_icon",
        "window_joystick",
    };
    for (examples) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        example.addModule("widow", widow);
        example.linkLibC();
        const install_step = b.addInstallArtifact(example);
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_step.step);
    }

    const all_step = b.step("all", "Build all examples and run all tests.");
    all_step.dependOn(test_step);
    all_step.dependOn(example_step);

    b.default_step.dependOn(example_step);
}
