const std = @import("std");
const platform = @import("platform");
const Window = @import("window.zig").Window;
const common = @import("common");

pub const WidowContext = struct {
    platform_internals: platform.internals.Internals,
    monitors: platform.internals.MonitorStore,
    events_queue: common.event.EventQueue,
    joystick_sys: ?platform.joystick.JoystickSubSystemImpl,
    allocator: std.mem.Allocator,
    next_window_id: u32, // keeps track of assigned ids.

    const Self = @This();

    /// Creates an instance of the WidowContext.
    /// # Parameters
    /// `allocator`: the memory allocator to be used by the libaray.
    /// # Notes
    /// An instance of the WidowContext is necessary to use
    /// the library, and is required to initialize a window
    /// instance.
    /// User should deinitialize the instance once done,
    /// to free the allocated ressources.
    /// There can only be one instance at a time trying
    /// to initialize more would throw an error.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation failure.
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        try platform.internals.Internals.setup(&self.platform_internals);
        self.monitors = try platform.internals.MonitorStore.init(allocator);
        self.events_queue = common.event.EventQueue.init(allocator);
        self.joystick_sys = null;
        self.allocator = allocator;
        self.next_window_id = 0;
        // The monitors store will recieve updates through the helper window
        self.platform_internals.setStatePointer(
            platform.internals.Internals.StatePointerMode.Monitor,
            @ptrCast(*anyopaque, &self.monitors),
        );
        return self;
    }

    /// Free allocated ressources.
    /// # Parameters
    /// `allocator`: the memory allocator used during initialization.
    pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
        if (self.joystick_sys) |*jss| {
            jss.deinit();
        }
        self.joystick_sys = null;
        self.monitors.deinit();
        self.platform_internals.deinit(self.allocator);
        allocator.destroy(self);
    }

    /// Retrieves an event fromt the event queue,
    /// returns false if the queue is empty.
    /// # Parameters
    /// `event`: pointer to an event variable to be populated.
    pub inline fn pollEvents(self: *Self, event: *common.event.Event) bool {
        return self.events_queue.popEvent(event);
    }

    /// Returns the next available window ID.
    fn nextWindowId(self: *Self) u32 {
        self.next_window_id += 1;
        return self.next_window_id;
    }

    /// Returns the current text content of the system clipboard.
    /// # Notes
    /// This function fails if the clipboard doesn't contain a proper unicode formatted string.
    /// On success the clipboard value is cached for future calls until the clipboard value change.
    /// The Caller doesn't own the returned slice and shouldn't free it.
    pub inline fn clipboardText(self: *Self) ![]const u8 {
        return self.platform_internals.clipboardText(self.allocator);
    }

    /// Copys the given `text` to the system clipboard.
    /// # Parameters
    /// `text`: a slice of the data to be copied.
    pub inline fn setClipboardText(self: *Self, text: []const u8) !void {
        return self.platform_internals.setClipboardText(self.allocator, text);
    }

    /// Initializes and returns a shallow copy of the library's JoystickSubSystem.
    /// once initialized the JoystickSubSystem lives as long as the WidowContext instance,
    /// so subsequent calls to this function will won't do any init logic.
    pub inline fn joystickSubSyst(self: *Self) !JoystickSubSystem {
        if (self.joystick_sys == null) {
            self.joystick_sys = try platform.joystick.JoystickSubSystemImpl.init(self.allocator, &self.events_queue);
            // We assign it here so we can access it in the helper window procedure.
            self.platform_internals.setStatePointer(
                platform.internals.Internals.StatePointerMode.Joystick,
                @ptrCast(*anyopaque, &self.joystick_sys),
            );
            // First poll to detect joystick that are already present.
            self.joystick_sys.?.queryConnectedJoys();
        }

        return JoystickSubSystem{ .impl = &self.joystick_sys.? };
    }
};

