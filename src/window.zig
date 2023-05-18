const std = @import("std");
const platform = @import("platform");
const common = @import("common");
const WidowContext = @import("./widow.zig").WidowContext;
const EventType = common.event.EventType;

pub const WindowBuilder = struct {
    window_config: common.window_data.WindowData,
    const Self = @This();

    pub fn init(title: []const u8, width: i32, height: i32) Self {
        std.debug.assert((width > 0 and height > 0));
        return Self{
            .window_config = common.window_data.WindowData{
                .title = title, // The window title.
                .video = common.video_mode.VideoMode{
                    .width = width,
                    .height = height,
                    .color_depth = 32,
                    .frequency = 60,
                },
                .position = null,
                .restore_point = null,
                .min_size = null,
                .max_size = null,
                .aspect_ratio = null,
                .fullscreen_mode = null,
                .flags = common.window_data.WindowFlags{
                    .is_visible = true,
                    .is_maximized = false,
                    .is_minimized = false,
                    .is_resizable = false,
                    .is_decorated = false,
                    .is_topmost = false,
                    .is_focused = false,
                    .cursor_in_client = false,
                    .accepts_raw_input = false,
                },
            },
        };
    }

    /// Returns the built window instance
    pub fn build(self: *const Self, cntxt: *WidowContext) !Window {
        std.debug.assert(cntxt.*.is_init);
        return Window{
            .impl = try platform.window_impl.WindowImpl.create(cntxt.allocator, cntxt.internals.?, self.window_config),
            .allocator = cntxt.allocator,
        };
    }

    /// Whether the window is visible(true) or hidden(false).
    /// if not set the `default` is visible.
    pub fn visibility(self: *Self, value: bool) *Self {
        self.window_config.flags.is_visible = value;
        return self;
    }

    /// The position of the window's top left corner.
    /// if not set the `default` is decided by the system.
    pub fn position(self: *Self, pos: common.geometry.WidowPoint2D) *Self {
        self.window_config.position = pos;
        return self;
    }

    /// Starts the window in the chosen fullscreen mode.
    /// by default the window isn't fullscreen.
    pub fn fullscreen(self: *Self, mode: common.window_data.FullScreenMode) *Self {
        self.window_config.fullscreen_mode = mode;
        return self;
    }

    /// Make the window resizable.
    /// if not set the window is not resizable by default.
    pub fn resizable(self: *Self) *Self {
        self.window_config.flags.is_resizable = true;
        return self;
    }

    /// Whether the window has a frame or not.
    /// if not set the `default` false.
    pub fn framless(self: *Self, value: bool) *Self {
        self.window_config.flags.is_decorated = value;
        return self;
    }

    /// Whether the window should stay on top even if it lose focus.
    /// if not set the `default` false.
    pub fn always_on_top(self: *Self, value: bool) *Self {
        self.window_config.flags.is_topmost = value;
        return self;
    }

    pub fn limit_size(self: *Self, min_size: common.geometry.WidowSize, max_size: common.geometry.WidowSize) *Self {
        self.window_config.min_size = min_size;
        self.window_config.max_size = max_size;
        return self;
    }
};

pub const Window = struct {
    impl: ?*platform.window_impl.WindowImpl,
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.impl.?.destroy(self.allocator);
        self.impl = null;
    }

    pub inline fn poll_event(self: *Self) ?common.event.Event {
        return self.impl.?.poll_event();
    }
};

test "window_creation" {
    const testing = std.testing;
    std.debug.print("Window struct size {}\n", .{@sizeOf(Window)});
    var context = try WidowContext.init(testing.allocator);
    defer context.deinit();
    var window = try WindowBuilder.init("creation_test", 800, 600).build(&context);
    defer window.deinit();

    event_loop: while (true) {
        const event = window.poll_event() orelse continue;
        switch (event) {
            EventType.WindowClose => {
                break :event_loop;
            },
            else => {
                continue :event_loop;
            },
        }
    }
}
