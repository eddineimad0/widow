const std = @import("std");
const platform = @import("platform");
const common = @import("common");
const WidowContext = @import("./widow.zig").WidowContext;
const EventType = common.event.EventType;

pub const WindowBuilder = struct {
    platform_internals: *platform.internals.Internals,
    allocator: std.mem.Allocator,
    window_config: common.window_data.WindowData,
    const Self = @This();

    /// Creates a window builder instance.
    /// The window builder wraps the creation attributes of the window,
    /// and the functions necessary to changes those attributes.
    /// # Parameter
    /// `title`: the title to be displayed in the window's caption bar.
    /// `width`: intial width of the window.
    /// `height`: intial height of the window.
    /// `context`: a pointer to the WidowContext instance.
    /// # Note
    /// The context parameter should point to an initialzed WidowContext instance that lives
    /// as long as the window, i.e destroying the WidowContext instance before the window is destroyed
    /// causes undefined behaviour.
    pub fn init(title: []const u8, width: i32, height: i32, context: *WidowContext) !Self {
        std.debug.assert(context.internals != undefined);
        std.debug.assert((width > 0 and height > 0));
        const title_str = try context.allocator.alloc(u8, title.len);
        std.mem.copy(u8, title_str, title);
        return Self{
            .platform_internals = context.internals,
            .allocator = context.allocator,
            .window_config = common.window_data.WindowData{ .title = title_str, .video = common.video_mode.VideoMode{
                .width = width,
                .height = height,
                .color_depth = 32,
                .frequency = 60,
            }, .position = platform.window_impl.WindowImpl.WINDOW_DEFAULT_POSITION, .restore_point = null, .min_size = null, .max_size = null, .aspect_ratio = null, .fullscreen_mode = null, .flags = common.window_data.WindowFlags{
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
            }, .input = common.keyboard_and_mouse.InputState.init() },
        };
    }

    /// Creates and returns the built window instance.
    /// # Note
    /// The user should deinitialize the Window instance when done.
    pub fn build(self: *const Self) !Window {
        return Window{
            .impl = try platform.window_impl.WindowImpl.create(self.allocator, self.platform_internals, self.window_config),
            .allocator = self.allocator,
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
    pub fn position(self: *Self, pos: *const common.geometry.WidowPoint2D) *Self {
        self.window_config.position = pos.*;
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
    pub fn decorated(self: *Self, value: bool) *Self {
        self.window_config.flags.is_decorated = value;
        return self;
    }

    /// Whether the window should stay on top even if it lose focus.
    /// if not set the `default` false.
    pub fn alwaysOnTop(self: *Self, value: bool) *Self {
        self.window_config.flags.is_topmost = value;
        return self;
    }

    /// Specify a minimum and maximum window size for resizable windows.
    /// no size limit is applied by `default`.
    pub fn sizeLimit(self: *Self, min_size: *const common.geometry.WidowSize, max_size: *const common.geometry.WidowSize) *Self {
        self.window_config.min_size = min_size.*;
        self.window_config.max_size = max_size.*;
        return self;
    }

    /// Specify whether the window size should be scaled by the monitor Dpi .
    /// scaling is applied by `default`.
    pub fn dpiScaled(self: *Self, value: bool) *Self {
        self.window_config.allow_dpi_scaling = value;
        return self;
    }
};

pub const Window = struct {
    impl: *platform.window_impl.WindowImpl,
    allocator: std.mem.Allocator,
    const Self = @This();

    /// Destroys the window and releases all allocated ressources.
    pub fn deinit(self: *Self) void {
        self.impl.destroy(self.allocator);
        self.impl = undefined;
    }

    /// Poll for any events are currently in the queue, and copies
    /// the first one it find to the `event` parameter.
    /// Returns true if any event was copied to the event parametre.
    pub inline fn pollEvent(self: *Self, event: *common.event.Event) bool {
        return self.impl.pollEvent(event);
    }

    /// This function puts the calling thread to sleep
    /// until an event msg is posted by the system.
    /// from there it acts exactly as [`Window.pollEvent'].
    ///
    /// # Note
    /// An event is guranteed to be copied.
    pub inline fn waitEvent(self: *Self, event: *common.event.Event) void {
        self.impl.waitEvent(event);
    }

    /// This function puts the calling thread to sleep
    /// until an event msg is posted by the system,
    /// or timeout period elapses.
    /// from there it acts exactly as [`Window.pollEvent'].
    /// Returns true if any event was copied to the event parametre.
    ///
    /// # Note
    /// If the timeout is 0 the function will return immediately.
    /// The timeout parameter is specified in milliseconds.
    pub inline fn waitEventTimeout(self: *Self, event: *common.event.Event, timeout: u32) bool {
        std.debug.assert(timeout > 0);
        return self.impl.waitEventTimeout(timeout, event);
    }

    /// Posts the [`EventType.WindowClose`] event to the window's event loop.
    /// # Note
    /// This function can be used to signal a desire to exit the event loop,
    /// from the code.
    /// This function doesn't close the window or perform any cleanup logic,
    /// the window will still be visible untill the variable is deinitialized.
    /// Events posted before a call to this function will still be processed
    /// first.
    pub inline fn queueCloseEvent(self: *Self) void {
        const event = common.event.createCloseEvent();
        self.impl.queueEvent(&event);
    }

    /// Returns the position of the top-left corner of the window's client area,
    /// relative to the virtual desktop's top-left corner.
    /// # Note
    /// The client area is the content of the window, excluding the title bar and borders.
    /// The virutal desktop is the desktop created by combining all connected monitors
    /// where each monitor displays a portion of it.
    /// The virtual desktop's top-left in a single monitor setup is the same as that monitor's
    /// top left-corner, in a multi-monitor setup it depends on the setup's configuration.
    pub inline fn clientPosition(self: *const Self) common.geometry.WidowPoint2D {
        return platform.window_impl.windowClientPosition(self.impl.handle);
    }

    /// Change the position of the window's top-left corner,
    /// to the newly specified x and y.
    /// # Note
    /// The `x` and `y` parameters should be in virutal desktop coordinates.
    /// if the window is maximized it is automatically restored.
    /// I fail to think of any situation where this should be used.
    pub inline fn setPosition(self: *const Self, x: i32, y: i32) void {
        self.impl.setPosition(x, y);
    }

    /// Returns the position of the top-left corner of the window,
    /// relative to the virtual desktop's top-left corner.
    /// # Note
    /// The virutal desktop is the desktop created by combining all connected monitors
    /// where each monitor displays a portion of it.
    /// The virtual desktop's top-left in a single monitor setup is the same as that monitor's
    /// top left-corner, in a multi-monitor setup it depends on the setup's configuration.
    pub inline fn position(self: *const Self) common.geometry.WidowPoint2D {
        return self.impl.position();
    }

    /// Returns the size in physical pixels of the window's client area.
    /// # Note
    /// The client area is the content of the window, excluding the title bar and borders.
    /// The logical size which is the same as the size specified during window creation,
    /// can be aquired by dividing the Physical size with the content scale factor
    /// returned by [`Window::contentScale`].
    pub inline fn clientSize(self: *const Self) common.geometry.WidowSize {
        return platform.window_impl.clientSize(self.impl.handle);
    }

    /// Returns the size in physical pixels of the entire window.
    pub inline fn size(self: *const Self) common.geometry.WidowSize {
        return platform.window_impl.windowSize(self.impl.handle);
    }

    /// Changes the client size of the window.
    /// The specifed size should be in logical pixels i.e no need to scale it.
    /// width must be > 0 and height must be > 0.
    /// # Note
    /// For a full screen window this function updates the resolution
    /// and switches to the video mode closest to the desired one.
    /// This automatically un-maximizes the window if it's maximized.
    pub inline fn setClientSize(self: *Self, width: i32, height: i32) void {
        std.debug.assert(width > 0 and height > 0);
        var new_size = common.geometry.WidowSize{ .width = width, .height = height };
        self.impl.setClientSize(&new_size);
    }

    /// Sets a minimum limit for the window's client size and applys it immediately.
    /// # Note
    /// The new size limit must have a width and height greater than zero or it's ignored.
    ///
    /// if the requested minimum size is bigger than an already set maximum size it's ignored
    ///
    /// The new size limit only affects window while it isn't full screen mode.
    ///
    /// If the window isn't resizable any call to this function is useless as
    /// as it has no effect.
    pub inline fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
        self.impl.setMinSize(min_size);
    }

    /// Sets a maximum limit for the window's client size, and applys it immediately.
    /// # Note
    /// The new size limit must have a width and height greater than zero or it's ignored.
    ///
    /// If the requested maximum size is smaller than an already set minimum size it's ignored
    ///
    /// The new size limit only affects window while it isn't full screen mode.
    ///
    /// If the window isn't resizable any call to this function is useless as
    /// as it has no effect.
    pub inline fn setMaxSize(self: *Self, max_size: ?common.geometry.WidowSize) void {
        self.impl.setMaxSize(max_size);
    }

    /// Sets the aspect ratio of the window.
    /// # Note
    /// The new aspect ration only takes effect once the
    /// window is in windowed mode.
    ///
    /// If the window isn't resizable this function does nothing.
    ///
    /// The new ratio is given as (numerator,denomiator),
    /// where bothe numerator and denominator should be greater
    /// than zero,e.g:(16,9) for 16:9 ratio or (4,3) for 4:3 ratio.
    pub inline fn setAspectRatio(self: *Self, ratio: ?common.geometry.AspectRatio) void {
        if (ratio) |*value| {
            std.debug.assert(value.x > 0);
            std.debug.assert(value.y > 0);
        }
        self.impl.setAspectRatio(ratio);
    }

    /// Gets the current window title.
    /// # Note
    /// The caller responsible for freeing the memory.
    pub inline fn title(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return self.impl.title(allocator);
    }

    /// Changes the title of the window.
    pub inline fn setTitle(self: *Self, new_title: []const u8) !void {
        return self.impl.setTitle(self.allocator, new_title);
    }

    /// Gets the window's current visibility state.
    /// true:visible,false:hidden.
    pub inline fn isVisible(self: *const Self) bool {
        return self.impl.data.flags.is_visible;
    }

    /// Changes the window's visibility.
    /// If `false`, this will hide the window.
    /// If `true`, this will show the window.
    /// # Note
    /// This function has no effect on a full screen window.
    pub inline fn setVisible(self: *Self, visible: bool) void {
        if (self.impl.data.fullscreen_mode != null) {
            return;
        }
        if (visible) {
            self.impl.show();
        } else {
            self.impl.hide();
        }
    }

    /// Gets the window's current resizable state.
    pub inline fn isResizable(self: *const Self) bool {
        return self.impl.data.flags.is_resizable;
    }

    /// Sets whether the window is resizable or not.
    /// # Note
    /// This removes the ability to resize the window by draging it's edges,
    /// or maximize it through the caption buttons
    /// however calls to [`Window.setClientSize`],or [`Window.set_maximize`] functions can still change
    /// the size of the window and emit [`EventType.WindowResize`] event.
    pub inline fn setResizable(self: *Self, resizable: bool) void {
        self.impl.setResizable(resizable);
    }

    /// Returns true if the window is currently decorated.
    pub inline fn isDecorated(self: *const Self) bool {
        return self.impl.data.flags.is_decorated;
    }

    /// Removes the window's decorations.
    pub inline fn setDecorated(self: *Self, decorated: bool) void {
        self.impl.setDecorated(decorated);
    }

    /// Returns true if the window is minimized.
    pub inline fn isMinimized(self: *const Self) bool {
        return self.impl.data.flags.is_minimized;
    }

    /// Minimizes or restores the window.
    /// # Note
    /// If the window is full screen, the function
    /// will restore the original video mode if it was changed
    /// before minimizing it, and will switch it back when it restores the window.
    pub inline fn setMinimized(self: *Self, minimized: bool) void {
        if (minimized) {
            self.impl.minimize();
        } else {
            self.impl.restore();
        }
    }

    /// Returns true if the window is maximized.
    pub inline fn isMaximized(self: *const Self) bool {
        return self.impl.data.flags.is_maximized;
    }

    /// Maximizes or restore the window.
    /// # Note
    /// This function does nothing to a full screen window.
    pub inline fn setMaximized(self: *Self, maximized: bool) void {
        if (self.impl.data.fullscreen_mode != null) {
            return;
        }
        if (maximized) {
            self.impl.maximize();
        } else {
            self.impl.restore();
        }
    }

    /// Returns the value of the window's opacity
    /// # Note
    /// The window's opacity or alpha value is a real number
    /// between 1 and 0 that reflects how transparent
    /// the window(client area + decorations) is
    /// with 1 being opaque, and 0 being fully transparent.
    /// A window is always created with an opacity value of 1.
    pub inline fn opacity(self: *const Self) f32 {
        return self.impl.opacity();
    }

    /// Changes the opacity value of the window(client area + decorations).
    /// # Note
    /// The window's opacity or alpha value is a real number
    /// between 1 and 0 that reflects how transparent
    /// the window(client area + decorations) is
    /// with 1 being opaque, and 0 being fully transparent.
    ///
    /// A window is always created with an opacity value of 1.
    pub inline fn setOpacity(self: *Self, new_opacity: f32) void {
        std.debug.assert(new_opacity <= @as(f32, 1.0));
        std.debug.assert(new_opacity >= @as(f32, 0.0));
        self.impl.setOpacity(new_opacity);
    }

    /// Brings the window to the front and acquires input focus. Has no effect if the window is
    /// already in focus, minimized, or not visible.
    /// # Note
    /// Focusing a window means stealing input focus from others,
    /// which is anoying for the user.
    /// prefer using [`Window.requestUserAttention`] to not disrupt the user.
    pub inline fn focus(self: *const Self) void {
        if (!self.impl.data.flags.is_focused) {
            self.impl.focus();
        }
    }

    /// Returns true if the window is focused.
    pub inline fn isFocused(self: *const Self) bool {
        return self.impl.data.flags.is_focused;
    }

    /// Requests user attention to the window,
    /// this has no effect if the application is already focused.
    /// # Note
    /// How requesting for user attention manifests is platform dependent,
    pub inline fn requestUserAttention(self: *const Self) void {
        if (!self.impl.data.flags.is_focused) {
            self.impl.flash();
        }
    }

    /// Switches the window to full screen or back(null) to windowed mode.
    ///
    /// # Note
    /// [`common:window_data.FullScreenMode.Exclusive`]
    /// A full screen mode with change in the display's video mode.
    /// This mode should be used when a video mode change is desired,
    ///
    /// [`common:window_data.FullScreenMode.Borderless`]
    /// A full screen mode that simply resize the window to fit the entire monitor.
    pub inline fn setFullscreen(self: *Self, fullscreen_mode: ?common.window_data.FullScreenMode) !void {
        return self.impl.setFullscreen(fullscreen_mode);
    }

    /// Gets the fullscreen's mode.
    /// # Note
    /// if the window isn't fullscreen it returns null.
    pub inline fn fullscreen(self: *const Self) ?common.window_data.FullScreenMode {
        return self.impl.data.fullscreen_mode;
    }

    /// Returns the scale factor that maps logical pixels to real(physical) pixels.
    /// This value depends on which monitor the system considers the window
    /// to be on.
    /// The content scale factor is the ratio between the window's current DPI
    /// and the platform's default DPI
    /// e.g: On my windows laptop with a 120 DPI monitor this function returns 1.25(120/96)
    /// # Note
    /// It's important to take the scale factor into consideration when drawing to
    /// the window, as it makes the result looks more "crisp"
    /// e.g: an image might be 64 virtual pixels tall, but with a scale factor of 2.0,
    /// it should drawn with 128 physical pixels for it to appear good.
    /// [`EventType.DPIChange`] can be tracked to monitor changes in the dpi,
    /// and the scale factor.
    pub inline fn contentScale(self: *const Self) f64 {
        var scale: f64 = undefined;
        _ = self.impl.scalingDPI(&scale);
        return scale;
    }

    /// Returns the 2D virtual desktop coordinates of the mouse cursor,
    /// relative to the client_area's top-left corner.
    /// # Note
    /// The top-left corner of the client area is considered to be
    /// the origin point(0,0), with y axis pointing to the bottom,
    /// and the x axis pointing to the right
    pub inline fn cursorPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.impl.cursorPositon();
    }

    /// Returns true if the cursor is hovering on the window,
    /// i.e the cursor is inside the window area.
    /// # Note
    /// If you want to automatically be notified
    /// of cursor entering and exiting the window area.
    /// you can track the [`EventType.MouseEntered`]
    /// and [`EventType.MouseLeft`] events.
    pub inline fn isHovered(self: *const Self) bool {
        return self.impl.data.flags.cursor_in_client;
    }

    /// Changes the position of the cursor relative
    /// to the client area's top-left corner.
    /// # Note
    /// From Win32 docs: "The cursor is a shared resource.
    /// A window should move the cursor only when the cursor
    /// is in the window's client area".
    /// to comply with this and for a better user experience
    /// this function won't do anything if the window isn't focused.
    /// The specified position should be relative to the client area's top-left corner.
    /// with everything above it having a negative y-coord,
    /// and everthing to the left of it having a negative x-coord.
    pub fn setCursorPosition(self: *const Self, x: i32, y: i32) void {
        if (self.isFocused()) {
            self.impl.setCursorPosition(x, y);
        }
    }

    /// Changes the cursor used by the window.
    /// Setting a new cursor automatically enables the cursor
    /// if it was disabled and releases it if it was captured
    /// by the window.
    /// # Note
    /// From the win32 Docs:
    /// "The cursor is a shared resource.
    /// A window should set the cursor shape only
    /// when the cursor is in its client area or
    /// when the window is capturing mouse input".
    // to comply with this and for a better user experience
    // this function won't change the cursor image unless
    // it's on the client area.
    //
    // To create a cursor and retrieve the it's handle
    // use [`WidowContext::create_platform_cursor`] or
    // [`WidowContext::create_cursor`] functions.
    // pub fn setCursor(self: *Self, cursor: WidowCursor) {
    //     self.impl.?.use_cursor(cursor);
    // }

    /// Sets the cursor's mode effectively caputring it,
    /// hiding it or releasing it.
    /// # Note
    /// the `mode` parameter can take the following values:
    /// [`CursorMode.Normal`]: this is the normal mode
    /// of the cursor where it can jump freely between windows.
    /// [`CursorMode.Captured`]: this mode limit the cursor's movement
    /// to the inside of the client area preventing it's hotspot from leaving the window.
    /// [`CursorMode.Disabled`]: this is equivalent to both capturing the cursor,
    /// and removing it's visibility.
    pub inline fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
        self.impl.setCursorMode(mode);
    }

    //     // Sets the window's icon.
    //     // # Note
    //     // To create a WindowIcon from raw RGBA pixels,
    //     // use [`crate::WidowContext::create_icon`]
    //     #[inline]
    //     pub fn set_window_icon(self: *Self, icon: Option<WidowIcon>) {
    //         self.impl.?.set_window_icon(icon);
    //     }

    //     #[inline]
    //     pub fn enable_raw_mouse(self: *Self, enabled: bool) {
    //         self.impl.?.enable_raw_mouse(enabled);
    //     }
    // }
    //
    pub fn debugInfos(self: *const Self) void {
        self.impl.debugInfos();
    }
};