pub const WindowBuilder = struct {
    allocator: std.mem.Allocator,
    context: *WidowContext,
    window_attributes: common.window_data.WindowData,
    title: []u8,
    const Self = @This();

    /// Creates a window builder instance.
    /// The window builder wraps the creation attributes of the window,
    /// and the functions necessary to changes those attributes.
    /// # Parameters
    /// `title`: the title to be displayed in the window's caption bar.
    /// `width`: intial width of the window.
    /// `height`: intial height of the window.
    /// `context`: a pointer to the WidowContext instance.
    /// # Notes
    /// The context parameter should point to an initialzed WidowContext instance that lives
    /// as long as the window, i.e destroying the WidowContext instance before the window is destroyed
    /// causes undefined behaviour.
    /// Call `deinit()` when done using the WindowBuilder.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation Failure.
    pub fn init(
        title: []const u8,
        width: i32,
        height: i32,
        context: *WidowContext,
    ) !Self {
        std.debug.assert(width > 0 and height > 0);
        // can't be sure of the title's lifetime so copy it first.
        const new_title = try context.allocator.alloc(u8, title.len);
        std.mem.copyForwards(u8, new_title, title);
        return Self{
            .allocator = context.allocator,
            .context = context,
            .title = new_title,
            // Defalut attributes
            .window_attributes = common.window_data.WindowData{
                .id = 0,
                .client_area = common.geometry.WidowArea.init(
                    platform.window_impl.WindowImpl.WINDOW_DEFAULT_POSITION.x,
                    platform.window_impl.WindowImpl.WINDOW_DEFAULT_POSITION.y,
                    width,
                    height,
                ),
                .min_size = null,
                .max_size = null,
                .aspect_ratio = null,
                .flags = common.window_data.WindowFlags{
                    .is_visible = true,
                    .is_maximized = false,
                    .is_minimized = false,
                    .is_resizable = false,
                    .is_decorated = true,
                    .is_topmost = false,
                    .is_focused = false,
                    .is_fullscreen = false,
                    .cursor_in_client = false,
                    .allow_dpi_scaling = false,
                },
                .input = common.keyboard_and_mouse.InputState.init(),
            },
        };
    }

    // Frees allocated ressources.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title);
        self.title = undefined;
    }

    /// Creates and returns the built window instance.
    /// # Notes
    /// The user should deinitialize the Window instance when done.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn build(self: *Self) !Window {
        // First window has id of 1,
        self.window_attributes.id = self.context.nextWindowId();
        const window = Window.init(
            self.allocator,
            self.title,
            &self.window_attributes,
            platform.window_impl.WidowProps{
                .monitors = &self.context.monitors,
                .events_queue = &self.context.events_queue,
            },
        );
        return window;
    }

    /// Set the window title.
    /// # Parameters
    /// `title`: the new title to replace the current one.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn withTitle(self: *Self, title: []const u8) !*Self {
        const new_title = try self.allocator.alloc(u8, title.len);
        std.mem.copyForwards(u8, new_title, title);
        self.allocator.free(self.title);
        self.title = new_title;
        return self;
    }

    /// Set the window width and height.
    /// # Parameters
    /// `width`: the new width to replace the current one.
    /// `height`: the new height to replace the current one.
    /// # Notes
    /// If the window is DPI scaled the final width and height
    /// might be diffrent in window mode but the video mode for
    /// exclusive fullscreen mode retain the given widht and height.
    pub fn withSize(self: *Self, width: i32, height: i32) *Self {
        std.debug.assert(width > 0 and height > 0);
        self.window_attributes.client_area.size.width = width;
        self.window_attributes.client_area.size.height = height;
        return self;
    }

    /// Whether the window is visible(true) or hidden(false).
    /// if not set the default is visible.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withVisibility(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_visible = value;
        return self;
    }

    /// Choose the position of the client(content area)'s top left corner.
    /// if not set the default is decided by the system.
    /// # Parameters
    /// `x`: the y coordinates of the client's top left corner.
    /// `y`: the y coordinates of the client's top left corner.
    pub fn withPosition(self: *Self, x: i32, y: i32) *Self {
        self.window_attributes.client_area.top_left.x = x;
        self.window_attributes.client_area.top_left.y = y;
        return self;
    }

    /// Starts the window in the chosen fullscreen mode.
    /// by default the window isn't fullscreen.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withFullscreen(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_fullscreen = value;
        return self;
    }

    /// Make the window resizable.
    /// the window is not resizable by default.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withResize(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_resizable = value;
        return self;
    }

    /// Whether the window has a frame or not.
    /// if not set the default is false.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDecoration(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_decorated = value;
        return self;
    }

    /// Whether the window should stay on top even if it lose focus.
    /// if not set the default is false.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withTopMost(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_topmost = value;
        return self;
    }

    /// Specify a minimum and maximum window size for resizable windows.
    /// no size limit is applied by default.
    /// # Paramters
    /// `min_size`: the minimum possible size for the window.
    /// `max_size`: the maximum possible size fo the window.
    pub fn withSizeLimit(self: *Self, min_size: *const geometry.WidowSize, max_size: *const geometry.WidowSize) *Self {
        self.window_attributes.min_size = min_size.*;
        self.window_attributes.max_size = max_size.*;
        return self;
    }

    /// Specify whether the window size should be scaled by the monitor Dpi .
    /// scaling is not applied by default.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDPIScaling(self: *Self, value: bool) *Self {
        self.window_attributes.flags.allow_dpi_scaling = value;
        return self;
    }
};

