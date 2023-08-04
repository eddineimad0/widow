const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const widow = exportWidowModule(b, &target);

    const example_step = b.step("example", "Compile example");
    const examples = [_][]const u8{
        "simple_window",
        "playing_with_inputs",
        "cursor_and_icon",
        "joystick",
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
        const install_step = b.addInstallArtifact(example, .{});
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_step.step);
    }
}

fn exportWidowModule(b: *std.Build, target: *const std.zig.CrossTarget) *std.build.Module {
    const common_module = b.createModule(.{ .source_file = .{ .path = "src/common/common.zig" } });

    var platform_module: *std.build.Module = switch (target.getOs().tag) {
        .windows => windows: {
            var zigwin32 = b.createModule(.{
                .source_file = .{ .path = "libs/zigwin32/win32.zig" },
            });
            var deps: [2]std.build.ModuleDependency = undefined;
            deps[0] = std.build.ModuleDependency{ .name = "common", .module = common_module };
            deps[1] = std.build.ModuleDependency{ .name = "zigwin32", .module = zigwin32 };
            break :windows b.createModule(
                .{ .source_file = .{ .path = "src/platform/win32/platform.zig" }, .dependencies = &deps },
            );
        },
        else => {
            @panic("Unsupported platform");
        },
    };

    const deps = [2]std.build.ModuleDependency{
        std.build.ModuleDependency{ .name = "common", .module = common_module },
        std.build.ModuleDependency{ .name = "platform", .module = platform_module },
    };

    const widow = b.addModule("widow", .{ .source_file = .{ .path = "src/main.zig" }, .dependencies = &deps });
    return widow;
}
