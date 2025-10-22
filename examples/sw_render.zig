const std = @import("std");
const builtin = std.builtin;
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

const dbg = std.debug;
const math = std.math;

pub inline fn castNumeric(comptime T: type, x: anytype) T {
    switch (@typeInfo(@TypeOf(x))) {
        .int => switch (@typeInfo(T)) {
            .int => return @intCast(x),
            .float => return @floatFromInt(x),
            else => @compileError("casting from " ++ @typeName(@TypeOf(x)) ++ " to " ++ @typeName(T) ++ " is not supported"),
        },
        .float => switch (@typeInfo(T)) {
            .int => return @intFromFloat(x),
            .float => return @floatCast(x),
            else => @compileError("casting from " ++ @typeName(@TypeOf(x)) ++ " to " ++ @typeName(T) ++ " is not supported"),
        },
        .comptime_int, .comptime_float => return @as(T, x),
        else => @compileError(@typeName(@TypeOf(x)) ++ " isn't a numeric type"),
    }
}

pub inline fn @"i8"(x: anytype) i8 {
    return castNumeric(i8, x);
}

pub inline fn @"u8"(x: anytype) u8 {
    return castNumeric(u8, x);
}

pub inline fn @"i16"(x: anytype) i16 {
    return castNumeric(i16, x);
}

pub inline fn @"u16"(x: anytype) u16 {
    return castNumeric(u16, x);
}

pub inline fn @"i32"(x: anytype) i32 {
    return castNumeric(i32, x);
}

pub inline fn @"u32"(x: anytype) u32 {
    return castNumeric(u32, x);
}

pub inline fn @"i64"(x: anytype) i64 {
    return castNumeric(i64, x);
}

pub inline fn @"u64"(x: anytype) u64 {
    return castNumeric(u64, x);
}

pub inline fn @"f32"(x: anytype) f32 {
    return castNumeric(f32, x);
}

pub inline fn @"f64"(x: anytype) f64 {
    return castNumeric(f64, x);
}

const NUM_CUBE_POINTS = 2 * 2 * 2;
var cube_points = [NUM_CUBE_POINTS]f32x3{
    // 4 world units for each edge
    // front 4
    // A-B
    // D-C
    .{ 1, 2, 1 }, //D
    .{ 4, 2, 1 }, //C
    .{ 4, 2, 4 }, //B
    .{ 1, 2, 4 }, //A
    // back 4
    // X-Y
    // W-Z
    .{ 1, 3, 1 }, //W
    .{ 4, 3, 1 }, //Z
    .{ 4, 3, 4 }, //Y
    .{ 1, 3, 4 }, //X
};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    const ctx = try widow.createWidowContext(allocator);
    defer widow.destroyWidowContext(allocator, ctx);

    var ev_queue = try EventQueue.init(allocator, 256);
    defer ev_queue.deinit();

    var builder = widow.WindowBuilder.init();
    var mywindow = builder.withTitle("Software rendered Window")
        .withSize(640, 480)
        .withPosition(200, 200)
        .withDecoration(true)
        .withResize(true)
        .withEventQueue(&ev_queue)
        .withFrameBuffer(&.{
            .depth_bits = 24,
            .stencil_bits = 8,
            .color = .{
                .red_bits = 8,
                .green_bits = 8,
                .blue_bits = 8,
                .alpha_bits = 8,
            },
            .accum = .{
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
            .accel = .{ .software = {} },
        })
        .build(ctx, null) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // closes the window when done.
    defer mywindow.deinit();
    mywindow.focus();

    var sw_canvas = try mywindow.createCanvas();
    defer sw_canvas.deinit();

    var pbuff: [1024]u8 = undefined;
    var p_wr = std.io.Writer.fixed(&pbuff);
    const success = sw_canvas.getDriverInfo(&p_wr);
    if (success) {
        std.debug.print("{s}\n", .{p_wr.buffered()});
    }
    std.debug.print("Render API:{t}\n", .{sw_canvas.getDriverName()});
    std.debug.print("Framebuffer pixel format :{t}\n", .{sw_canvas.getPixelFormatInfo().fmt});

    std.debug.print("DPI Info:{}\n", .{mywindow.getDpiInfo()});

    initTicks();
    var rend = Renderer.init(sw_canvas);
    var in_key = KeyCode.C;
    const CAM_SPEED = 5;
    var cam = Camera{ .position = .{ 0, 0, 0 }, .deg_fov_x = 520, .aspect_ratio = @as(f32, 800.0) / 600.0 };
    var frame_start: u64 = 0;
    var frame_end: u64 = 0;
    const TARGET_FRAME_TIME = 16 * std.time.ns_per_ms;
    event_loop: while (true) {
        var last_frame_time = frame_end - frame_start;
        if (last_frame_time < TARGET_FRAME_TIME) {
            widow.time.waitForNs(TARGET_FRAME_TIME - last_frame_time);
            last_frame_time = TARGET_FRAME_TIME;
        }

        const dt = @"f64"(last_frame_time) / std.time.ns_per_s;
        frame_start = getTicksNs();
        dbg.print(
            "last frame: {} ms, {d} FPS\n",
            .{ @divTrunc(last_frame_time, std.time.ns_per_ms), std.time.ns_per_s / @"f64"(last_frame_time) },
        );
        try mywindow.pollEvents();

        var event: widow.event.Event = undefined;

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => break :event_loop,
                EventType.Keyboard => |*key| {
                    in_key = key.keycode;
                    if (key.state.isPressed()) {
                        if (key.keycode == KeyCode.Q) {
                            mywindow.queueCloseEvent();
                        }

                        if (key.keycode == KeyCode.E) {
                            _ = mywindow.setFullscreen(true);
                        }

                        if (key.keycode == KeyCode.Escape) {
                            _ = mywindow.setFullscreen(false);
                        }

                        if (key.keycode == .Down) {
                            cam.position[1] += CAM_SPEED * -1 * @"f32"(dt);
                        }

                        if (key.keycode == .Up) {
                            cam.position[1] += CAM_SPEED * 1 * @"f32"(dt);
                        }

                        if (key.keycode == .Right) {
                            cam.position[0] += CAM_SPEED * 1 * @"f32"(dt);
                        }

                        if (key.keycode == .Left) {
                            cam.position[0] += CAM_SPEED * -1 * @"f32"(dt);
                        }
                    }
                },

                EventType.WindowResize => |*ev| {
                    std.debug.print(
                        "Window logical size (wxh={}x{})\t physical size (wxh={}x{})\t scale factor {}\n",
                        .{
                            ev.new_size.logical_width,
                            ev.new_size.logical_height,
                            ev.new_size.physical_width,
                            ev.new_size.physical_height,
                            ev.new_size.scale,
                        },
                    );
                    rend.updateFramebuffer(ev.new_size.physical_width, ev.new_size.physical_height);
                    cam.aspect_ratio = @"f32"(ev.new_size.physical_width) / @"f32"(ev.new_size.physical_height);
                },
                else => continue,
            }
        }

        { // drawing routine
            rend.clearRenderTarget(RGBA.BLACK);
            var scr_pts: [NUM_CUBE_POINTS]i32x2 = std.mem.zeroes([NUM_CUBE_POINTS]i32x2);
            for (&cube_points, 0..) |*p, i| {
                // p.* = rotateYDeg(p.*, @floatCast(60.0 * dt));
                const view_p = camToViewport(&cam, p.*);
                if (@abs(view_p[0]) > 1 or @abs(view_p[1]) > 1) continue; //skip
                scr_pts[i] = viewportToCanvas(
                    view_p[0],
                    view_p[1],
                    @"f32"(rend.frame.width),
                    @"f32"(rend.frame.height),
                );
            }

            rend.drawLine(scr_pts[0][0], scr_pts[0][1], scr_pts[1][0], scr_pts[1][1], RGBA.GREEN);
            rend.drawLine(scr_pts[1][0], scr_pts[1][1], scr_pts[2][0], scr_pts[2][1], RGBA.GREEN);
            rend.drawLine(scr_pts[2][0], scr_pts[2][1], scr_pts[3][0], scr_pts[3][1], RGBA.GREEN);
            rend.drawLine(scr_pts[3][0], scr_pts[3][1], scr_pts[0][0], scr_pts[0][1], RGBA.GREEN);

            rend.drawLine(scr_pts[4][0], scr_pts[4][1], scr_pts[5][0], scr_pts[5][1], RGBA.FAV_RED);
            rend.drawLine(scr_pts[5][0], scr_pts[5][1], scr_pts[6][0], scr_pts[6][1], RGBA.FAV_RED);
            rend.drawLine(scr_pts[6][0], scr_pts[6][1], scr_pts[7][0], scr_pts[7][1], RGBA.FAV_RED);
            rend.drawLine(scr_pts[7][0], scr_pts[7][1], scr_pts[4][0], scr_pts[4][1], RGBA.FAV_RED);

            rend.drawLine(scr_pts[4][0], scr_pts[4][1], scr_pts[0][0], scr_pts[0][1], RGBA.BLUE);
            rend.drawLine(scr_pts[5][0], scr_pts[5][1], scr_pts[1][0], scr_pts[1][1], RGBA.BLUE);
            rend.drawLine(scr_pts[6][0], scr_pts[6][1], scr_pts[2][0], scr_pts[2][1], RGBA.BLUE);
            rend.drawLine(scr_pts[7][0], scr_pts[7][1], scr_pts[3][0], scr_pts[3][1], RGBA.BLUE);
        }

        rend.present();

        frame_end = getTicksNs();
    }
}

