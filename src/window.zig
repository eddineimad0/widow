const std = @import("std");
const common = @import("common");
const platform = @import("platform");
const mem = std.mem;
const WindowImpl = platform.Window;
const WindowData = common.window_data.WindowData;
const EventQueue = common.event.EventQueue;
const WidowContext = platform.WidowContext;

pub const WindowBuilder = struct {
    attribs: common.window_data.WindowData,
    fbcfg: common.fb.FBConfig,
    title: []const u8,
    const Self = @This();

    /// Creates a window builder instance.
    /// The window builder wraps the creation attributes of the window,
    /// and the functions necessary to changes those attributes.
    /// # Parameters
    /// `context`: a pointer to the WidowContext instance.
    /// # Notes
    /// The context parameter should point to an initialzed WidowContext instance that lives
    /// as long as the window, i.e destroying the WidowContext instance before the window is destroyed
    /// causes undefined behaviour.
    pub fn init() Self {
        return Self{
            .title = "",
            // Defalut attributes
            .attribs = common.window_data.WindowData{
                .id = 0,
                .client_area = common.geometry.Rect.init(
                    platform.Window.WINDOW_DEFAULT_POSITION.x,
                    platform.Window.WINDOW_DEFAULT_POSITION.y,
                    640,
                    480,
                ),
                .min_size = null,
                .max_size = null,
                .aspect_ratio = null,
                .flags = .{
                    .is_visible = true,
                    .is_maximized = false,
                    .is_minimized = false,
                    .is_resizable = false,
                    .is_decorated = true,
                    .is_topmost = false,
                    .is_focused = false,
                    .is_fullscreen = false,
                    .cursor_in_client = false,
                    .is_dpi_aware = false,
                    .has_raw_mouse = false,
                },
                .input = common.keyboard_mouse.InputState.init(),
            },
            .fbcfg = .{
                .depth_bits = 24,
                .stencil_bits = 8,

                .color_bits = .{
                    .red_bits = 8,
                    .green_bits = 8,
                    .blue_bits = 8,
                    .alpha_bits = 8,
                },

                .accum_bits = .{
                    .red_bits = 0,
                    .green_bits = 0,
                    .blue_bits = 0,
                    .alpha_bits = 0,
                },

                .flags = .{
                    .double_buffered = true,
                    .sRGB = true,
                    .stereo = false,
                },

                .accel = .{
                    .opengl = .{
                        .ver = .{
                            .major = 4,
                            .minor = 1,
                        },
                        .profile = .Core,
                    },
                },
            },
        };
    }

    /// Creates and returns the built window instance.
    /// # Parameters
    /// `ctx`: a pointer to a valid WindowContext
    /// `id`: number used to identify the window, if null is used an identifer
    /// is generated from the platform window identifer whose value is unpredicatble.
    /// # Notes
    /// The user should deinitialize the Window instance when done.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    pub fn build(self: *Self, ctx: *WidowContext, id: ?usize) !Window {
        // The Window should copy the title.
        const w = Window.init(
            ctx,
            id,
            self.title,
            &self.attribs,
            &self.fbcfg,
        );
        return w;
    }

    /// Set the window title.
    /// # Parameters
    /// `title`: the new title to replace the current one.
    /// # Notes
    /// The title slice should remain valid until the window is created.
    pub fn withTitle(self: *Self, title: []const u8) *Self {
        self.title = title;
        return self;
    }

    /// Set the window width and height.
    /// # Parameters
    /// `width`: the new width to replace the current one.
    /// `height`: the new height to replace the current one.
    /// # Notes
    /// If the window is DPI aware the final width and height
    /// might be diffrent
    pub fn withSize(self: *Self, width: i32, height: i32) *Self {
        std.debug.assert(width > 0 and height > 0);
        self.attribs.client_area.size.width = width;
        self.attribs.client_area.size.height = height;
        return self;
    }

    /// Whether the window is visible(true) or hidden(false).
    /// if not set the default is visible.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withVisibility(self: *Self, value: bool) *Self {
        self.attribs.flags.is_visible = value;
        return self;
    }

    /// Choose the position of the client(content area)'s top left corner.
    /// If not set the default is decided by the system.
    /// # Parameters
    /// `x`: the y coordinates of the client's top left corner.
    /// `y`: the y coordinates of the client's top left corner.
    pub fn withPosition(self: *Self, x: i32, y: i32) *Self {
        self.attribs.client_area.top_left.x = x;
        self.attribs.client_area.top_left.y = y;
        return self;
    }

    /// Make the window resizable.
    /// The window is not resizable by default.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withResize(self: *Self, value: bool) *Self {
        self.attribs.flags.is_resizable = value;
        return self;
    }

    /// Whether the window has a frame or not.
    /// The default is true.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDecoration(self: *Self, value: bool) *Self {
        self.attribs.flags.is_decorated = value;
        return self;
    }

    /// Whether the window should stay on top even if it lose focus.
    /// The default is false.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withTopMost(self: *Self, value: bool) *Self {
        self.attribs.flags.is_topmost = value;
        return self;
    }

    /// Specify a minimum and maximum window size for resizable windows.
    /// No size limitation is applied by default.
    /// # Paramters
    /// `width`: the minimum possible width for the window.
    /// `height`: the minimum possible height fo the window.
    pub fn withMinSizeLimit(
        self: *Self,
        width: i32,
        height: i32,
    ) *Self {
        self.attribs.min_size = .{ .width = width, .height = height };
        return self;
    }

    /// Specify a maximum window size for resizable windows.
    /// No size limitation is applied by default.
    /// # Paramters
    /// `width`: the maximum possible width for the window.
    /// `height`: the maximum possible height fo the window.
    pub fn withMaxSizeLimit(
        self: *Self,
        width: i32,
        height: i32,
    ) *Self {
        self.attribs.max_size = .{ .width = width, .height = height };
        return self;
    }

    /// Specify whether the window size should be scaled by the Display's Dpi.
    /// scaling is not applied by default.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withDPIAware(self: *Self, value: bool) *Self {
        self.attribs.flags.is_dpi_aware = value;
        return self;
    }

    /// Specify whether the window should be fullscreen on creation.
    /// # Parameters
    /// `value`: the boolean value of the flag.
    pub fn withFullscreen(self: *Self, value: bool) *Self {
        self.attribs.flags.is_fullscreen = value;
        return self;
    }

    /// Specify the frame buffer configuration for the window.
    /// # Parameters
    /// `cfg`: a pointer to a FBConfig struct.
    pub fn withFrameBuffer(self: *Self, cfg: *const common.fb.FBConfig) *Self {
        self.fbcfg = cfg.*;
        return self;
    }
};

