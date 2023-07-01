const std = @import("std");
const platform = @import("platform");
const window = @import("window.zig");
const common = @import("common");

pub const WidowContext = struct {
    platform_internals: platform.internals.Internals,
    monitors: platform.internals.MonitorStore,
    events_queue: common.event.EventQueue,
    joysticks: ?platform.joystick.JoystickSubSystem,
    allocator: std.mem.Allocator,

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
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn create(allocator: std.mem.Allocator) !*Self {
        const self = try allocator.create(Self);
        try platform.internals.Internals.setup(&self.platform_internals);
        self.monitors = try platform.internals.MonitorStore.init(allocator);
        self.events_queue = common.event.EventQueue.init(allocator);
        self.joysticks = null;
        self.allocator = allocator;
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
        if (self.joysticks) |*joys| {
            joys.deinit();
        }
        self.joysticks = null;
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

    /// returns the string contained inside the system clipboard.
    /// # Notes
    /// This function fails if the clipboard doesn't contain a proper unicode formatted string.
    /// On success the clipboard value is cached for future calls until the clipboard value change.
    /// The Caller shouldn't free the returned slice.
    pub inline fn clipboardText(self: *Self) ![]const u8 {
        return self.platform_internals.clipboardText(self.allocator);
    }

    /// Copys the given `text` to the system clipboard.
    /// # Parameters
    /// `text`: a slice of the data to be copied.
    pub inline fn setClipboardText(self: *Self, text: []const u8) !void {
        return self.platform_internals.setClipboardText(self.allocator, text);
    }

    /// Sets  the window's icon to the RGBA pixels data.
    /// # Notes
    /// This function expects non-premultiplied, 32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha.
    pub inline fn setWindowIcon(target: *window.Window, pixels: []const u8, width: i32, height: i32) !void {
        std.debug.assert(width > 0 and height > 0);
        std.debug.assert(pixels.len == (width * height * 4));
        try platform.internals.createIcon(target.impl, pixels, width, height);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Notes
    /// Unlike [`WidowContext.setWindowIcon`] this function also takes the cooridnates of the
    /// cursor hotspot which is the pixel that the system tracks to decide mouse click
    /// target, the `xhot` and `yhot` parameters represent the x and y coordinates
    /// of that pixel relative to the top left corner of the image, with the x axis directed
    /// to the right and the y axis directed to the bottom.
    /// This function expects non-premultiplied,32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha.
    pub inline fn setWindowCursor(target: *window.Window, pixels: []const u8, width: i32, height: i32, xhot: u32, yhot: u32) !void {
        std.debug.assert(width > 0 and height > 0);
        std.debug.assert(pixels.len == (width * height * 4));
        try platform.internals.createCursor(target.impl, pixels, width, height, xhot, yhot);
    }

    // /// Sets the Widow's cursor to an image from the system's standard cursors.
    // /// # Notes
    // /// The new image used by the cursor is loaded by the system therefore,
    // /// the appearance will vary between platforms.
    // pub fn setWindowStdCursor(target: *window.Window, shape: cursor.CursorShape) !void {
    //     try platform.internals.createStandardCursor(target.impl, shape);
    // }

    // Joystick interface.

    /// Initialize the joystick sub system.
    pub inline fn initJoystickSubSyst(self: *Self) !void {
        self.joysticks = try platform.joystick.JoystickSubSystem.init(self.allocator);
        // We assign it here so we can access it in the helper window procedure.
        self.platform_internals.setStatePointer(
            platform.internals.Internals.StatePointerMode.Joystick,
            @ptrCast(*anyopaque, &self.joysticks),
        );
        // First poll to detect joystick that are already present.
        self.joysticks.?.queryConnectedJoys();
    }

    // /// Adds a window refrence to the listener list of the joystick sub system.
    // /// # Note
    // /// Only windows registered as listener receives joystick/gamepad events
    // /// (connection,disconnection...).
    // /// Any window added should be removed with `removeJoystickListener` before
    // /// the window gets deinitialized.
    // pub inline fn addJoystickListener(self: *Self, window_ptr: *window.Window) !void {
    //     try self.joysticks.?.addListener(window_ptr.impl);
    // }
    //
    // /// Removes a window refrence from the listener list of the joystick sub system.
    // /// # Note
    // /// It's necessary for a window to be unregistered from the list before it gets
    // /// deinitialized, otherwise the joystick sub system would be working with invalid
    // /// pointers and causing Undefined behaviour.
    // pub inline fn removeJoystickListener(self: *Self, window_ptr: *window.Window) void {
    //     self.joysticks.?.removeListener(window_ptr.impl);
    // }
    //
    pub inline fn updateJoystick(self: *Self, joy_id: u8) void {
        _ = self.joysticks.?.updateJoystickState(joy_id);
    }

    pub inline fn pollJoyEvent(self: *Self, ev: *common.event.Event) bool {
        return self.joysticks.?.pollEvent(ev);
    }

    /// Returns a slice containing the name for the joystick that corresponds
    /// to the given joy_id.
    /// # Note
    /// If no joystick corresponds to the given id, or if the joystick
    /// is disconnected null is returned.
    /// The returned slice is managed by the library and the user shouldn't free it.
    /// The returned slice is only valid until the joystick is disconnected.
    pub inline fn joystickName(self: *const Self, joy_id: u8) ?[]const u8 {
        return self.joysticks.?.joystickName(joy_id);
    }

    /// Applys force rumble to the given joystick if it supports it.
    /// not all joysticks support this feature so the function returns
    /// true on success and false on fail.
    pub inline fn rumbleJoystick(self: *Self, joy_id: u8, magnitude: u16) bool {
        return self.joysticks.?.rumbleJoystick(joy_id, magnitude);
    }

    /// Returns the state of the joystick battery.
    /// # Note
    /// If the device is wired it returns `BatteryInfo.WirePowered`.
    /// If it fails to retrieve the battery state it returns `BatteryInfo.PowerUnknown`.
    pub inline fn joystickBattery(self: *Self, joy_id: u8) common.joystick.BatteryInfo {
        return self.joysticks.?.joystickBatteryInfo(joy_id);
    }
};

pub const WindowBuilder = struct {
    allocator: std.mem.Allocator,
    context_data: platform.window_impl.WidowData,
    window_attributes: common.window_data.WindowData,
    title_cache: []u8, // Keep a cache of the title so that the user can build multiple
    // windows without setting the same title.
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
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn init(
        title: []const u8,
        width: i32,
        height: i32,
        context: *WidowContext,
    ) !Self {
        std.debug.assert(width > 0 and height > 0);
        const new_title = try context.allocator.alloc(u8, title.len);
        std.mem.copyForwards(u8, new_title, title);
        return Self{
            .allocator = context.allocator,
            .context_data = platform.window_impl.WidowData{
                .monitors = &context.monitors,
                .events_queue = &context.events_queue,
            },
            .title_cache = new_title,
            // Defalut attributes
            .window_attributes = common.window_data.WindowData{
                .title = undefined, // we'll set this before building.
                .video = common.video_mode.VideoMode{
                    .width = width,
                    .height = height,
                    .color_depth = 32,
                    .frequency = 60,
                },
                .position = platform.window_impl.WindowImpl.WINDOW_DEFAULT_POSITION,
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
                    .is_decorated = true,
                    .is_topmost = false,
                    .is_focused = false,
                    .cursor_in_client = false,
                    .accepts_raw_input = false,
                    .allow_dpi_scaling = true,
                },
                .input = common.keyboard_and_mouse.InputState.init(),
            },
        };
    }

    // Frees allocated ressources.
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.title_cache);
        self.title_cache = undefined;
    }

    /// Creates and returns the built window instance.
    /// # Notes
    /// The user should deinitialize the Window instance when done.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn build(self: *Self) !window.Window {
        // Before building set the window attributes title.
        const title_copy = try self.allocator.alloc(u8, self.title_cache.len);
        std.mem.copyForwards(u8, title_copy, self.title_cache);
        self.window_attributes.title = title_copy;
        return window.Window{
            .impl = try platform.window_impl.WindowImpl.create(self.allocator, self.context_data, &self.window_attributes),
            .allocator = self.allocator,
        };
    }

    /// Set the window title.
    /// # Parameters
    /// `title`: the new title to replace the current one.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn withTitle(self: *Self, title: []const u8) !*Self {
        const new_title = try self.allocator.alloc(u8, title.len);
        std.mem.copyForwards(u8, new_title, title);
        if (self.title_cache) |ptr| {
            self.allocator.free(ptr);
        }
        self.title_cache = new_title;
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
        self.builder.window_attributes.video.width = width;
        self.builder.window_attributes.video.height = height;
        return self;
    }

    /// Whether the window is visible(true) or hidden(false).
    /// if not set the `default` is visible.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withVisibility(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_visible = value;
        return self;
    }

    /// The position of the window's top left corner.
    /// if not set the `default` is decided by the system.
    /// # Parameters
    /// `position`: the new position of the window.
    pub fn withPosition(self: *Self, position: *const geometry.WidowPoint2D) *Self {
        self.window_attributes.position = position.*;
        return self;
    }

    /// Starts the window in the chosen fullscreen mode.
    /// by default the window isn't fullscreen.
    /// # Parameters
    /// `mode`: the new `FullScreenMode` enum value.
    pub fn withFullscreen(self: *Self, mode: FullScreenMode) *Self {
        self.window_attributes.fullscreen_mode = mode;
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
    /// if not set the `default` false.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDecoration(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_decorated = value;
        return self;
    }

    /// Whether the window should stay on top even if it lose focus.
    /// if not set the `default` false.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withTopMost(self: *Self, value: bool) *Self {
        self.window_attributes.flags.is_topmost = value;
        return self;
    }

    /// Specify a minimum and maximum window size for resizable windows.
    /// no size limit is applied by `default`.
    /// # Paramters
    /// `min_size`: the minimum possible size for the window.
    /// `max_size`: the maximum possible size fo the window.
    pub fn withSizeLimit(self: *Self, min_size: *const geometry.WidowSize, max_size: *const geometry.WidowSize) *Self {
        self.window_attributes.min_size = min_size.*;
        self.window_attributes.max_size = max_size.*;
        return self;
    }

    /// Specify whether the window size should be scaled by the monitor Dpi .
    /// scaling is applied by `default`.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDPIScaling(self: *Self, value: bool) *Self {
        self.window_attributes.flags.allow_dpi_scaling = value;
        return self;
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
pub const FullScreenMode = common.window_data.FullScreenMode;
pub const Event = common.event.Event;
pub const EventType = common.event.EventType;
// TODO more restriction on the exports.
pub const input = common.keyboard_and_mouse;
pub const joystick = common.joystick;