fn renderWeirdGradient(framebuffer: []u32) void {
    const now: f64 = @floatFromInt(std.time.timestamp());
    const PI: f64 = std.math.pi;
    const r: f64 = 0.5 + (0.5 * std.math.sin(now));
    const g: f64 = 0.5 + (0.5 * std.math.sin(now + (PI * 2 / 3)));
    const b: f64 = 0.5 + (0.5 * std.math.sin(now + (PI * 4 / 3)));
    var argb = [4]u8{ 255, @intFromFloat(255 * r), @intFromFloat(255 * g), @intFromFloat(255 * b) };
    const color_ = std.mem.readInt(u32, &argb, .big);
    for (framebuffer) |*pixel|
        pixel.* = color_;
}

pub inline fn mapRGBA(fmt: *const widow.gfx.PixelFormatInfo, r: u32, g: u32, b: u32, a: u32) u32 {
    const r_shr = r >> @intCast(fmt.red.loss);
    const red = r_shr << @intCast(fmt.red.shift);

    const g_shr = g >> @intCast(fmt.green.loss);
    const green = g_shr << @intCast(fmt.green.shift);

    const b_shr = b >> @intCast(fmt.blue.loss);
    const blue = b_shr << @intCast(fmt.blue.shift);

    const a_shr = a >> @intCast(fmt.alpha.loss);
    const alpha = a_shr << @intCast(fmt.alpha.shift);

    return red | green | blue | alpha;
}

pub inline fn mapRGB(fmt: *const widow.gfx.PixelFormatInfo, r: u32, g: u32, b: u32) u32 {
    const r_shr = r >> @intCast(fmt.red.loss);
    const red = r_shr << @intCast(fmt.red.shift);

    const g_shr = g >> @intCast(fmt.green.loss);
    const green = g_shr << @intCast(fmt.green.shift);

    const b_shr = b >> @intCast(fmt.blue.loss);
    const blue = b_shr << @intCast(fmt.blue.shift);

    return red | green | blue;
}

pub const i32x2 = [2](i32);
pub const i32x3 = [3](i32);
pub const i32x4 = [4](i32);
pub const f32x2 = [2](f32);
pub const f32x3 = [3](f32);
pub const f32x4 = [4](f32);
pub const i64x2 = [2](i64);
pub const i64x3 = [3](i64);
pub const i64x4 = [4](i64);

pub const u32x2 = [2](u32);
pub const u32x3 = [3](u32);

// row major
pub const Mat2 = [2](f32x2);
pub const Mat3 = [3](f32x3);
pub const Mat4 = [4](f32x4);

pub const Rgba8 = [4](u8);
pub const RgbaF32 = f32x4;