pub const Window = struct {
    impl: *WindowImpl,
    const Self = @This();

    /// Initializes and returns a Window instance.
    /// Prefer using a WindowBuilder instead of calling this directly.
    /// # Parameters
    /// `ctx` : a pointer to a valid WidowContext,
    /// `title` : the window's title.
    /// `data` : a refrence to a WindowData structure.
    /// `fb_cfg`: a pointer to a FBConfig struct.
    /// # Errors
    /// `OutOfMemory`: failure due to memory allocation.
    /// `WindowError.FailedToCreate` : couldn't create the window due
    /// to a platform error.
    fn init(
        ctx: *WidowContext,
        id: ?usize,
        window_title: []const u8,
        data: *WindowData,
        fb_cfg: *common.fb.FBConfig,
    ) !Self {
        return .{
            .impl = try WindowImpl.init(
                ctx,
                id,
                window_title,
                data,
                fb_cfg,
            ),
        };
    }

    /// Destroys the window and releases all allocated ressources.
    pub fn deinit(self: *Self) void {
        self.impl.deinit();
        self.impl = undefined;
    }

    /// Returns a pointer to the current queue the window is using
    /// for sending events
    pub inline fn getEventQueue(self: *const Self) ?*EventQueue {
        return self.impl.getEventQueue();
    }

    /// Sets a pointer the queue where the window events will be sent,
    /// and returns the previous queue pointer.
    /// By default there is no registered queue and the windo simply discards
    /// all events.
    /// caller must guarantee the queue outlives the window.
    /// # Paramters
    /// `queue` a optional pointer to the queue that will be used.
    pub inline fn setEventQueue(self: *Self, queue: ?*EventQueue) ?*EventQueue {
        return self.impl.setEventQueue(queue);
    }

    /// Process pending events and posts them to
    /// the event queue.
    /// make sure a destination queue is already set in place
    /// by calling *setEventQueue* otherwise the events won't be reported.
    pub inline fn pollEvents(self: *Self) platform.WindowError!void {
        return self.impl.processEvents();
    }

    /// This function puts the calling thread to sleep
    /// until an event msg is posted by the system.
    pub inline fn waitEvent(self: *Self) platform.WindowError!void {
        return self.impl.waitEvent();
    }

    /// This function puts the calling thread to sleep
    /// until an event msg is posted by the system,
    /// or timeout period elapses.
    /// # Parameters
    /// `duration_ms`: the timeout period in milliseconds.
    /// # Notes
    /// If the timeout is 0 the function will return immediately.
    pub inline fn waitEventTimeout(
        self: *Self,
        duration_ms: u32,
    ) platform.WindowError!bool {
        std.debug.assert(duration_ms != 0);
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
    /// The client area is the content of the window, excluding the
    /// title bar and borders. The virutal desktop is the desktop created
    /// by combining all connected monitors where each monitor displays a
    /// portion of it. The virtual desktop's top-left in a single monitor setup
    /// is the same as that monitor's top left-corner, in a multi-monitor setup
    /// it depends on the setup's configuration.
    pub inline fn getClientPosition(self: *const Self) common.geometry.Point2D {
        return self.impl.getClientPosition();
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
    /// The client area is the content of the window, excluding the title
    /// bar and borders. If the window allows dpi scaling
    /// the returned size might be diffrent from the physical size.
    pub inline fn getClientSize(self: *const Self) common.geometry.RectSize {
        return self.impl.getClientSize();
    }

    /// Returns the size in physical pixels of the window's client area.
    /// # Notes
    /// The client area is the content of the window, excluding the title
    /// bar and borders. If the window allows dpi scaling the returned
    /// size might be diffrent from the logical size.
    pub inline fn getClientPixelSize(self: *const Self) common.geometry.RectSize {
        return self.impl.getClientPixelSize();
    }

    /// Changes the client size of the window.
    /// The specifed size should be in logical pixels i.e no need to scale
    /// it by the dpi. width must be > 0 and height must be > 0.
    /// # Parameters
    /// `width`: the new width of the client size.
    /// `height`: the new height of the client size.
    /// # Notes
    /// This automatically un-maximizes the window if it's maximized.
    /// For a full screen window this function does nothing.
    pub inline fn setClientSize(self: *Self, width: i32, height: i32) void {
        std.debug.assert(width > 0 and height > 0);
        var new_size = common.geometry.RectSize{
            .width = width,
            .height = height,
        };
        self.impl.setClientSize(&new_size);
    }

    /// Sets a minimum limit for the window's client size and applys it
    /// immediately.
    /// # Parameters
    /// `min_size`: the new minimum size to be applied or null to remove
    /// size limitation.
    /// # Notes
    /// If the window isn't resizable this function returns immediately
    /// By default no size limit is specified.
    /// The new size limit must have a width and height greater
    /// than zero or it's ignored. If the requested minimum size is bigger
    /// than an already set maximum size it's ignored The new size limit only
    /// affects window while it isn't full screen mode. If the window allows dpi
    /// scaling the specified size is auto scaled by the window's dpi.
    pub inline fn setMinSize(
        self: *Self,
        min_size: ?common.geometry.RectSize,
    ) void {
        self.impl.setMinSize(min_size);
    }

    /// Sets a maximum limit for the window's client size, and applys it
    /// immediately.
    /// # Parameters
    /// `max_size`: the new maximum size to be applied or null to remove
    /// size limitation.
    /// # Notes
    /// If the window isn't resizable this function returns immediately.
    /// By default no size limit is specified.
    /// The new size limit must have a width and height greater than zero
    /// or it's ignored. If the requested maximum size is smaller than an
    /// already set minimum size it's ignored The new size limit only affects
    /// window while it isn't full screen mode. If the window allows dpi scaling
    /// the specified size is auto scaled by the window's dpi.
    pub inline fn setMaxSize(
        self: *Self,
        max_size: ?common.geometry.RectSize,
    ) void {
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
    pub inline fn setAspectRatio(
        self: *Self,
        ratio: ?common.geometry.AspectRatio,
    ) void {
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
    pub inline fn getTitle(self: *const Self, allocator: mem.Allocator) mem.Allocator.Error![]u8 {
        return self.impl.getTitle(allocator);
    }

    /// Changes the title of the window.
    /// # Parameters
    /// `new_title`: utf-8 string of the new title to be set.
    /// # Errors
    /// 'OutOfMemory': function could fail due to memory allocation.
    /// 'InvalidUtf8': function could fail if the new_title isn't a valid utf-8 string
    pub inline fn setTitle(self: *Self, new_title: []const u8) error{ OutOfMemory, InvalidUtf8 }!void {
        return self.impl.setTitle(new_title);
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
    /// Setting false removes the ability to resize the window by draging
    /// it's edges, or maximize it through the caption buttons
    /// however calls to `Window.setClientSize`, or `Window.setMaximized`
    /// functions can still change the size of the window
    /// and emit `EventType.WindowResize` event.
    pub inline fn setResizable(self: *Self, resizable: bool) void {
        self.impl.setResizable(resizable);
    }

    /// Returns true if the window is currently
    /// decorated(has a title bar and borders).
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
        if (self.impl.data.flags.is_fullscreen or
            !self.impl.data.flags.is_resizable)
        {
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
    pub inline fn getOpacity(self: *const Self) f32 {
        return self.impl.getOpacity();
    }

    /// Changes the opacity value of the window(client area + decorations).
    /// # Parameters
    /// `value`: the new opacity value.
    /// # Returns
    /// `true` on success otherwise `false`.
    /// # Notes
    /// The window's opacity or alpha value is a real number
    /// between 1 and 0 that reflects how transparent
    /// the window(client area + decorations) is
    /// with 1 being opaque, and 0 being fully transparent.
    /// A window is always created with an opacity value of 1.
    pub inline fn setOpacity(self: *Self, value: f32) bool {
        std.debug.assert(value <= @as(f32, 1.0));
        std.debug.assert(value >= @as(f32, 0.0));
        return self.impl.setOpacity(value);
    }

    /// Brings the window to the front and acquires input focus.
    /// Has no effect if the window is already in focus, minimized,
    /// or not visible.
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
    /// returns true if the request was successful.
    pub fn requestUserAttention(self: *const Self) bool {
        if (!self.impl.data.flags.is_focused) {
            return self.impl.flash();
        }
        return false;
    }

    /// Switches the window to fullscreen or back to windowed mode.
    /// if the function succeeds it returns true else it returns false.
    /// # Parameters
    /// `value`: whether to set or exit fullscreen mode.
    pub fn setFullscreen(
        self: *Self,
        value: bool,
    ) bool {
        return self.impl.setFullscreen(value);
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
    /// e.g: On my windows laptop with a 120 DPI monitor this function returns
    /// 1.25(120/96)
    /// # Notes
    /// It's important to take the scale factor into consideration when drawing
    /// to the window, as it makes the result looks more "crisp"
    /// e.g: an image might be 64 virtual pixels tall, but with a scale
    /// factor of 2.0,
    /// it should drawn with 128 physical pixels for it to appear good.
    /// `EventType.DPIChange` can be tracked to monitor changes in the dpi,
    /// and the scale factor.
    pub fn getContentScale(self: *const Self) f64 {
        var scale: f64 = undefined;
        _ = self.impl.getScalingDPI(&scale);
        return scale;
    }

    /// Returns the 2D virtual desktop coordinates of the mouse cursor,
    /// relative to the client_area's top-left corner.
    /// # Notes
    /// The top-left corner of the client area is considered to be
    /// the origin point(0,0), with y axis pointing to the bottom,
    /// and the x axis pointing to the right
    pub inline fn getCursorPosition(self: *const Self) common.geometry.Point2D {
        return self.impl.getCursorPosition();
    }

    /// Returns true if the cursor is hovering on the window,
    /// i.e the cursor is inside the window area.
    /// # Notes
    /// If you want to automatically be notified
    /// of cursor entering and exiting the window area.
    /// you can track the `EventType.MouseEnter`
    /// and `EventType.MouseExit` events.
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
    /// The specified position should be relative to the client area's
    /// top-left corner. with everything above it having a negative y-coord,
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
    /// to the inside of the client area preventing it's hotspot from
    /// leaving the window.
    /// `CursorMode.Hidden`: this is equivalent to both capturing the cursor,
    /// and removing it's visibility.
    pub inline fn setCursorMode(
        self: *Self,
        mode: common.cursor.CursorMode,
    ) void {
        self.impl.setCursorMode(mode);
    }

    /// Sets whether the window accepts dropping files or not.
    /// by default any window created doesn't allow file to be dragged
    /// and dropped.
    /// # Parameters
    /// `allow`: true to allow file dropping, false to block it.
    pub inline fn allowDragAndDrop(self: *Self, allow: bool) void {
        self.impl.setDragAndDrop(allow);
    }

    /// Returns a slice that holds the path(s) to the latest dropped file(s)
    /// # Note
    /// User should only call this function when receiving a
    /// `EventType.FileDrop` event, otherwise it returns undefined data.
    /// Caller shouldn't attempt to free or modify the returned slice
    /// and should instead call `Window.freeDroppedFiles` if they wish
    /// to free the cache. The returned slice may gets invalidated and mutated
    /// during the next file drop event
    pub inline fn getDroppedFilesURI(self: *const Self) [][]const u8 {
        return self.impl.getDroppedFiles();
    }

    /// Frees the memory used to hold the dropped file(s) path(s).
    /// # Note
    /// Each window keeps a cache of the last dropped file(s) path(s)
    /// in heap memory, the allocated memory is reused whenever a new drop happens
    /// and may get resized if more space is needed.
    /// User may want to call this function to manage
    /// that memory as they see fit.
    pub inline fn freeDroppedFilesURI(self: *Self) void {
        return self.impl.freeDroppedFiles();
    }

    /// Sets the window's icon to the RGBA pixels data.
    /// # Parameters
    /// `pixels`: a slice to the icon's pixel(RGBA) data or null
    /// to set the platform default icon.
    /// `width` : the width of the icon in pixels.
    /// `height`: the height of the icon in pixels.
    /// 'allocator': some platform require the pixel data to be transformed,
    /// the allocator is used to dynamically create the recepient buffer.
    /// # Notes
    /// This function expects non-premultiplied, 32-bits RGBA pixels
    /// i.e. each channel's value should not be scaled by the alpha
    /// value, and should be
    /// represented using 8-bits, with the Red Channel being first followed
    /// by the blue,the green, and the alpha last.
    /// If the pixels slice is null width and height can be set to whatever.
    pub inline fn setIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        allocator: std.mem.Allocator,
    ) !void {
        if (pixels != null) {
            std.debug.assert(width > 0 and height > 0);
            std.debug.assert(pixels.?.len == (width * height * 4));
        }
        try self.impl.setIcon(pixels, width, height, allocator);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Parameters
    /// `pixels`: a slice to the cursor image's pixel(RGBA) data or null
    /// to use the platform's default cursor.
    /// `width` : the width of the icon in pixels.
    /// `height`: the height of the icon in pixels.
    /// `xhot`: the x coordinates of the cursor's hotspot.
    /// `yhot`: the y coordinates of the cursor's hotspot.
    /// # Notes
    /// Unlike `WidowContext.setWindowIcon` this function also takes
    /// the cooridnates of the cursor hotspot which is the pixel that
    /// the system tracks to decide mouse click target,
    /// the `xhot` and `yhot` parameters represent the x and y coordinates
    /// of that pixel relative to the top left corner of the image,
    /// with the x axis directed to the right and the y axis directed
    /// to the bottom. This function expects non-premultiplied,
    /// 32-bits RGBA pixels i.e. each channel's value should not be scaled
    /// by the alpha value, and should be represented using 8-bits,
    /// with the Red Channel being first followed by
    /// the blue,the green, and the alpha.
    /// If the pixels slice is null width,height,xhot and yhot
    /// can be set to whatever.
    pub inline fn setCursorIcon(
        self: *Self,
        pixels: ?[]const u8,
        width: i32,
        height: i32,
        xhot: u32,
        yhot: u32,
    ) !void {
        if (pixels != null) {
            std.debug.assert(width > 0 and height > 0);
            std.debug.assert(pixels.?.len == (width * height * 4));
        }
        try self.impl.setCursorIcon(pixels, width, height, xhot, yhot);
    }

    /// Sets the Widow's cursor to an image from the RGBA pixels data.
    /// # Parameters
    /// `cursor_shape`: cursor to set from the NativeCursorShape enum.
    pub inline fn setNativeCursorIcon(
        self: *Self,
        cursor_shape: common.cursor.NativeCursorShape,
    ) !void {
        try self.impl.setNativeCursorIcon(cursor_shape);
    }

    /// Returns the descriptor or handle used by the platform to
    /// identify the window.
    /// the platform handle can also be used as an id for the window
    /// although the values are unpredicatble.
    pub inline fn getPlatformHandle(self: *const Self) platform.WindowHandle {
        return self.impl.handle;
    }

    /// Initializes an opengl rendering context for the window and returns
    /// it. the context creation can be customized through the `cfg` struct
    pub inline fn initGLContext(
        self: *Self,
    ) !platform.GLContext {
        return self.impl.getGLContext();
    }

    /// Activate or deactivate raw mouse input for the window,
    /// returns true on success.
    ///# Note
    /// raw mouse inputs will only be delivered when
    /// the cursor need to be set to hidden mode.
    pub inline fn setRawMouseMotion(self: *Self, active: bool) bool {
        return self.impl.setRawMouseMotion(active);
    }

    // Prints some debug information to stdout.
    // if compiled in non Debug mode it does nothing.
    pub fn debugInfos(self: *const Self, size: bool, flags: bool) void {
        if (common.IS_DEBUG_BUILD) {
            self.impl.debugInfos(size, flags);
        }
    }
};
