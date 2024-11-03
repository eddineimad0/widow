const std = @import("std");
const common = @import("common");
const libwayland = @import("wl/wl.zig");
const unix = common.unix;


const WlDriverError = error{
    DisplayConnectionFailed,
};

pub const WlDriver = struct {
     handles:struct {
        display:*libwayland.wl_display,
     },

    const Self = @This();
    var driver_guard: std.Thread.Mutex = std.Thread.Mutex{};
    var g_init: bool = false;
    var g_instance: Self = .{};

    pub fn initSingleton() void {
        @setCold(true);

        Self.driver_guard.lock();
        defer driver_guard.unlock();
        if(!Self.g_init){
            Self.g_instance.handles.display = libwayland.wl_display_connect(null) orelse
                return WlDriverError.DisplayConnectionFailed;
        }
    }
};