const RGBA = struct {
    pub const BLACK: Rgba8 = .{ 0, 0, 0, 255 };
    pub const WHITE: Rgba8 = .{ 255, 255, 255, 255 };
    pub const TRANSPARENT: Rgba8 = .{ 0, 0, 0, 0 };
    pub const RED: Rgba8 = .{ 255, 0, 0, 255 };
    pub const GREEN: Rgba8 = .{ 0, 255, 0, 255 };
    pub const BLUE: Rgba8 = .{ 0, 0, 255, 255 };
    pub const LIGHTGRAY: Rgba8 = .{ 199, 199, 199, 255 };
    pub const GRAY: Rgba8 = .{ 130, 130, 130, 255 };
    pub const DARKGRAY: Rgba8 = .{ 79, 79, 79, 255 };
    pub const YELLOW: Rgba8 = .{ 252, 250, 0, 255 };
    pub const GOLD: Rgba8 = .{ 255, 204, 0, 255 };
    pub const ORANGE: Rgba8 = .{ 255, 161, 0, 255 };
    pub const PINK: Rgba8 = .{ 255, 110, 194, 255 };
    pub const MAROON: Rgba8 = .{ 191, 33, 56, 255 };
    pub const LIME: Rgba8 = .{ 0, 158, 46, 255 };
    pub const DARKGREEN: Rgba8 = .{ 0, 117, 43, 255 };
    pub const SKYBLUE: Rgba8 = .{ 102, 191, 255, 255 };
    pub const DARKBLUE: Rgba8 = .{ 0, 82, 171, 255 };
    pub const PURPLE: Rgba8 = .{ 199, 122, 255, 255 };
    pub const VIOLET: Rgba8 = .{ 135, 61, 191, 255 };
    pub const DARKPURPLE: Rgba8 = .{ 112, 31, 125, 255 };
    pub const BEIGE: Rgba8 = .{ 212, 176, 130, 255 };
    pub const BROWN: Rgba8 = .{ 128, 107, 79, 255 };
    pub const DARKBROWN: Rgba8 = .{ 77, 64, 46, 255 };
    pub const MAGENTA: Rgba8 = .{ 255, 0, 255, 255 };
    pub const FAV_RED: Rgba8 = .{ 219, 105, 105, 255 };
    // float version
    pub const BLACK_F32: RgbaF32 = .{ 0.0, 0.0, 0.0, 1.0 };
    pub const WHITE_F32: RgbaF32 = .{ 1.0, 1.0, 1.0, 1.0 };
    pub const TRANSPARENT_F32: RgbaF32 = .{ 0.0, 0.0, 0.0, 0.0 };
    pub const RED_F32: RgbaF32 = .{ 1.0, 0.0, 0.0, 1.0 };
    pub const GREEN_F32: RgbaF32 = .{ 0.0, 1.0, 0.0, 1.0 };
    pub const BLUE_F32: RgbaF32 = .{ 0.0, 0.0, 1.0, 1.0 };
    pub const LIGHTGRAY_F32: RgbaF32 = .{ 0.78, 0.78, 0.78, 1.0 };
    pub const GRAY_F32: RgbaF32 = .{ 0.51, 0.51, 0.51, 1.0 };
    pub const DARKGRAY_F32: RgbaF32 = .{ 0.31, 0.31, 0.31, 1.0 };
    pub const YELLOW_F32: RgbaF32 = .{ 0.99, 0.98, 0.00, 1.0 };
    pub const GOLD_F32: RgbaF32 = .{ 1.00, 0.80, 0.00, 1.0 };
    pub const ORANGE_F32: RgbaF32 = .{ 1.00, 0.63, 0.00, 1.0 };
    pub const PINK_F32: RgbaF32 = .{ 1.00, 0.43, 0.76, 1.0 };
    pub const MAROON_F32: RgbaF32 = .{ 0.75, 0.13, 0.22, 1.0 };
    pub const LIME_F32: RgbaF32 = .{ 0.00, 0.62, 0.18, 1.0 };
    pub const DARKGREEN_F32: RgbaF32 = .{ 0.00, 0.46, 0.17, 1.0 };
    pub const SKYBLUE_F32: RgbaF32 = .{ 0.40, 0.75, 1.00, 1.0 };
    pub const DARKBLUE_F32: RgbaF32 = .{ 0.00, 0.32, 0.67, 1.0 };
    pub const PURPLE_F32: RgbaF32 = .{ 0.78, 0.48, 1.00, 1.0 };
    pub const VIOLET_F32: RgbaF32 = .{ 0.53, 0.24, 0.75, 1.0 };
    pub const DARKPURPLE_F32: RgbaF32 = .{ 0.44, 0.12, 0.49, 1.0 };
    pub const BEIGE_F32: RgbaF32 = .{ 0.83, 0.69, 0.51, 1.0 };
    pub const BROWN_F32: RgbaF32 = .{ 0.50, 0.42, 0.31, 1.0 };
    pub const DARKBROWN_F32: RgbaF32 = .{ 0.30, 0.25, 0.18, 1.0 };
    pub const MAGENTA_F32: RgbaF32 = .{ 1.00, 0.00, 1.00, 1.0 };
    pub const FAV_RED_F32: RgbaF32 = .{ 0.859, 0.412, 0.412, 1.0 };
};

pub const Color32 = Rgba8;