pub const JoystickSubSystem = struct {
    impl: *platform.joystick.JoystickSubSystemImpl,
    const Self = @This();

    /// Returns the maximum number of supported joysticks by the library.
    pub inline fn joysticksMaxCount() comptime_int {
        return joystick.JOYSTICK_MAX_COUNT;
    }

    /// Returns the maximum number of currently connected joysticks.
    pub inline fn joysticksCount(self: *const Self) u8 {
        return self.impl.countConnected();
    }

    /// Check for any new inputs by the device the corresponds to the joy_id,
    /// and sends the appropriate events to the Main event queue.
    /// # Parameters
    /// `joy_id`: the id of the targeted joystick.
    /// # Notes
    /// If no joystick corresponds to the given id, or if the joystick
    /// it returns immediately.
    pub inline fn updateJoyState(self: *Self, joy_id: u8) void {
        self.impl.updateJoystickState(joy_id);
    }

    /// Returns a slice containing the name for the joystick that corresponds
    /// to the given joy_id.
    /// # Parameters
    /// `joy_id`: the id of the targeted joystick.
    /// # Notes
    /// If no joystick corresponds to the given id, or if the joystick
    /// is disconnected null is returned.
    /// The returned slice is managed by the library and the user shouldn't free it.
    /// The returned slice is only valid until the joystick is disconnected.
    pub inline fn joystickName(self: *const Self, joy_id: u8) ?[]const u8 {
        return self.impl.joystickName(joy_id);
    }

    /// Applys force rumble to the given joystick if it supports it.
    /// not all joysticks support this feature so the function returns
    /// true on success and false on fail.
    /// # Parameters
    /// `joy_id`: the id of the targeted joystick.
    /// `magnitude`: the rumble magnitude, a value of 0 means no rumble.
    pub inline fn rumbleJoystick(self: *Self, joy_id: u8, magnitude: u16) bool {
        return self.impl.rumbleJoystick(joy_id, magnitude);
    }

    /// Returns the state of the joystick battery.
    /// # Parameters
    /// `joy_id`: the id of the targeted joystick.
    /// # Notes
    /// If the device is wired it returns `BatteryInfo.Wired`.
    /// If it fails to retrieve the battery state it returns `BatteryInfo.PowerUnknown`.
    pub inline fn joystickBattery(self: *Self, joy_id: u8) common.joystick.BatteryInfo {
        return self.impl.joystickBatteryInfo(joy_id);
    }
};

test "Widow.init" {
    const testing = std.testing;
    var cntxt = try WidowContext.create(testing.allocator);
    defer cntxt.destroy(testing.allocator);
}

test "widow.clipboardText" {
    const testing = std.testing;
    var cntxt = try WidowContext.create(testing.allocator);
    defer cntxt.destroy(testing.allocator);
    const string1 = "Clipboard Test String👌.";
    const string2 = "Maybe widow is a terrible name for the library.";
    try cntxt.setClipboardText(string1);
    const copied_string = try cntxt.clipboardText();
    std.debug.print("\n 1st clipboard value:{s}\n string length:{}\n", .{ copied_string, copied_string.len });
    const copied_string2 = try cntxt.clipboardText();
    std.debug.print("\n 2nd clipboard value:{s}\n string length:{}\n", .{ copied_string2, copied_string2.len });
    try testing.expect(copied_string.ptr == copied_string2.ptr); // no reallocation if the clipboard value didn't change.
    try cntxt.setClipboardText(string2);
    const copied_string3 = try cntxt.clipboardText();
    try testing.expect(copied_string3.ptr != copied_string.ptr);
    std.debug.print("\n 3rd clipboard value:{s}\n string length:{}\n", .{ copied_string3, copied_string2.len });
}

// Exports
pub const geometry = common.geometry;
pub const cursor = common.cursor;
pub const VideoMode = common.video_mode.VideoMode;
pub const Event = common.event.Event;
pub const EventType = common.event.EventType;
pub const keyboard_and_mouse = common.keyboard_and_mouse;
pub const joystick = common.joystick;
