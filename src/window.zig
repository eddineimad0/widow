const std = @import("std");
const common = @import("common");
const platform = @import("platform");
const WindowImpl = platform.window_impl.WindowImpl;
const Allocator = std.mem.Allocator;

pub const Window = struct {
    impl: *WindowImpl,
    allocator: Allocator,
    const Self = @This();

    /// Destroys the window and releases all allocated ressources.
    pub fn deinit(self: *Self) void {
        self.impl.destroy(self.allocator);
        self.impl = undefined;
    }

    /// Process pending events and posts them to
    /// the main event queue.
    pub inline fn processEvents(self: *Self) void {
        self.impl.processEvents();
    }

    /// This function puts the calling thread to sleep
    /// until an event msg is posted by the system.
    pub inline fn waitEvent(self: *Self) void {
        self.impl.waitEvent();
    }

    /// This function puts the calling thread to sleep
    /// until an event msg is posted by the system,
    /// or timeout period elapses.
    /// # Parameters
    /// `duration_ms`: the timeout period in milliseconds.
    /// # Notes
    /// If the timeout is 0 the function will return immediately.
    pub inline fn waitEventTimeout(self: *Self, duration_ms: u32) bool {
        std.debug.assert(duration_ms > 0);
        return self.impl.waitEventTimeout(duration_ms);
    }

    /// Posts `EventType.WindowClose` event to the main event queue.
    /// # Notes
    /// This function can be used to signal a desire to exit the event loop,
    /// from the code.
    /// This function doesn't close the window or perform any cleanup logic,
    /// the window will still be visible untill the binding is deinitialized.
    /// Events posted before a call to this function will still be processed
    /// first.
    pub inline fn queueCloseEvent(self: *Self) void {
        const event = common.event.createCloseEvent(self.impl.data.id);
        self.impl.queueEvent(&event);
    }

    /// Returns the position of the top-left corner of the window's client area,
    /// relative to the virtual desktop's top-left corner.
    /// # Notes
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
    /// # Notes
    /// The `x` and `y` parameters should be in virutal desktop coordinates.
    /// if the window is maximized it is automatically restored.
    /// I fail to think of any situation where this should be used.
    pub inline fn setPosition(self: *const Self, x: i32, y: i32) void {
        self.impl.setPosition(x, y);
    }

    /// Returns the position of the top-left corner of the window,
    /// relative to the virtual desktop's top-left corner.
    /// # Notes
    /// The virutal desktop is the desktop created by combining all connected monitors
    /// where each monitor displays a portion of it.
    /// The virtual desktop's top-left in a single monitor setup is the same as that monitor's
    /// top left-corner, in a multi-monitor setup it depends on the setup's configuration.
    pub inline fn position(self: *const Self) common.geometry.WidowPoint2D {
        return self.impl.position();
    }

    /// Returns the size in physical pixels of the window's client area.
    /// # Notes
    /// The client area is the content of the window, excluding the title bar and borders.
    /// The logical size which is the same as the size specified during window creation,
    /// can be aquired by dividing the Physical size with the content scale factor
    /// returned by `Window.contentScale()`.
    pub inline fn clientSize(self: *const Self) common.geometry.WidowSize {
        return platform.window_impl.clientSize(self.impl.handle);
    }

    /// Returns the size in physical pixels of the entire window.
    pub inline fn size(self: *const Self) common.geometry.WidowSize {
        return platform.window_impl.windowSize(self.impl.handle);
    }

    /// Changes the client size of the window.
    /// The specifed size should be in logical pixels i.e no need to scale it by the dpi.
    /// width must be > 0 and height must be > 0.
    /// # Parameters
    /// `width`: the new width of the client size.
    /// `height`: the new height of the client size.
    /// # Notes
    /// For a full screen window this function updates the resolution
    /// and switches to the video mode closest to the desired one.
    /// This automatically un-maximizes the window if it's maximized.
    pub inline fn setClientSize(self: *Self, width: i32, height: i32) void {
        std.debug.assert(width > 0 and height > 0);
        var new_size = common.geometry.WidowSize{ .width = width, .height = height };
        self.impl.setClientSize(&new_size);
    }

    /// Sets a minimum limit for the window's client size and applys it immediately.
    /// # Parameters
    /// `min_size`: the new minimum size to be applied.
    /// # Notes
    /// If the window isn't resizable any call to this function is useless as
    /// as it has no effect.
    /// By default no size limit is specified.
    /// The new size limit must have a width and height greater than zero or it's ignored.
    /// if the requested minimum size is bigger than an already set maximum size it's ignored
    /// The new size limit only affects window while it isn't full screen mode.
    pub inline fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
        self.impl.setMinSize(min_size);
    }

    /// Sets a maximum limit for the window's client size, and applys it immediately.
    /// # Parameters
    /// `max_size`: the new maximum size to be applied.
    /// # Notes
    /// If the window isn't resizable any call to this function is useless as
    /// as it has no effect.
    /// By default no size limit is specified.
    /// The new size limit must have a width and height greater than zero or it's ignored.
    /// If the requested maximum size is smaller than an already set minimum size it's ignored
    /// The new size limit only affects window while it isn't full screen mode.
    pub inline fn setMaxSize(self: *Self, max_size: ?common.geometry.WidowSize) void {
        self.impl.setMaxSize(max_size);
    }

    /// Sets the aspect ratio of the window.
    /// # Parameters
    /// `ratio`: the new aspect ratio to be applied (numerator,denominator).
    /// # Notes
    /// If the window isn't resizable this function does nothing.
    /// The new aspect ration only takes effect once the
    /// window is in windowed mode.
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

    /// Returns a slice conatining the current window title.
    /// # Parameters
    /// `allocator`: the allocator to be used for allocating the returned slice.
    /// # Notes
    /// The caller has ownership of the returned slice,
    /// and is responsible for freeing the memory.
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
    /// # Parameters
    /// `visible`: the new visiblity state to be set.
    /// # Notes
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
    /// # Parameters
    /// `resizable`: the new resizable state to be set.
    /// # Notes
    /// Setting false removes the ability to resize the window by draging it's edges,
    /// or maximize it through the caption buttons
    /// however calls to `Window.setClientSize`, or `Window.set_maximize` functions can still change
    /// the size of the window and emit `EventType.WindowResize` event.
    pub inline fn setResizable(self: *Self, resizable: bool) void {
        self.impl.setResizable(resizable);
    }

    /// Returns true if the window is currently decorated.
    pub inline fn isDecorated(self: *const Self) bool {
        return self.impl.data.flags.is_decorated;
    }

    /// Removes the window's decorations.
    /// # Parameters
    /// `decorated`: the new decorated state to be set.
    pub inline fn setDecorated(self: *Self, decorated: bool) void {
        self.impl.setDecorated(decorated);
    }

    /// Returns true if the window is minimized.
    pub inline fn isMinimized(self: *const Self) bool {
        return self.impl.data.flags.is_minimized;
    }

    /// Minimizes or restores the window.
    /// # Parameters
    /// `minimize`: flag whether to minimize or restore(unminimize).
    /// # Notes
    /// If the window is full screen, the function
    /// will restore the original video mode if it was changed
    /// before minimizing it, and will switch it back when it restores the window.
    pub inline fn setMinimized(self: *Self, minimize: bool) void {
        if (minimize) {
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
    /// # Parameters
    /// `maximize`: flag whether to maximize or restore(unmaximize).
    /// # Notes
    /// This function does nothing to a full screen window.
    pub inline fn setMaximized(self: *Self, maximize: bool) void {
        if (self.impl.data.fullscreen_mode != null) {
            return;
        }
        if (maximize) {
            self.impl.maximize();
        } else {
            self.impl.restore();
        }
    }

    /// Returns the value of the window's opacity
    /// # Notes
    /// The window's opacity or alpha value is a real number
    /// between 1 and 0 that reflects how transparent
    /// the window(client area + decorations) is
    /// with 1 being opaque, and 0 being fully transparent.
    /// A window is always created with an opacity value of 1.
    pub inline fn opacity(self: *const Self) f32 {
        return self.impl.opacity();
    }

    /// Changes the opacity value of the window(client area + decorations).
    /// # Parameters
    /// `value`: the new opacity value.
    /// # Notes
    /// The window's opacity or alpha value is a real number
    /// between 1 and 0 that reflects how transparent
    /// the window(client area + decorations) is
    /// with 1 being opaque, and 0 being fully transparent.
    /// A window is always created with an opacity value of 1.
    pub inline fn setOpacity(self: *Self, value: f32) void {
        std.debug.assert(value <= @as(f32, 1.0));
        std.debug.assert(value >= @as(f32, 0.0));
        self.impl.setOpacity(value);
    }

    /// Brings the window to the front and acquires input focus. Has no effect if the window is
    /// already in focus, minimized, or not visible.
    /// # Notes
    /// Focusing a window means stealing input focus from others,
    /// which is anoying for the user.
    /// prefer using `Window.requestUserAttention()` to not disrupt the user.
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
    /// # Notes
    /// How requesting for user attention manifests is platform dependent,
    pub inline fn requestUserAttention(self: *const Self) void {
        if (!self.impl.data.flags.is_focused) {
            self.impl.flash();
        }
    }

    /// Switches the window to fullscreen or back(null) to windowed mode.
    /// # Parameters
    /// `fullscreen_mode` : mode to switch to or null to restore the window.
    /// # Notes
    /// Possible fullscreen modes are:
    /// [`FullScreenMode.Exclusive`]
    /// A full screen mode with change in the display's video mode.
    /// This mode should be used when a video mode change is desired,
    /// [`FullScreenMode.Borderless`]
    /// A full screen mode that simply resize the window to fit the entire monitor.
    pub inline fn setFullscreen(self: *Self, fullscreen_mode: ?common.window_data.FullScreenMode) !void {
        return self.impl.setFullscreen(fullscreen_mode);
    }

    /// Gets the fullscreen's mode.
    /// # Notes
    /// If the window isn't fullscreen it returns null.
    pub inline fn fullscreen(self: *const Self) ?common.window_data.FullScreenMode {
        return self.impl.data.fullscreen_mode;
    }

    /// Returns the scale factor that maps logical pixels to real(physical) pixels.
    /// This value depends on which monitor the system considers the window
    /// to be on.
    /// The content scale factor is the ratio between the window's current DPI
    /// and the platform's default DPI
    /// e.g: On my windows laptop with a 120 DPI monitor this function returns 1.25(120/96)
    /// # Notes
    /// It's important to take the scale factor into consideration when drawing to
    /// the window, as it makes the result looks more "crisp"
    /// e.g: an image might be 64 virtual pixels tall, but with a scale factor of 2.0,
    /// it should drawn with 128 physical pixels for it to appear good.
    /// `EventType.DPIChange` can be tracked to monitor changes in the dpi,
    /// and the scale factor.
    pub inline fn contentScale(self: *const Self) f64 {
        var scale: f64 = undefined;
        _ = self.impl.scalingDPI(&scale);
        return scale;
    }

    /// Returns the 2D virtual desktop coordinates of the mouse cursor,
    /// relative to the client_area's top-left corner.
    /// # Notes
    /// The top-left corner of the client area is considered to be
    /// the origin point(0,0), with y axis pointing to the bottom,
    /// and the x axis pointing to the right
    pub inline fn cursorPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.impl.cursorPositon();
    }

    /// Returns true if the cursor is hovering on the window,
    /// i.e the cursor is inside the window area.
    /// # Notes
    /// If you want to automatically be notified
    /// of cursor entering and exiting the window area.
    /// you can track the `EventType.MouseEntered`
    /// and `EventType.MouseLeft` events.
    pub inline fn isHovered(self: *const Self) bool {
        return self.impl.data.flags.cursor_in_client;
    }

    /// Changes the position of the cursor relative
    /// to the client area's top-left corner.
    /// # Parameters
    /// `x`: the new x position of the cursor.
    /// `y`: the new y position of the cursor.
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

    /// Sets the cursor's mode effectively caputring it,
    /// hiding it or releasing it.
    /// # Parameters
    /// `mode`: the new cursor mode to be applied.
    /// # Note
    /// the `mode` parameter can take the following values:
    /// `CursorMode.Normal`: this is the normal mode
    /// of the cursor where it can jump freely between windows.
    /// `CursorMode.Captured`: this mode limit the cursor's movement
    /// to the inside of the client area preventing it's hotspot from leaving the window.
    /// `CursorMode.Disabled`: this is equivalent to both capturing the cursor,
    /// and removing it's visibility.
    pub inline fn setCursorMode(self: *Self, mode: common.cursor.CursorMode) void {
        self.impl.setCursorMode(mode);
    }

    /// Returns a slice that holds the path(s) to the latest dropped file(s)
    /// # Note
    /// User should only call this function when receiving a FileDrop event.
    /// User shouldn't attempt to free or modify the returned slice and should instead
    /// call `Window.freeDroppedFiles` if they wish to free it.
    /// The returned slice may gets invalidated and mutated during the next file drop event
    pub inline fn droppedFiles(self: *const Self) [][]const u8 {
        return self.impl.droppedFiles();
    }

    /// Frees the memory used to hold the dropped file(s) path(s).
    /// # Note
    /// Each window keeps a cache of the last dropped file(s) path(s) in heap memory,
    /// the allocated memory is reused whenever a new drop happens and may get resized
    /// if more space is needed.
    /// User may want to call this function to manage that memory as they see fit.
    pub inline fn freeDroppedFiles(self: *Self) void {
        return self.impl.freeDroppedFiles();
    }

    /// Sets the window's icon to the RGBA pixels data.
    /// # Parameters
    /// `pixels`: a slice to the icon's pixel(RGBA) data.
    /// `width` : the width of the icon in pixels.
    /// `height`: the height of the icon in pixels.
    /// # Notes
    /// This function expects non-premultiplied, 32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha last.
    pub inline fn setIcon(self: *Self, pixels: []const u8, width: i32, height: i32) !void {
        std.debug.assert(width > 0 and height > 0);
        std.debug.assert(pixels.len == (width * height * 4));
        try platform.internals.createIcon(self.impl, pixels, width, height);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Notes
    /// Unlike `WidowContext.setWindowIcon` this function also takes the cooridnates of the
    /// cursor hotspot which is the pixel that the system tracks to decide mouse click
    /// target, the `xhot` and `yhot` parameters represent the x and y coordinates
    /// of that pixel relative to the top left corner of the image, with the x axis directed
    /// to the right and the y axis directed to the bottom.
    /// This function expects non-premultiplied,32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha.
    pub inline fn setCursor(self: *Self, pixels: []const u8, width: i32, height: i32, xhot: u32, yhot: u32) !void {
        std.debug.assert(width > 0 and height > 0);
        std.debug.assert(pixels.len == (width * height * 4));
        try platform.internals.createCursor(self.impl, pixels, width, height, xhot, yhot);
    }

    // # Use only for debug.
    pub fn debugInfos(self: *const Self) void {
        self.impl.debugInfos();
    }
};
