const std = @import("std");
const mem = std.mem;

const DisplayProtocol = enum {
    Win32,
    Xorg,
    Wayland,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var display_target = b.option(
        DisplayProtocol,
        "widow_display_protocol",
        "Specify the target display protocol to compile for.",
    );

    const log_platform_events = b.option(
        bool,
        "widow_log_platform_events",
        "Print platform events messages.",
    ) orelse
        false;

    const win32_wndclass_name = b.option(
        []const u8,
        "widow_win32_wndclass_name",
        "Specify a name for the win32 WNDClass",
    ) orelse "WIDOW_CLASS";

    const options = b.addOptions();
    options.addOption(bool, "LOG_PLATFORM_EVENTS", log_platform_events);
    options.addOption([]const u8, "WIN32_WNDCLASS_NAME", win32_wndclass_name);

    if (display_target) |t| {
        if (!isDisplayTargetValid(&target, t)) {
            @panic("The specified Os target and display_protocol combination isn't supported.");
        }
    } else {
        display_target = detectDispalyTarget(b.allocator, &target);
    }

    const widow = prepareWidowModule(b, display_target.?, options);

    const example_step = b.step("examples", "Compile examples");
    const examples = [_][]const u8{
        "simple_window",
        // "playing_with_inputs",
        // "cursor_and_icon",
        // "xorg_basic",
        // "gl_triangle",
    };

    for (examples) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = .{ .path = b.fmt("examples/{s}.zig", .{example_name}) },
            .target = target,
            .optimize = optimize,
        });
        // example.root_module.addOptions("build_options", options);
        example.root_module.addImport("widow", widow);
        example.linkLibC();
        const install_step = b.addInstallArtifact(example, .{});
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_step.step);
    }

    const testing_step = b.step("test", "Temp test step");
    const test_step = b.addTest(.{
        .root_source_file = .{ .path = "src/platform/win32/platform.zig" },
        .target = target,
        .optimize = optimize,
    });
    const zigwin32 = b.createModule(.{
        .root_source_file = .{ .path = "libs/zigwin32/win32.zig" },
    });
    const common = b.createModule(.{
        .root_source_file = .{ .path = "src/common/common.zig" },
    });
    test_step.root_module.addImport("zigwin32", zigwin32);
    test_step.root_module.addImport("common", common);
    const test_run = b.addRunArtifact(test_step);
    testing_step.dependOn(&test_run.step);
}

fn isDisplayTargetValid(
    target: *const std.Build.ResolvedTarget,
    protocol: DisplayProtocol,
) bool {
    return switch (target.result.os.tag) {
        .windows => protocol == .Win32,
        .linux, .freebsd, .netbsd => (protocol == .Xorg or protocol == .Wayland),
        else => false,
    };
}

fn detectDispalyTarget(allocator: std.mem.Allocator, target: *const std.Build.ResolvedTarget) DisplayProtocol {
    const SESSION_TYPE_X11: [*:0]const u8 = "x11";
    const SESSION_TYPE_WAYLAND: [*:0]const u8 = "wayland";

    return switch (target.result.os.tag) {
        .windows => .Win32,
        .linux, .freebsd, .netbsd => unix: {
            // need to determine what display server is being used
            const display_session_type = std.process.getEnvVarOwned(
                allocator,
                "XDG_SESSION_TYPE",
            ) catch @panic("Couldn't determine display server type\n");

            defer allocator.free(display_session_type);

            if (display_session_type.len == 0) {
                @panic("XDG_SESSION_TYPE env variable not set");
            }

            if (mem.eql(u8, display_session_type, mem.span(SESSION_TYPE_X11))) {
                break :unix .Xorg;
            } else if (mem.eql(u8, display_session_type, mem.span(SESSION_TYPE_WAYLAND))) {
                break :unix .Wayland;
            } else {
                @panic("Unsupported unix display server");
            }
        },
        else => @panic("Unsupported Target"),
    };
}

fn prepareWidowModule(
    b: *std.Build,
    target: DisplayProtocol,
    opts: *std.Build.Step.Options,
) *std.Build.Module {
    const common_module = b.createModule(.{
        .root_source_file = .{ .path = "src/common/common.zig" },
    });

    const common_dep = std.Build.Module.Import{ .name = "common", .module = common_module };

    const platform_module: *std.Build.Module = switch (target) {
        .Win32 => win32: {
            const zigwin32 = b.createModule(.{
                .root_source_file = .{ .path = "libs/zigwin32/win32.zig" },
            });
            break :win32 b.createModule(
                .{
                    .root_source_file = .{ .path = "src/platform/win32/platform.zig" },
                    .imports = &.{
                        common_dep,
                        .{ .name = "zigwin32", .module = zigwin32 },
                    },
                },
            );
        },
        .Xorg => b.createModule(
            .{
                .root_source_file = .{
                    .path = "src/platform/linuxbsd/xorg/platform.zig",
                },
                .imports = &.{common_dep},
            },
        ),
        else => {
            @panic("Unsupported platform");
        },
    };

    platform_module.addOptions("build-options", opts);
    const widow = b.addModule("widow", .{
        .root_source_file = .{ .path = "src/main.zig" },
        .imports = &.{
            common_dep,
            .{ .name = "platform", .module = platform_module },
        },
    });

    return widow;
}