pub const Renderer = struct {
    target: widow.gfx.Canvas,

    // canvas coordinates
    //                           h/2(1.0)
    //          ┌───────────────────│───────────────────┐
    //          │                   │                   │
    //          │                   │                   │
    //          │                   │                   │
    //-w/2(-1.0)<───────────────────│───────────────────> w/2(1.0)
    //          │                   │                   │
    //          │                   │                   │
    //          │                   │                   │
    //          └───────────────────│───────────────────┘
    //                           -h/2(-1.0)
    frame: struct {
        buffer: []u32,
        width: u32,
        height: u32,
        pitch: u32,
    },
    fb_format: widow.gfx.PixelFormatInfo,

    const Self = @This();

    pub fn init(target: widow.gfx.Canvas) Self {
        var pixels: []u32 = &.{};
        var w: u32, var h: u32, var pitch: u32 = .{ 0, 0, 0 };
        const success = target.getSoftwareBuffer(&pixels, &w, &h, &pitch);
        dbg.assert(success);
        dbg.print("Software framebuffer:({}x{}) with pitch:{}\n", .{ w, h, pitch });
        dbg.assert(target.getPixelFormatInfo().bytes_per_pixel == 4); // the renderer doesn't support any other colordepth
        return .{
            .target = target,
            .frame = .{
                .buffer = pixels,
                .width = w,
                .height = h,
                .pitch = pitch,
            },
            .fb_format = target.getPixelFormatInfo(),
        };
    }

    pub inline fn clearRenderTarget(self: *Self, clear_color: Color32) void {
        const c: u32 = mapRGBA(
            &self.fb_format,
            clear_color[0],
            clear_color[1],
            clear_color[2],
            clear_color[3],
        );
        @memset(self.frame.buffer, c);
    }

    inline fn normalizeCoordinates(self: *const Self, x: i32, y: i32) [2]i32 {
        dbg.assert(self.frame.width > 0);
        dbg.assert(self.frame.height > 0);
        dbg.assert(self.frame.width % 2 == 0);
        dbg.assert(@abs(x * 2) <= self.frame.width);
        dbg.assert(@abs(y * 2) <= self.frame.height);
        const W_DIV_2 = @"i32"(self.frame.width / 2);
        const H_DIV_2 = @"i32"(self.frame.height / 2);
        var nx = x + W_DIV_2;
        var ny = H_DIV_2 - y;
        // NOTE: both w/2 and (w/2) - 1 point ot the same pixel
        if (nx == self.frame.width) nx -= 1;
        // NOTE: both -h/2 and (h/2) - 1 point ot the same pixel
        if (ny == self.frame.height) ny -= 1;
        dbg.print("Normalizing ({},{}) => ({}x{})\n", .{ x, y, nx, ny });
        return .{ nx, ny };
    }

    inline fn canvasToRasterCoords(self: *const Self, x: i32, y: i32) [2]i32 {
        dbg.assert(self.frame.width > 0);
        dbg.assert(self.frame.height > 0);
        dbg.assert(self.frame.width % 2 == 0);

        if (@abs(x * 2) > self.frame.width or
            @abs(y * 2) > self.frame.height) return .{ -1, -1 };

        const W_DIV_2 = @"i32"(self.frame.width / 2);
        const H_DIV_2 = @"i32"(self.frame.height / 2);
        var nx = x + W_DIV_2;
        var ny = H_DIV_2 - y;
        // NOTE: both w/2 and (w/2) - 1 point ot the same pixel
        if (nx == self.frame.width) nx -= 1;
        // NOTE: both -h/2 and (h/2) - 1 point ot the same pixel
        if (ny == self.frame.height) ny -= 1;
        dbg.print("Normalizing ({},{}) => ({}x{})\n", .{ x, y, nx, ny });
        return .{ nx, ny };
    }

    pub fn putPixel(self: *Self, x: i32, y: i32, c: Color32) void {
        const nx: i32, const ny: i32 = self.canvasToRasterCoords(x, y);
        if (nx == -1) return; // don't plot

        self.frame.buffer[(self.frame.pitch / self.fb_format.bytes_per_pixel) * @"u32"(ny) + @"u32"(nx)] =
            mapRGBA(&self.fb_format, c[0], c[1], c[2], c[3]);
    }

    inline fn drawBrLine(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, color: u32) void {
        const pitch = (self.frame.pitch / self.fb_format.bytes_per_pixel);
        const dy: i32 = @intCast(@abs(y1 - y0));
        const dx: i32 = @intCast(@abs(x1 - x0));
        if (dx >= dy) {
            var x, var y, const x_end, const y_end = if (x0 < x1)
                .{ x0, y0, x1, y1 }
            else
                .{ x1, y1, x0, y0 };

            var d = (2 * dy) - dx; // d = 2*err*delta_x + 2*delta_y - delta_x
            const d_inc0 = 2 * dy;
            const d_inc1 = 2 * (dy - dx);
            const y_inc: i32 = if (y > y_end) -1 else 1;
            while (x <= x_end) : (x += 1) {
                self.frame.buffer[pitch * @"u32"(y) + @"u32"(x)] = color;
                if (d < 0) {
                    d += d_inc0;
                } else {
                    d += d_inc1;
                    y += y_inc;
                }
            }
        } else {
            var y, var x, const y_end, const x_end = if (y0 < y1)
                .{ y0, x0, y1, x1 }
            else
                .{ y1, x1, y0, x0 };

            var d = (2 * dx) - dy; // d = 2*err*delta_y + 2*delta_x - delta_y
            const d_inc0 = 2 * dx;
            const d_inc1 = 2 * (dx - dy);
            const x_inc: i32 = if (x > x_end) -1 else 1;

            while (y <= y_end) : (y += 1) {
                self.frame.buffer[pitch * @"u32"(y) + @"u32"(x)] = color;
                if (d < 0) {
                    d += d_inc0;
                } else {
                    d += d_inc1;
                    x += x_inc;
                }
            }
        }
    }

    inline fn drawHorizLine(self: *Self, nx0: i32, nx1: i32, ny: i32, color: u32) void {
        const len: i32 = nx1 - nx0;

        const start: usize = if (len >= 0)
            (self.frame.pitch / self.fb_format.bytes_per_pixel) * @"u32"(ny) + @"u32"(nx0)
        else
            (self.frame.pitch / self.fb_format.bytes_per_pixel) * @"u32"(ny) + @"u32"(nx1);

        @memset(self.frame.buffer[start..(start + @abs(len) + 1)], color);
    }

    inline fn drawVertiLine(self: *Self, ny0: i32, ny1: i32, nx: i32, color: u32) void {
        const pitch = self.frame.pitch / self.fb_format.bytes_per_pixel;
        const len: i32 = ny1 - ny0;

        var start: usize = if (len >= 0)
            pitch * @"u32"(ny0) + @"u32"(nx)
        else
            pitch * @"u32"(ny1) + @"u32"(nx);

        var end: u32 = @abs(len) + 1;

        while (end > 0) : (end -= 1) {
            self.frame.buffer[start] = color;
            start += pitch;
        }
    }

    inline fn drawDiagLine(self: *Self, nx0: i32, ny0: i32, nx1: i32, ny1: i32, color: u32) void {
        var pitch = self.frame.pitch / self.fb_format.bytes_per_pixel;

        var start: usize = 0;
        const len = ny1 - ny0;
        if (len >= 0) {
            start = pitch * @"u32"(ny0) + @"u32"(nx0);
            if (nx0 <= nx1) pitch += 1 else pitch -= 1;
        } else {
            start = pitch * @"u32"(ny1) + @"u32"(nx1);
            if (nx1 <= nx0) pitch += 1 else pitch -= 1;
        }

        var end: u32 = @abs(len) + 1;

        while (end > 0) : (end -= 1) {
            self.frame.buffer[start] = color;
            start += pitch;
        }
    }

    pub fn drawLine(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, c: Color32) void {
        const color = mapRGBA(&self.fb_format, c[0], c[1], c[2], c[3]);
        const nx0, const ny0 = self.normalizeCoordinates(x0, y0);
        const nx1, const ny1 = self.normalizeCoordinates(x1, y1);

        if (y0 == y1) {
            self.drawHorizLine(nx0, nx1, ny0, color);
            return;
        } else if (x0 == x1) {
            self.drawVertiLine(ny0, ny1, nx0, color);
            return;
        } else if (y1 - y0 == x1 - x0) {
            self.drawDiagLine(nx0, ny0, nx1, ny1, color);
        }

        self.drawBrLine(nx0, ny0, nx1, ny1, color);
    }

    pub fn drawTriangle(self: *Self, v0: i32x2, v1: i32x2, v2: i32x2, c: Color32) void {
        self.drawLine(v0[0], v0[1], v1[0], v1[1], c);
        self.drawLine(v0[0], v0[1], v2[0], v2[1], c);
        self.drawLine(v1[0], v1[1], v2[0], v2[1], c);
    }

    /// scanline rasterization
    /// doesn't follow any fill convention
    pub fn fillTriangleClassic(self: *Self, v0: i32x2, v1: i32x2, v2: i32x2, c: Color32) void {
        const color = mapRGBA(&self.fb_format, c[0], c[1], c[2], c[3]);

        var nv0 = self.normalizeCoordinates(v0[0], v0[1]);
        var nv1 = self.normalizeCoordinates(v1[0], v1[1]);
        var nv2 = self.normalizeCoordinates(v2[0], v2[1]);

        {
            // verticies sorting by Y
            if (nv1[1] < nv0[1]) {
                const tmp = nv0;
                nv0 = nv1;
                nv1 = tmp;
            }
            if (nv2[1] < nv0[1]) {
                const tmp = nv0;
                nv0 = nv2;
                nv2 = tmp;
            }
            if (nv2[1] < nv1[1]) {
                const tmp = nv1;
                nv1 = nv2;
                nv2 = tmp;
            }
        }

        const min_y = nv0[1];
        const max_y_1 = nv1[1];
        const max_y_2 = nv2[1];

        const total_height = max_y_2 - min_y;
        dbg.assert(total_height > 0);

        const pitch: u32 = (self.frame.pitch / self.fb_format.bytes_per_pixel);
        var y = min_y;
        var offset: usize = @"u32"(y) * pitch;
        { // first half
            const segment_height = max_y_1 - min_y;
            while (y <= max_y_1) : ({
                y += 1;
                offset += pitch;
            }) {
                const m02: f32 = @"f32"(y - min_y) / @"f32"(total_height);
                const m01: f32 = @"f32"(y - min_y) / @"f32"(segment_height);
                const a = lerp(@"f32"(nv0[0]), @"f32"(nv2[0]), m02);
                const b = lerp(@"f32"(nv0[0]), @"f32"(nv1[0]), m01);
                const next_x01: i32 = @intFromFloat(a);
                const next_x02: i32 = @intFromFloat(b);
                const min_x = @min(next_x01, next_x02);
                var max_x = next_x01 ^ next_x02;
                max_x = max_x ^ min_x;

                const start: usize = offset + @"u32"(min_x + 1);
                const len: usize = @intCast(max_x - min_x);
                @memset(self.frame.buffer[start..(start + len)], color);
            }
        }

        { // second half
            const segment_height = max_y_2 - max_y_1;
            while (y <= max_y_2) : ({
                y += 1;
                offset += pitch;
            }) {
                const m02: f32 = @"f32"(y - min_y) / @"f32"(total_height);
                const m01: f32 = @"f32"(y - max_y_1) / @"f32"(segment_height);
                const a = lerp(@"f32"(nv0[0]), @"f32"(nv2[0]), m02);
                const b = lerp(@"f32"(nv1[0]), @"f32"(nv2[0]), m01);
                const next_x01: i32 = @intFromFloat(a);
                const next_x02: i32 = @intFromFloat(b);
                const min_x = @min(next_x01, next_x02);
                var max_x = next_x01 ^ next_x02;
                max_x = max_x ^ min_x;

                const start: usize = offset + @"u32"(min_x + 1);
                const len: usize = @intCast(max_x - min_x);
                @memset(self.frame.buffer[start..(start + len)], color);
            }
        }
    }

    pub fn fillTriangle(
        self: *Self,
        v0: i32x2,
        v1: i32x2,
        v2: i32x2,
        c0: Color32,
        c1: Color32,
        c2: Color32,
    ) void {
        const nv0 = self.normalizeCoordinates(v0[0], v0[1]);
        var nv1 = self.normalizeCoordinates(v1[0], v1[1]);
        var nc1 = c1;
        var nv2 = self.normalizeCoordinates(v2[0], v2[1]);
        var nc2 = c2;

        const is_flat_colored = arrayEq(c0, c1) and arrayEq(c1, c2);

        var min_x: i32, var max_x: i32 = .{ 0, 0 };
        var min_y: i32, var max_y: i32 = .{ 0, 0 };

        { // find rectangle bounding box
            min_x = @min(nv0[0], @min(nv1[0], nv2[0]));
            max_x = @max(nv0[0], @max(nv1[0], nv2[0]));
            min_y = @min(nv0[1], @min(nv1[1], nv2[1]));
            max_y = @max(nv0[1], @max(nv1[1], nv2[1]));
        }

        var area = cross2(sub2(nv1, nv0), sub2(nv2, nv0));
        if (area == 0) return;
        if (area < 0) {
            // enforce clockwise configuration
            const tmp = nv1;
            nv1 = nv2;
            nv2 = tmp;
            if (!is_flat_colored) {
                const c_tmp = nc1;
                nc1 = nc2;
                nc2 = c_tmp;
            }
            area = -area;
        }

        const nv0v1 = sub2(nv1, nv0);
        const nv1v2 = sub2(nv2, nv1);
        const nv2v0 = sub2(nv0, nv2);
        const bias_w0: i32 = if (isTopLeftEdge(nv0, nv1)) 0 else -1;
        const bias_w1: i32 = if (isTopLeftEdge(nv1, nv2)) 0 else -1;
        const bias_w2: i32 = if (isTopLeftEdge(nv2, nv0)) 0 else -1;

        const pitch: u32 = (self.frame.pitch / self.fb_format.bytes_per_pixel);
        var start: usize = @"u32"(min_y) * pitch + @"u32"(min_x);
        var y: i32 = min_y;
        const v0p = sub2(i32x2{ min_x, y }, nv0);
        const v1p = sub2(i32x2{ min_x, y }, nv1);
        const v2p = sub2(i32x2{ min_x, y }, nv2);
        // bias is used to respect top-left rasterization rule
        var initial_w0 = edgeCross(nv0v1, v0p) + bias_w0;
        var initial_w1 = edgeCross(nv1v2, v1p) + bias_w1;
        var initial_w2 = edgeCross(nv2v0, v2p) + bias_w2;
        if (is_flat_colored) {
            const color = mapRGBA(&self.fb_format, c0[0], c0[1], c0[2], c0[3]);
            while (y <= max_y) : (y += 1) {
                var x: i32 = min_x;
                var w0 = initial_w0;
                var w1 = initial_w1;
                var w2 = initial_w2;

                while (x <= max_x + 1) : (x += 1) {
                    if (w0 >= 0 and w1 >= 0 and w2 >= 0)
                        self.frame.buffer[start + @"u32"(x - min_x)] = color;

                    w0 -= nv0v1[1];
                    w1 -= nv1v2[1];
                    w2 -= nv2v0[1];
                }
                initial_w0 += nv0v1[0];
                initial_w1 += nv1v2[0];
                initial_w2 += nv2v0[0];
                start += pitch;
            }
        } else {
            // baycentric color mapping
            while (y <= max_y) : (y += 1) {
                var x: i32 = min_x;
                var w0 = initial_w0;
                var w1 = initial_w1;
                var w2 = initial_w2;

                while (x <= max_x + 1) : (x += 1) {
                    if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                        const r: u32 = @intCast(@divTrunc((c0[0] * w1 + nc1[0] * w2 + nc2[0] * w0), area));
                        const g: u32 = @intCast(@divTrunc((c0[1] * w1 + nc1[1] * w2 + nc2[1] * w0), area));
                        const b: u32 = @intCast(@divTrunc((c0[2] * w1 + nc1[2] * w2 + nc2[2] * w0), area));
                        const a: u32 = @intCast(@divTrunc((c0[3] * w1 + nc1[3] * w2 + nc2[3] * w0), area));
                        const color = mapRGBA(&self.fb_format, r, g, b, a);
                        self.frame.buffer[start + @"u32"(x - min_x)] = @intCast(color);
                    }

                    w0 -= nv0v1[1];
                    w1 -= nv1v2[1];
                    w2 -= nv2v0[1];
                }
                initial_w0 += nv0v1[0];
                initial_w1 += nv1v2[0];
                initial_w2 += nv2v0[0];
                start += pitch;
            }
        }
    }

    pub fn fillRect(self: *Self, x: i32, y: i32, w: i32, h: i32, c0: Rgba8) void {
        dbg.assert(w > 0);
        dbg.assert(h > 0);

        const color = mapRGBA(&self.fb_format, c0[0], c0[1], c0[2], c0[3]);
        const pitch = (self.frame.pitch / self.fb_format.bytes_per_pixel);
        const nx0, const ny0 = self.normalizeCoordinates(x, y);

        const height: i32 = if (@"u32"(ny0 + h) <= self.frame.height)
            h
        else
            (@"i32"(self.frame.height) - (ny0));

        const width: u32 = if (@"u32"(nx0 + w) <= self.frame.width)
            @intCast(w)
        else
            (self.frame.width - @"u32"(nx0));

        const ny1 = ny0 + height;

        var start: usize = @"u32"(ny0) * pitch + @"u32"(nx0);
        var i = ny0;
        while (i < ny1) : (i += 1) {
            const end = start + width;
            @memset(self.frame.buffer[start..end], color);
            start += pitch;
        }
    }

    pub fn drawObject(self: *Self, verticies: []const i32x3, triangles: []const TriangleDesc) void {
        for (triangles) |t| {
            self.drawTriangle(
                projectVertex(verticies[t.indices[0]], 100),
                projectVertex(verticies[t.indices[1]], 100),
                projectVertex(verticies[t.indices[2]], 100),
                t.color,
            );
        }
    }

    pub inline fn present(self: *const Self) void {
        const ok = self.target.swapBuffers();
        std.debug.assert(ok);
    }

    pub fn updateFramebuffer(
        self: *Self,
        new_width: i32,
        new_height: i32,
    ) void {
        var success = self.target.updateSoftwareBuffer(new_width, new_height);
        std.debug.assert(success == true);
        success = self.target.getSoftwareBuffer(&self.frame.buffer, &self.frame.width, &self.frame.height, &self.frame.pitch);
        std.debug.assert(success == true);
        std.debug.print("Software framebuffer:({}x{}) with pitch:{}\n", .{ self.frame.width, self.frame.height, self.frame.pitch });
    }
};

