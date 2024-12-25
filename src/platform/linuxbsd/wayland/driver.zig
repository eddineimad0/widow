const std = @import("std");
const common = @import("common");
const libwayland = @import("wl/wl.zig");
const unix = common.unix;
const debug = std.debug;
const mem = std.mem;

const WlDriverError = error{ DisplayConnectionFailed, RegistryNotFound };

const WlRegistryError = error{
    BadState,
};

fn handleRegistryGlobal(
    data: *anyopaque,
    registry: *libwayland.wl_registry,
    name: u32,
    interface: [*:0]const u8,
    ver: u32,
) callconv(.C) void {
    _ = data;
    const r = WlRegistry.acquireSingleton();
    defer WlRegistry.releaseSingleton(r);
    debug.print("[+] Inteface: {s}, Version: {}, name: {}\n", .{ interface, ver, name });
    if (mem.orderZ(u8, interface, libwayland.wl_compositor_interface.name) == .eq) {
        r.compositor = @ptrCast(libwayland.wl_registry_bind(registry, name, libwayland.wl_compositor_interface, ver));
    }
}

fn handleRegistryGlobalRemove(
    data: *anyopaque,
    registry: *libwayland.wl_registry,
    name: u32,
) callconv(.C) void {
    _ = data;
    _ = registry;
    debug.print("[-] Removed: {}\n", .{name});
}

const registry_listener = libwayland.wl_registry_listener{
    .global = handleRegistryGlobal,
    .global_remove = handleRegistryGlobalRemove,
};

pub const WlRegistry = struct {
    compositor: ?*libwayland.wl_compositor,

    const Self = @This();
    var registry_guard: std.Thread.Mutex = std.Thread.Mutex{};
    var g_instance: Self = .{ .compositor = null };

    pub inline fn acquireSingleton() *Self {
        Self.registry_guard.lock();
        return &Self.g_instance;
    }

    pub inline fn releaseSingleton(s: *Self) void {
        _ = s;
        Self.registry_guard.unlock();
    }

    /// Checks for bad registry state.
    fn assertState(s: *const Self) WlRegistryError!void {
        if (s.compositor == null) {
            // compositor can't be null;
            return WlRegistryError.BadState;
        }
    }
};

/// Global constant, holds data for communicating
/// with wayland.
pub const WlDriver = struct {
    handles: struct {
        display: *libwayland.wl_display,
        registry: *libwayland.wl_registry,
    },
    wl_tag: [*:0]const u8,

    const Self = @This();
    var driver_guard: std.Thread.Mutex = std.Thread.Mutex{}; // ensures thread saftey when calling `initSingleton()`
    var g_init: bool = false;
    var g_instance: Self = .{
        .handles = undefined,
        .wl_tag = "WIDOW_WAYLAND_TAG",
    };

    pub fn initSingleton() (WlDriverError || WlRegistryError)!void {
        @setCold(true);

        Self.driver_guard.lock();
        defer driver_guard.unlock();
        if (!Self.g_init) {
            Self.g_instance.handles.display = libwayland.wl_display_connect(null) orelse
                return WlDriverError.DisplayConnectionFailed;

            Self.g_instance.handles.registry =
                libwayland.wl_display_get_registry(Self.g_instance.handles.display) orelse
                return WlDriverError.RegistryNotFound;

            _ = libwayland.wl_registry_add_listener(
                Self.g_instance.handles.registry,
                &registry_listener,
                null,
            );

            _ = libwayland.wl_display_roundtrip(Self.g_instance.handles.display);

            const r = WlRegistry.acquireSingleton();
            defer WlRegistry.releaseSingleton(r);
            try r.assertState();

            Self.g_init = true;
        }
    }

    pub inline fn getSingleton() *const Self {
        return &Self.g_instance;
    }
};
