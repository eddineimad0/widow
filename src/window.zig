const std = @import("std");
const builtin = @import("builtin");
const dbg = builtin.mode == .Debug;
const common = @import("common");
const platform = @import("platform");
const WindowImpl = platform.window_impl.WindowImpl;
const WidowProps = platform.window_impl.WidowProps;
const WindowData = common.window_data.WindowData;
const Allocator = std.mem.Allocator;

pub const Window = struct {
    impl: *WindowImpl,
    allocator: Allocator,
    const Self = @This();

    /// Initializes and returns a Window instance.
    /// Prefer using a WindowBuilder instead of calling this directly.
    /// # Parameters
    /// `Allocator` : the allocator to be used with window related allocations(title,...).
    /// `title` : the window's title.
    /// `data` : a refrence to a WindowData structure.
    /// `events_queue` : a pointer to the library's shared event queue.
    /// `internals` : a pointer to an instance of the platform widow Internals.
    /// # Errors
    /// `OutOfMemory`: failure due to memory allocation.
    /// `WindowError.FailedToCreate` : couldn't create the window due to a platform error.
    pub fn init(
        allocator: Allocator,
        window_title: []const u8,
        data: *WindowData,
        events_queue: *common.event.EventQueue,
        internals: *platform.Internals,
    ) !Self {
        var self = Self{
            .allocator = allocator,
            .impl = try WindowImpl.create(
                allocator,
                window_title,
                data,
                events_queue,
                internals,
            ),
        };
        return self;
    }

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
        self.impl.sendEvent(&event);
    }

    /// Returns the position of the top-left corner of the window's client area,
    /// relative to the virtual desktop's top-left corner.
    /// If the window is minimized the returned value is the last known position
    /// of the client area.
    /// # Notes
    /// The client area is the content of the window, excluding the title bar and borders.
    /// The virutal desktop is the desktop created by combining all connected monitors
    /// where each monitor displays a portion of it.
    /// The virtual desktop's top-left in a single monitor setup is the same as that monitor's
    /// top left-corner, in a multi-monitor setup it depends on the setup's configuration.
    pub inline fn clientPosition(self: *const Self) common.geometry.WidowPoint2D {
        return self.impl.clientPosition();
    }

    /// Change the position of the window's top-left corner,
    /// to the newly specified x and y.
    /// # Parameters
    /// `x`: the new x coordinate.
    /// `y`: the new y coordinate.
    /// # Notes
    /// The `x` and `y` parameters should be in virutal desktop coordinates.
    /// if the window is maximized it is automatically restored.
    /// I fail to think of any situation where this should be used.
    pub inline fn setClientPosition(self: *const Self, x: i32, y: i32) void {
        self.impl.setClientPosition(x, y);
    }

    /// Returns the size in logical pixels of the window's client area.
    /// # Notes
    /// The client area is the content of the window, excluding the title bar and borders.
    /// If the window allows dpi scaling the returned size might be diffrent from the
    /// physical size.
    pub inline fn clientSize(self: *const Self) common.geometry.WidowSize {
        return self.impl.clientSize();
    }

    /// Returns the size in physical pixels of the window's client area.
    /// # Notes
    /// The client area is the content of the window, excluding the title bar and borders.
    /// If the window allows dpi scaling the returned size might be diffrent from the
    /// logical size.
    pub inline fn clientPixelSize(self: *const Self) common.geometry.WidowSize {
        return self.impl.clientPixelSize();
    }

    /// Changes the client size of the window.
    /// The specifed size should be in logical pixels i.e no need to scale it by the dpi.
    /// width must be > 0 and height must be > 0.
    /// # Parameters
    /// `width`: the new width of the client size.
    /// `height`: the new height of the client size.
    /// # Notes
    /// This automatically un-maximizes the window if it's maximized.
    /// For a full screen window this function does nothing.
    pub inline fn setClientSize(self: *Self, width: i32, height: i32) void {
        std.debug.assert(width > 0 and height > 0);
        var new_size = common.geometry.WidowSize{ .width = width, .height = height };
        self.impl.setClientSize(&new_size);
    }

    /// Sets a minimum limit for the window's client size and applys it immediately.
    /// # Parameters
    /// `min_size`: the new minimum size to be applied or null to remove size limitation.
    /// # Notes
    /// If the window isn't resizable this function returns immediately
    /// By default no size limit is specified.
    /// The new size limit must have a width and height greater than zero or it's ignored.
    /// If the requested minimum size is bigger than an already set maximum size it's ignored
    /// The new size limit only affects window while it isn't full screen mode.
    /// If the window allows dpi scaling the specified size is auto scaled by the window's dpi.
    pub inline fn setMinSize(self: *Self, min_size: ?common.geometry.WidowSize) void {
        self.impl.setMinSize(min_size);
    }

    /// Sets a maximum limit for the window's client size, and applys it immediately.
    /// # Parameters
    /// `max_size`: the new maximum size to be applied or null to remove size limitation.
    /// # Notes
    /// If the window isn't resizable this function returns immediately.
    /// By default no size limit is specified.
    /// The new size limit must have a width and height greater than zero or it's ignored.
    /// If the requested maximum size is smaller than an already set minimum size it's ignored
    /// The new size limit only affects window while it isn't full screen mode.
    /// If the window allows dpi scaling the specified size is auto scaled by the window's dpi.
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
    /// `allocator`: the allocator used for allocating the returned slice.
    /// # Notes
    /// The caller has ownership of the returned slice,
    /// and is responsible for freeing the memory.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub inline fn title(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return self.impl.title(allocator);
    }

    /// Changes the title of the window.
    /// # Parameters
    /// `new_title`: utf-8 string of the new title to be set.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
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
    pub fn setVisible(self: *Self, visible: bool) void {
        if (self.impl.data.flags.is_fullscreen) {
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
    /// however calls to `Window.setClientSize`, or `Window.setMaximized` functions can still change
    /// the size of the window and emit `EventType.WindowResize` event.
    pub inline fn setResizable(self: *Self, resizable: bool) void {
        self.impl.setResizable(resizable);
    }

    /// Returns true if the window is currently decorated(has a title bar and borders).
    pub inline fn isDecorated(self: *const Self) bool {
        return self.impl.data.flags.is_decorated;
    }

    /// Sets the window's decorations On or Off.
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
    pub fn setMinimized(self: *Self, minimize: bool) void {
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
    /// This function does nothing to a full screen or a non resizable window.
    pub fn setMaximized(self: *Self, maximize: bool) void {
        if (self.impl.data.flags.is_fullscreen or !self.impl.data.flags.is_resizable) {
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
    pub fn focus(self: *Self) void {
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
    pub fn requestUserAttention(self: *const Self) void {
        if (!self.impl.data.flags.is_focused) {
            self.impl.flash();
        }
    }

    /// Switches the window to fullscreen or back to windowed mode.
    /// if the function succeeds it returns true else it returns false.
    /// # Parameters
    /// `value`: whether to set or exit fullscreen mode.
    /// `video_mode`:  a VideoMode to switch to or null to keep the user's video mode
    pub fn setFullscreen(self: *Self, value: bool, video_mode: ?*common.video_mode.VideoMode) bool {
        self.impl.setFullscreen(value, video_mode) catch |err| {
            std.log.err("[Window]:Failed to set Fullscreen mode, error:{}\n", .{err});
            return false;
        };
        return true;
    }

    /// Returns whether the window is fullscreen or not.
    pub inline fn isFullscreen(self: *const Self) bool {
        return self.impl.data.flags.is_fullscreen;
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
    pub fn contentScale(self: *const Self) f64 {
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

    /// Sets whether the window accepts dropping files or not.
    /// by default any window created doesn't allow file to be dragged and dropped.
    /// # Parameters
    /// `accepted`: true to allow file dropping, false to block it.
    pub inline fn setDragAndDrop(self: *Self, accepted: bool) void {
        self.impl.setDragAndDrop(accepted);
    }

    /// Returns a slice that holds the path(s) to the latest dropped file(s)
    /// # Note
    /// User should only call this function when receiving a `EventType.FileDrop` event.
    /// User shouldn't attempt to free or modify the returned slice and should instead
    /// call `Window.freeDroppedFiles` if they wish to free the cache.
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
    /// `pixels`: a slice to the icon's pixel(RGBA) data or null to set the platform default icon.
    /// `width` : the width of the icon in pixels.
    /// `height`: the height of the icon in pixels.
    /// # Notes
    /// This function expects non-premultiplied, 32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha value, and should be
    /// represented using 8-bits, with the Red Channel being first followed by the blue,the green,
    /// and the alpha last.
    /// If the pixels slice is null width and height can be set to whatever.
    pub inline fn setIcon(self: *Self, pixels: ?[]const u8, width: i32, height: i32) !void {
        if (pixels != null) {
            std.debug.assert(width > 0 and height > 0);
            std.debug.assert(pixels.?.len == (width * height * 4));
        }
        try self.impl.setIcon(pixels, width, height);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Parameters
    /// `pixels`: a slice to the cursor image's pixel(RGBA) data or null to use the platform's default cursor.
    /// `width` : the width of the icon in pixels.
    /// `height`: the height of the icon in pixels.
    /// `xhot`: the x coordinates of the cursor's hotspot.
    /// `yhot`: the y coordinates of the cursor's hotspot.
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
    /// If the pixels slice is null width,height,xhot and yhot can be set to whatever.
    pub inline fn setCursor(self: *Self, pixels: ?[]const u8, width: i32, height: i32, xhot: u32, yhot: u32) !void {
        if (pixels != null) {
            std.debug.assert(width > 0 and height > 0);
            std.debug.assert(pixels.?.len == (width * height * 4));
        }
        try self.impl.setCursor(pixels, width, height, xhot, yhot);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Parameters
    /// `cursor_shape`: the standard cursor to set from the StandardCursorShape enum.
    pub inline fn setStandardCursor(self: *Self, cursor_shape: common.cursor.StandardCursorShape) !void {
        try self.impl.setStandardCursor(cursor_shape);
    }

    /// Returns the descriptor or handle used by the platform to identify the window.
    pub inline fn platformHandle(self: *const Self) platform.WindowHandle {
        return self.impl.platformHandle();
    }

    // Prints some debug information to stdout.
    // if compiled in non Debug mode it does nothing.
    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (dbg) {
            self.impl.debugInfos(size, flags);
        }
    }
};