inline fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

/// NOTE: this test is done in screen coordinate system (i.e x=>right, y=>down)
/// assumes clockwise winding of verticies
inline fn isTopLeftEdge(start: i32x2, end: i32x2) bool {
    const edge = .{ end[0] - start[0], end[1] - start[1] };
    // a left edge has negative dy assumes clockwise edge order
    const is_left_edge = edge[1] < 0;
    // an edge is top edge if start and end has same y value
    // and is above the third vertex
    const is_top_edge = edge[1] == 0 and edge[0] > 0;
    return is_top_edge or is_left_edge;
}

inline fn arrayEq(lhs: anytype, rhs: @TypeOf(lhs)) bool {
    const T = @TypeOf(lhs);
    const array_info = @typeInfo(T).array;
    var is_eq: bool = true;
    inline for (0..array_info.len) |i| {
        is_eq = is_eq and lhs[i] == rhs[i];
    }
    return is_eq;
}

inline fn edgeCross(a: i32x2, b: i32x2) i64 {
    // force i64 because these values might potentialy overflow
    return (@"i64"(a[0]) * b[1]) - (@"i64"(a[1]) * b[0]);
}

inline fn projectVertex(v: i32x3, distance: i32) i32x2 {
    return .{ @divTrunc(v[0] * distance, v[2]), @divTrunc(v[1] * distance, v[2]) };
}

