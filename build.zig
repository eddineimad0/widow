const std = @import("std");
const mem = std.mem;

const DisplayProtocol = enum {
    Win32,
    Xorg,
    Wayland, // yeah this isn't supported yet
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var display_target = b.option(
        DisplayProtocol,
        "widow_display_protocol",
        "Specify the target display protocol to compile for.",
    );

    if (display_target) |t| {
        if (!isDisplayTargetValid(&target, t)) {
            @panic("The specified Os target and display_protocol combination isn't supported.");
        }
    } else {
        display_target = detectDispalyTarget(b.allocator, &target);
    }

    const widow = createWidowModule(
        b,
        display_target.?,
        prepareCompileOptions(b),
    );

    const example_step = b.step("examples", "Compile examples");
    const examples = [_][]const u8{
        "simple_window",
        "cursor_and_icon",
        "events_loop",
        "gl_triangle",
    };

    for (examples) |example_name| {
        const example = b.addExecutable(.{
            .name = example_name,
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{example_name})),
            .target = target,
            .optimize = optimize,
        });

        example.root_module.addImport("widow", widow);
        if (mem.eql(u8, example_name, "gl_triangle")) {
            const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
                .api = .gl,
                .version = .@"4.1",
                .profile = .core,
                .extensions = &.{ .ARB_clip_control, .NV_scissor_exclusive },
            });

            example.root_module.addImport("gl", gl_bindings);
            if (target.result.os.tag == .windows) {
                example.dll_export_fns = true;
            }
        }
        if (target.result.os.tag == .linux) {
            example.linkLibC();
        }

        const install_step = b.addInstallArtifact(example, .{});
        example_step.dependOn(&example.step);
        example_step.dependOn(&install_step.step);
    }
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

fn detectDispalyTarget(
    allocator: std.mem.Allocator,
    target: *const std.Build.ResolvedTarget,
) DisplayProtocol {
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
                break :unix .Xorg;
            } else {
                @panic("Unsupported unix display server");
            }
        },
        else => @panic("Unsupported Target"),
    };
}

fn createWidowModule(
    b: *std.Build,
    display_target: DisplayProtocol,
    opts: *std.Build.Step.Options,
) *std.Build.Module {
    const gl_mod = b.createModule(.{
        .root_source_file = b.path("src/opengl/gl.zig"),
    });

    const common_mod = b.createModule(.{
        .root_source_file = b.path("src/common/common.zig"),
        .imports = &.{
            .{ .name = "opengl", .module = gl_mod },
        },
    });

    const platform_mod: *std.Build.Module = switch (display_target) {
        .Win32 => win32: {
            break :win32 b.createModule(
                .{
                    .root_source_file = b.path("src/platform/windows/platform.zig"),
                    .imports = &.{
                        .{ .name = "opengl", .module = gl_mod },
                        .{ .name = "common", .module = common_mod },
                    },
                },
            );
        },
        .Xorg => b.createModule(
            .{
                .root_source_file = b.path("src/platform/linuxbsd/xorg/platform.zig"),

                .imports = &.{
                    .{ .name = "opengl", .module = gl_mod },
                    .{ .name = "common", .module = common_mod },
                },
            },
        ),
        else => {
            @panic("Unsupported platform");
        },
    };

    platform_mod.addOptions("build-options", opts);

    const widow = b.addModule("widow", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "common", .module = common_mod },
            .{ .name = "platform", .module = platform_mod },
            .{ .name = "opengl", .module = gl_mod },
        },
    });

    return widow;
}

fn prepareCompileOptions(b: *std.Build) *std.Build.Step.Options {
    // Common options
    const log_platform_events = b.option(
        bool,
        "widow_log_platform_events",
        "Print platform events messages.",
    ) orelse
        false;

    // Win32 options
    const win32_wndclass_name = b.option(
        []const u8,
        "widow_win32_wndclass_name",
        "Specify a name for the win32 WNDClass",
    ) orelse "WIDOW_CLASS";

    const win32_icon_res_name = b.option(
        []const u8,
        "widow_win32_icon_res_name",
        "Specify the name of the ressource icon to use on windows os",
    );

    // Xorg options
    const x11_res_name = b.option(
        []const u8,
        "widow_x11_res_name",
        "Specify the x11 application name",
    ) orelse "WIDOW_APPLICATION";

    const x11_class_name = b.option(
        []const u8,
        "widow_x11_class_name",
        "Specify the x11 application class",
    ) orelse "WIDOW_CLASS";

    const options = b.addOptions();
    options.addOption(bool, "LOG_PLATFORM_EVENTS", log_platform_events);
    options.addOption([]const u8, "WIN32_WNDCLASS_NAME", win32_wndclass_name);
    options.addOption(?[]const u8, "WIN32_ICON_RES_NAME", win32_icon_res_name);
    options.addOption([]const u8, "X11_CLASS_NAME", x11_class_name);
    options.addOption([]const u8, "X11_RES_NAME", x11_res_name);

    return options;
}
