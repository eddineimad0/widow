const std = @import("std");

const DisplayTarget = enum {
    Win32,
    Xorg,
    Wayland,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const display_target = detectDispalyTarget(&target);

    const widow = prepareWidowModule(b, display_target);

    const example_step = b.step("example", "Compile example");
    const examples = [_][]const u8{
        // "simple_window",
        // "playing_with_inputs",
        // "cursor_and_icon",
        // "joystick",
        "xorg_basic",
    };
    for (examples) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        example.addModule("widow", widow);
        switch (display_target) {
            .Xorg => {
                example.linkSystemLibrary("X11");
            },
            else => {},
        }
        example.linkLibC();
        const install_step = b.addInstallArtifact(example, .{});
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_step.step);
    }
}

fn detectDispalyTarget(target: *const std.zig.CrossTarget) DisplayTarget {
    return switch (target.getOs().tag) {
        .windows => .Win32,
        .linux, .freebsd, .netbsd => unix: {
            // need to determine what display server is being used
            const display_server = std.os.getenv("XDG_SESSION_TYPE") orelse @panic("Couldn't determine display server session\n");
            if (std.mem.orderZ(u8, display_server, "x11") == .eq) {
                break :unix .Xorg;
            } else if (std.mem.orderZ(u8, display_server, "wayland") == .eq) {
                break :unix .Wayland;
            } else {
                @panic("Unsupported unix display server");
            }
        },
        else => @panic("Unsupported Target"),
    };
}

fn prepareWidowModule(b: *std.Build, target: DisplayTarget) *std.build.Module {
    const common_module = b.createModule(.{ .source_file = .{ .path = "src/common/common.zig" } });
    const common_dep = std.build.ModuleDependency{ .name = "common", .module = common_module };
    var platform_dep: *std.build.Module = switch (target) {
        .Win32 => win32: {
            var zigwin32 = b.createModule(.{
                .source_file = .{ .path = "libs/zigwin32/win32.zig" },
            });
            var deps: [2]std.build.ModuleDependency = undefined;
            deps[0] = common_dep;
            deps[1] = std.build.ModuleDependency{ .name = "zigwin32", .module = zigwin32 };
            break :win32 b.createModule(
                .{ .source_file = .{ .path = "src/platform/win32/platform.zig" }, .dependencies = &deps },
            );
        },
        .Xorg => xorg: {
            var deps: [1]std.build.ModuleDependency = .{common_dep};
            break :xorg b.createModule(
                .{ .source_file = .{ .path = "src/platform/unix/xorg/platform.zig" }, .dependencies = &deps },
            );
        },
        else => {
            @panic("Unsupported platform");
        },
    };

    const deps = [2]std.build.ModuleDependency{
        common_dep,
        std.build.ModuleDependency{ .name = "platform", .module = platform_dep },
    };

    const widow = b.addModule("widow", .{ .source_file = .{ .path = "src/main.zig" }, .dependencies = &deps });
    return widow;
}
