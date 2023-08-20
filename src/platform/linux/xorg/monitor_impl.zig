const std = @import("std");
const libx11 = @import("x11_defs");
const common = @import("common");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const VideoMode = common.video_mode.VideoMode;

/// Construct a Vector with all currently connected monitors.
pub fn pollMonitors(allocator: Allocator) !ArrayList(MonitorImpl) {
    _ = allocator;
}

/// Returns a Vector containing all the possible video modes
/// for the given display adapter.
fn pollVideoModes(allocator: Allocator, adapter_name: []const u16, is_pruned: bool) !ArrayList(VideoMode) {
    _ = allocator;
    _ = adapter_name;
    _ = is_pruned;
}

/// Returns the dpi value for the given monitor.
/// # Note
/// This function is a last resort to get the dpi value for a window.
pub fn monitorDPI() u32 {}

/// Encapsulate the necessary infos for a monitor.
pub const MonitorImpl = struct {
    handle: libx11.Display, // System handle to the monitor.
    name: []u8, // Name assigned to the monitor
    adapter: [32]u16, // Wide encoded Name of the display adapter(gpu) used by the monitor.
    mode_changed: bool, // Set true if the original video mode of the monitor was changed.
    modes: ArrayList(VideoMode), // All the VideoModes that the monitor support.
    // window: ?*WindowImpl, // A pointer to the window occupying(fullscreen) the monitor.

    const Self = @This();

    pub fn init(
        handle: libx11.Display,
        adapter: [32]u16,
        name: []u8,
        modes: ArrayList(VideoMode),
    ) Self {
        return Self{
            .handle = handle,
            .adapter = adapter,
            .name = name,
            .modes = modes,
            .mode_changed = false,
        };
    }

    pub fn deinit(self: *Self) void {
        // Hack since both self.name and self.modes
        // use the same allocator.
        self.modes.allocator.free(self.name);
        // self.restoreOrignalVideo();
        self.modes.deinit();
    }

    /// Compares 2 monitors.
    /// # Note
    /// We will need this when checking which monitor was disconnected.
    pub inline fn equals(self: *const Self, other: *const Self) bool {
        // Windows might reassing the same handle to a new monitor so make sure
        // to compare the name too
        return (self.handle == other.handle);
    }
};