pub const TriangleDesc = extern struct {
    indices: u32x3,
    color: Rgba8,
};

const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

pub const Camera = extern struct {
    position: f32x3,
    deg_fov_x: f32, // in degrees
    aspect_ratio: f32, // render surface w/h

    const Self = @This();

    /// This creates a symmetric frustum with horizontal FOV
    /// by converting 4 params (self.fov_x, self.aspect_ratio=w/h, near_plane, far_plane)
    /// to 6 params (l, r, b, t, n, f)
    pub fn makeFrustum(self: *const Self, near_plane: f32, far_plane: f32, out_mat: *Mat4) void {
        const front = (near_plane + self.position[1]);
        const back = (far_plane + self.position[1]);

        const tangent = @tan((self.deg_fov_x / 2) * math.rad_per_deg);
        const right = front * tangent;
        const top = right / self.aspect_ratio;
        out_mat[0] = @splat(0);
        out_mat[1] = @splat(0);
        out_mat[2] = @splat(0);
        out_mat[4] = @splat(0);

        out_mat[0][0] = front / right;
        out_mat[1][2] = front / top;
        out_mat[2][1] = (-front - back) / (front - back);
        out_mat[2][3] = (2 * front * back) / (front - back);
        out_mat[3][1] = 1;
    }

    pub fn makeFrustumX(self: *const Self, near_plane: f32, out_mat: *Mat3) void {
        const front = (near_plane + self.position[1]);

        const tangent = @tan((self.deg_fov_x / 2) * math.rad_per_deg);
        dbg.print("tg={d}\n", .{tangent});
        const right = (front * tangent) + self.position[0];
        const top = (right / self.aspect_ratio) + self.position[2];
        dbg.print("front:{d},right:{d},top:{d}\n", .{ front, right, top });
        // TODO ask user to zero the matrix
        out_mat[0] = @splat(0);
        out_mat[1] = @splat(0);
        out_mat[2] = @splat(0);

        out_mat[0][0] = front / right;
        out_mat[1][2] = front / top;
        out_mat[2][1] = 1;
    }
};

