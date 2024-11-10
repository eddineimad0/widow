const std = @import("std");
const common = @import("common");
const libwayland = @import("wl/wl.zig");
const unix = common.unix;
const debug = std.debug;


const WlDriverError = error{
    DisplayConnectionFailed,
};

fn handleRegistryGlobal(data:*anyopaque,registry:*libwayland.wl_registry,name:u32,interface:[*:0]const u8,ver:u32,) callconv(.C) void {
    _ = data;
    _ = registry;
    debug.print("[+] Inteface: {s}, Version: {}, name: {}\n", .{interface,ver,name});
}

fn handleRegistryGlobalRemove(data:*anyopaque,registry:*libwayland.wl_registry,name:u32,) callconv(.C) void{
    _ = data;
    _ = registry;
    debug.print("[-] Removed: {}\n", .{name});
}

const registry_listener = libwayland.wl_registry_listener{
    .global = handleRegistryGlobal,
    .global_remove = handleRegistryGlobalRemove,
};

pub const WlDriver = struct {
     handles:struct {
        display:*libwayland.wl_display,
        registry:*libwayland.wl_registry,
     },

    const Self = @This();
    var driver_guard: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;
    var g_instance: Self = .{
        .handles = undefined,
    };

    pub fn initSingleton() WlDriverError!void {
        @setCold(true);

        Self.driver_guard.lock();
        defer driver_guard.unlock();
        if(!Self.g_init){
            Self.g_instance.handles.display = libwayland.wl_display_connect(null) orelse
                return WlDriverError.DisplayConnectionFailed;

            Self.g_instance.handles.registry = libwayland.wl_display_get_registry(Self.g_instance.handles.display);

            _ = libwayland.wl_registry_add_listener(Self.g_instance.handles.registry, &registry_listener, null);

            _ = libwayland.wl_display_roundtrip(Self.g_instance.handles.display);
        }
    }
};