pub fn viewportToCanvas(x: f32, y: f32, cv_w: f32, cv_h: f32) i32x2 {
    const w_div_2 = cv_w / 2;
    const h_div_2 = cv_h / 2;
    return .{ @intFromFloat(x * w_div_2), @intFromFloat(y * h_div_2) };
}

// Vec manipulation
inline fn rotate2(v: f32x2, angle: f32) f32x2 {
    return .{
        v[0] * @cos(angle) + v[1] * @sin(angle),
        v[0] * @sin(angle) - v[1] * @cos(angle),
    };
}

inline fn rotateX(v: f32x3, angle: f32) f32x3 {
    return .{
        v[0],
        v[1] * @cos(angle) + v[2] * @sin(angle),
        v[1] * @sin(angle) - v[2] * @cos(angle),
    };
}

inline fn rotateY(v: f32x3, angle: f32) f32x3 {
    return .{
        v[0] * @cos(angle) + v[2] * @sin(angle),
        v[1],
        v[0] * @sin(angle) - v[2] * @cos(angle),
    };
}

inline fn rotateZ(v: f32x3, angle: f32) f32x3 {
    return .{
        v[0] * @cos(angle) + v[1] * @sin(angle),
        v[0] * @sin(angle) - v[1] * @cos(angle),
        v[2],
    };
}

inline fn rotateXDeg(v: f32x3, deg_angle: f32) f32x3 {
    const angle = deg_angle * math.rad_per_deg;
    return .{
        v[0],
        v[1] * @cos(angle) - v[2] * @sin(angle),
        v[1] * @sin(angle) + v[2] * @cos(angle),
    };
}

inline fn rotateYDeg(v: f32x3, deg_angle: f32) f32x3 {
    const angle = deg_angle * math.rad_per_deg;
    return .{
        v[0] * @cos(angle) + v[2] * @sin(angle),
        v[1],
        -v[0] * @sin(angle) + v[2] * @cos(angle),
    };
}

inline fn rotateZDeg(v: f32x3, deg_angle: f32) f32x3 {
    const angle = deg_angle * math.rad_per_deg;
    return .{
        v[0] * @cos(angle) - v[1] * @sin(angle),
        v[0] * @sin(angle) + v[1] * @cos(angle),
        v[2],
    };
}

inline fn sub2(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return .{ lhs[0] - rhs[0], lhs[1] - rhs[1] };
}

inline fn add3(lhs: anytype, rhs: @TypeOf(lhs)) @TypeOf(lhs) {
    return .{ lhs[0] + rhs[0], lhs[1] + rhs[1], lhs[2] + rhs[2] };
}

inline fn dot4(lhs: anytype, rhs: @TypeOf(lhs)) ret: {
    const T = @TypeOf(lhs);
    break :ret @typeInfo(T).array.child;
} {
    const T = @TypeOf(lhs);
    if (@typeInfo(T).array.len != 4) @compileError("dot4 is intended for 4 components vectors only");
    return (lhs[0] * rhs[0]) + (lhs[1] * rhs[1]) + (lhs[2] * rhs[2]) + (lhs[3] * rhs[3]);
}

pub inline fn dot3(lhs: anytype, rhs: @TypeOf(lhs)) ret: {
    const T = @TypeOf(lhs);
    break :ret @typeInfo(T).array.child;
} {
    const T = @TypeOf(lhs);
    if (@typeInfo(T).array.len != 3) @compileError("dot3 is intended for 3 components vectors only");
    return (lhs[0] * rhs[0]) + (lhs[1] * rhs[1]) + (lhs[2] * rhs[2]);
}

inline fn cross2(lhs: anytype, rhs: @TypeOf(lhs)) ret_type: {
    const T = @TypeOf(lhs);
    const array_info = @typeInfo(T).array;
    break :ret_type array_info.child;
} {
    return (lhs[0] * rhs[1]) - (lhs[1] * rhs[0]);
}

inline fn mat_mul_v(
    m: anytype,
    v: @typeInfo(@TypeOf(m)).array.child,
) @typeInfo(@TypeOf(m)).array.child {
    return switch (@typeInfo(@TypeOf(m)).array.len) {
        2 => @panic("Unimplementd"),
        3 => .{
            dot3(m[0], v),
            dot3(m[1], v),
            dot3(m[2], v),
        },
        4 => .{
            dot4(m[0], v),
            dot4(m[1], v),
            dot4(m[2], v),
            dot4(m[3], v),
        },
        else => unreachable,
    };
}

fn camToViewport(cam: *const Camera, p: f32x3) f32x2 {
    var m: Mat3 = undefined;
    cam.makeFrustumX(1, &m);
    const clip_p = mat_mul_v(m, p);
    dbg.print("P:({any}) => Clip:({any})\n", .{ p, clip_p });
    return .{ clip_p[0] / clip_p[2], clip_p[1] / clip_p[2] };
}
// model space -> world space -> camera space -> viewport -> canvas -> raster space
//  (+x -> right, +y -> forward, +z -> up)    | (+x -> right, +y -> up) | (+x -> right, +y -> down)
// opengl
// camera space -> clip space -> ndc -> raster space space

fn task1(rend: *Renderer, input_key: KeyCode) void {
    const w_div_2 = @"i32"(rend.frame.width / 2);
    const h_div_2 = @"i32"(rend.frame.height / 2);
    var prng = std.Random.Xoroshiro128.init(blk: {
        const seed: u64 = @bitCast(std.time.milliTimestamp());
        break :blk seed;
    });

    var rand = prng.random();

    switch (input_key) {
        .L => { // DrawLine
            rend.clearRenderTarget(RGBA.BLACK);
            rend.drawLine(0, 0, w_div_2, h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, w_div_2, -h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, -w_div_2, h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, -w_div_2, -h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, w_div_2 - 350, h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, w_div_2 - 350, -h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, -w_div_2 + 350, h_div_2, RGBA.FAV_RED);
            rend.drawLine(0, 0, -w_div_2 + 350, -h_div_2, RGBA.FAV_RED);
            rend.drawLine(-w_div_2, 0, w_div_2, 0, RGBA.FAV_RED); // horizontal line
            rend.drawLine(0, h_div_2, 0, -h_div_2, RGBA.FAV_RED); // vertical line
        },
        .C => { // Draw cube
            rend.clearRenderTarget(RGBA.BLACK);
            var verts = [_]i32x3{
                .{ 1, 1, 1 },
                .{ -1, 1, 1 },
                .{ -1, -1, 1 },
                .{ 1, -1, 1 },
                .{ 1, 1, -1 },
                .{ -1, 1, -1 },
                .{ -1, -1, -1 },
                .{ 1, -1, -1 },
            };
            const triangles = [_]TriangleDesc{
                .{ .indices = .{ 0, 1, 2 }, .color = RGBA.RED },
                .{ .indices = .{ 0, 2, 3 }, .color = RGBA.RED },
                .{ .indices = .{ 4, 0, 3 }, .color = RGBA.GREEN },
                .{ .indices = .{ 4, 3, 7 }, .color = RGBA.GREEN },
                .{ .indices = .{ 5, 4, 7 }, .color = RGBA.BLUE },
                .{ .indices = .{ 5, 7, 6 }, .color = RGBA.BLUE },
                .{ .indices = .{ 1, 5, 6 }, .color = RGBA.YELLOW },
                .{ .indices = .{ 1, 6, 2 }, .color = RGBA.YELLOW },
                .{ .indices = .{ 4, 5, 1 }, .color = RGBA.PURPLE },
                .{ .indices = .{ 4, 1, 0 }, .color = RGBA.PURPLE },
                .{ .indices = .{ 2, 6, 7 }, .color = RGBA.BROWN },
                .{ .indices = .{ 2, 7, 3 }, .color = RGBA.BROWN },
            };

            const translation = i32x3{ -2, 0, 2 };
            for (verts, 0..) |v, i| {
                verts[i] = add3(v, translation);
            }

            rend.drawObject(&verts, &triangles);
        },
        .T => {
            rend.clearRenderTarget(RGBA.BLACK);
            rend.fillTriangle(
                .{ -w_div_2 + 100, 0 },
                .{ -w_div_2 + 200, h_div_2 },
                .{ 0, h_div_2 - 200 },
                RGBA.RED,
                RGBA.GREEN,
                RGBA.BLUE,
            );
            rend.drawTriangle(
                .{ -w_div_2 + 100, 0 },
                .{ -w_div_2 + 200, h_div_2 },
                .{ 0, h_div_2 - 200 },
                RGBA.BLUE,
            );

            rend.fillTriangle(
                .{ w_div_2 - 300, 0 },
                .{ w_div_2 - 100, 0 },
                .{ w_div_2 - 100, h_div_2 },
                RGBA.FAV_RED,
                RGBA.FAV_RED,
                RGBA.FAV_RED,
            );
            rend.drawTriangle(
                .{ w_div_2 - 300, 0 },
                .{ w_div_2 - 100, 0 },
                .{ w_div_2 - 100, h_div_2 },
                RGBA.BLUE,
            );

            rend.fillTriangle(
                .{ w_div_2 - 100, 0 },
                .{ w_div_2 - 200, -h_div_2 },
                .{ 0, -h_div_2 + 200 },
                RGBA.FAV_RED,
                RGBA.FAV_RED,
                RGBA.FAV_RED,
            );
            rend.drawTriangle(
                .{ w_div_2 - 100, 0 },
                .{ w_div_2 - 200, -h_div_2 },
                .{ 0, -h_div_2 + 200 },
                RGBA.BLUE,
            );

            rend.fillTriangle(
                .{ -w_div_2, -h_div_2 },
                .{ -w_div_2 + 200, -h_div_2 },
                .{ -w_div_2 + 100, -100 },
                RGBA.FAV_RED,
                RGBA.FAV_RED,
                RGBA.FAV_RED,
            );
            rend.drawTriangle(
                .{ -w_div_2, -h_div_2 },
                .{ -w_div_2 + 200, -h_div_2 },
                .{ -w_div_2 + 100, -100 },
                RGBA.BLUE,
            );
        },
        .R => {
            rend.clearRenderTarget(RGBA.BLACK);
            // rend.fillRect(0, 0, 200, 200, RGBA.BLUE);
            rend.fillRect(-100, 100, 100, 100, RGBA.FAV_RED);
            rend.fillRect(0, 0, 500, 400, RGBA.BLUE);
            const rect3_pos = viewportToCanvas(-1, 1, @floatFromInt(rend.frame.width), @floatFromInt(rend.frame.height));
            dbg.print("Rect=({any})\n", .{rect3_pos});
            rend.fillRect(rect3_pos[0], rect3_pos[1], 100, 100, RGBA.FAV_RED);
        },
        .F => {
            const rx0 = rand.intRangeAtMost(i32, -w_div_2, w_div_2);
            const ry0 = rand.intRangeAtMost(i32, -h_div_2, h_div_2);
            const rx1 = rand.intRangeAtMost(i32, -w_div_2, w_div_2);
            const ry1 = rand.intRangeAtMost(i32, -h_div_2, h_div_2);
            const rx2 = rand.intRangeAtMost(i32, -w_div_2, w_div_2);
            const ry2 = rand.intRangeAtMost(i32, -h_div_2, h_div_2);
            std.debug.print("Ploting ({},{})|({},{})|({},{})\n", .{ rx0, ry0, rx1, ry1, rx2, ry2 });
            rend.clearRenderTarget(RGBA.BLACK);
            rend.fillTriangle(.{ rx0, ry0 }, .{ rx1, ry1 }, .{ rx2, ry2 }, RGBA.FAV_RED, RGBA.FAV_RED, RGBA.FAV_RED);
        },
        else => {
            // rend.clearRenderTarget(RGBA.BLACK);
        },
    }
}

var tick_start: u64 = 0;
var tick_nume_ns: u32 = 0;
var tick_denom_ns: u32 = 0;
fn initTicks() void {
    const tick_freq = widow.time.getMonoClockFreq();
    dbg.assert(tick_freq > 0 and tick_freq <= math.maxInt(u32));
    const gcd = math.gcd(std.time.ns_per_s, tick_freq);
    tick_nume_ns = @intCast(std.time.ns_per_s / gcd);
    dbg.assert(tick_nume_ns > 0);
    tick_denom_ns = @intCast(tick_freq / gcd);
    tick_start = widow.time.getMonoClockTicks();
    dbg.assert(tick_start != 0);
}
fn getTicksNs() u64 {
    var result: u64 = 0;
    result = (widow.time.getMonoClockTicks() - tick_start);
    result = result * tick_nume_ns;
    result = result / tick_denom_ns;
    return result;
}
