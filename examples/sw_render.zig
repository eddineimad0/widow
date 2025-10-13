const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

const dbg = std.debug;

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
        // .withDPIAware(false)
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
    std.debug.print("Render API:{s}\n", .{sw_canvas.getDriverName()});
    std.debug.print("Framebuffer pixel format :{t}\n", .{sw_canvas.fb_format_info.fmt});

    std.debug.print("DPI Info:{}\n", .{mywindow.getDpiInfo()});

    var rend = Renderer.init(sw_canvas);
    var in_key = KeyCode.L;
    event_loop: while (true) {
        try mywindow.pollEvents();

        var event: widow.event.Event = undefined;

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    break :event_loop;
                },
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
                },
                else => continue,
            }
        }

        rend.clearRenderTarget(RGBA.BLACK);
        const w_div_2 = @"i32"(rend.frame.width / 2);
        const h_div_2 = @"i32"(rend.frame.height / 2);

        switch (in_key) {
            .L => { // DrawLine
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
            .P => { // Points
                // 3 horizontal points
                rend.putPixel(-1, h_div_2, RGBA.FAV_RED);
                rend.putPixel(0, h_div_2, RGBA.FAV_RED);
                rend.putPixel(1, h_div_2, RGBA.FAV_RED);
                // 3 vertical points
                rend.putPixel(0, h_div_2, RGBA.FAV_RED);
                rend.putPixel(0, h_div_2 - 1, RGBA.FAV_RED);
                rend.putPixel(0, h_div_2 - 2, RGBA.FAV_RED);
                // + in the middle
                rend.putPixel(0, 0, RGBA.FAV_RED);
                rend.putPixel(0, 0 - 1, RGBA.FAV_RED);
                rend.putPixel(0, 0 + 1, RGBA.FAV_RED);
                rend.putPixel(0 - 1, 0, RGBA.FAV_RED);
                rend.putPixel(0 + 1, 0, RGBA.FAV_RED);
            },
            .T => {
                rend.drawTriangle(
                    .xy(-w_div_2 + 100, 0),
                    .xy(-w_div_2 + 200, h_div_2),
                    .xy(-w_div_2 + 300, h_div_2 - 200),
                    RGBA.FAV_RED,
                );
                rend.drawTriangle(
                    .xy(w_div_2 - 300, 0),
                    .xy(w_div_2 - 100, 0),
                    .xy(w_div_2 - 100, h_div_2),
                    RGBA.FAV_RED,
                );
            },
            else => {},
        }
        // { // putPixelF
        //     rend.putPixelF(0, 0, .FAV_RED);
        //     rend.putPixelF(-1.0, 1.0, .FAV_RED);
        //     rend.putPixelF(1.0, 1.0, .FAV_RED);
        //     rend.putPixelF(-1.0, -1.0, .FAV_RED);
        //     rend.putPixelF(1.0, -1.0, .FAV_RED);
        // }

        rend.present();
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

// pub const Rgba8888 = extern struct {
//     r: u8,
//     g: u8,
//     b: u8,
//     a: u8,

//     const Self = @This();
// };

// pub const RgbaF32 = extern struct {
//     r: f32,
//     g: f32,
//     b: f32,
//     a: f32,

//     const Self = @This();

// };

// pub const ColorF32 = RgbaF32;

fn Tx2(comptime T: type) type {
    return extern struct {
        _0: T,
        _1: T,

        const Self = @This();
        pub inline fn xy(x: T, y: T) Self {
            return .{
                ._0 = x,
                ._1 = y,
            };
        }
    };
}

fn Tx3(comptime T: type) type {
    return extern struct {
        _0: T,
        _1: T,
        _2: T,

        const Self = @This();
        pub inline fn xy(x: T, y: T, z: T) Self {
            return .{
                ._0 = x,
                ._1 = y,
                ._2 = z,
            };
        }
    };
}

fn Tx4(comptime T: type) type {
    return extern struct {
        _0: T,
        _1: T,
        _2: T,
        _3: T,

        const Self = @This();
        pub inline fn xyzw(x: T, y: T, z: T, w: T) Self {
            return .{
                ._0 = x,
                ._1 = y,
                ._2 = z,
                ._3 = w,
            };
        }

        pub inline fn rgba(r: T, g: T, b: T, a: T) Self {
            return .{
                ._0 = r,
                ._1 = g,
                ._2 = b,
                ._3 = a,
            };
        }
    };
}
pub const i32x2 = Tx2(i32);
pub const i32x4 = Tx4(i32);
pub const f32x2 = Tx2(f32);
pub const f32x4 = Tx4(f32);

pub const Rgba8 = Tx4(u8);
pub const RgbaF32 = f32x4;

const RGBA = struct {
    pub const BLACK: Rgba8 = .rgba(0, 0, 0, 255);
    pub const WHITE: Rgba8 = .rgba(255, 255, 255, 255);
    pub const TRANSPARENT: Rgba8 = .rgba(0, 0, 0, 0);
    pub const RED: Rgba8 = .rgba(255, 0, 0, 255);
    pub const GREEN: Rgba8 = .rgba(0, 255, 0, 255);
    pub const BLUE: Rgba8 = .rgba(0, 0, 255, 255);
    pub const LIGHTGRAY: Rgba8 = .rgba(199, 199, 199, 255);
    pub const GRAY: Rgba8 = .rgba(130, 130, 130, 255);
    pub const DARKGRAY: Rgba8 = .rgba(79, 79, 79, 255);
    pub const YELLOW: Rgba8 = .rgba(252, 250, 0, 255);
    pub const GOLD: Rgba8 = .rgba(255, 204, 0, 255);
    pub const ORANGE: Rgba8 = .rgba(255, 161, 0, 255);
    pub const PINK: Rgba8 = .rgba(255, 110, 194, 255);
    pub const MAROON: Rgba8 = .rgba(191, 33, 56, 255);
    pub const LIME: Rgba8 = .rgba(0, 158, 46, 255);
    pub const DARKGREEN: Rgba8 = .rgba(0, 117, 43, 255);
    pub const SKYBLUE: Rgba8 = .rgba(102, 191, 255, 255);
    pub const DARKBLUE: Rgba8 = .rgba(0, 82, 171, 255);
    pub const PURPLE: Rgba8 = .rgba(199, 122, 255, 255);
    pub const VIOLET: Rgba8 = .rgba(135, 61, 191, 255);
    pub const DARKPURPLE: Rgba8 = .rgba(112, 31, 125, 255);
    pub const BEIGE: Rgba8 = .rgba(212, 176, 130, 255);
    pub const BROWN: Rgba8 = .rgba(128, 107, 79, 255);
    pub const DARKBROWN: Rgba8 = .rgba(77, 64, 46, 255);
    pub const MAGENTA: Rgba8 = .rgba(255, 0, 255, 255);
    pub const FAV_RED: Rgba8 = .rgba(219, 105, 105, 255);
    // float version
    pub const BLACK_F32: RgbaF32 = .rgba(0.0, 0.0, 0.0, 1.0);
    pub const WHITE_F32: RgbaF32 = .rgba(1.0, 1.0, 1.0, 1.0);
    pub const TRANSPARENT_F32: RgbaF32 = .rgba(0.0, 0.0, 0.0, 0.0);
    pub const RED_F32: RgbaF32 = .rgba(1.0, 0.0, 0.0, 1.0);
    pub const GREEN_F32: RgbaF32 = .rgba(0.0, 1.0, 0.0, 1.0);
    pub const BLUE_F32: RgbaF32 = .rgba(0.0, 0.0, 1.0, 1.0);
    pub const LIGHTGRAY_F32: RgbaF32 = .rgba(0.78, 0.78, 0.78, 1.0);
    pub const GRAY_F32: RgbaF32 = .rgba(0.51, 0.51, 0.51, 1.0);
    pub const DARKGRAY_F32: RgbaF32 = .rgba(0.31, 0.31, 0.31, 1.0);
    pub const YELLOW_F32: RgbaF32 = .rgba(0.99, 0.98, 0.00, 1.0);
    pub const GOLD_F32: RgbaF32 = .rgba(1.00, 0.80, 0.00, 1.0);
    pub const ORANGE_F32: RgbaF32 = .rgba(1.00, 0.63, 0.00, 1.0);
    pub const PINK_F32: RgbaF32 = .rgba(1.00, 0.43, 0.76, 1.0);
    pub const MAROON_F32: RgbaF32 = .rgba(0.75, 0.13, 0.22, 1.0);
    pub const LIME_F32: RgbaF32 = .rgba(0.00, 0.62, 0.18, 1.0);
    pub const DARKGREEN_F32: RgbaF32 = .rgba(0.00, 0.46, 0.17, 1.0);
    pub const SKYBLUE_F32: RgbaF32 = .rgba(0.40, 0.75, 1.00, 1.0);
    pub const DARKBLUE_F32: RgbaF32 = .rgba(0.00, 0.32, 0.67, 1.0);
    pub const PURPLE_F32: RgbaF32 = .rgba(0.78, 0.48, 1.00, 1.0);
    pub const VIOLET_F32: RgbaF32 = .rgba(0.53, 0.24, 0.75, 1.0);
    pub const DARKPURPLE_F32: RgbaF32 = .rgba(0.44, 0.12, 0.49, 1.0);
    pub const BEIGE_F32: RgbaF32 = .rgba(0.83, 0.69, 0.51, 1.0);
    pub const BROWN_F32: RgbaF32 = .rgba(0.50, 0.42, 0.31, 1.0);
    pub const DARKBROWN_F32: RgbaF32 = .rgba(0.30, 0.25, 0.18, 1.0);
    pub const MAGENTA_F32: RgbaF32 = .rgba(1.00, 0.00, 1.00, 1.0);
    pub const FAV_RED_F32: RgbaF32 = .rgba(0.859, 0.412, 0.412, 1.0);
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
    //-w/2(-1.0)────────────────────│──────────────────── w/2(1.0)
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
        std.debug.assert(success);
        std.debug.print("Software framebuffer:({}x{}) with pitch:{}\n", .{ w, h, pitch });
        return .{
            .target = target,
            .frame = .{
                .buffer = pixels,
                .width = w,
                .height = h,
                .pitch = pitch,
            },
            .fb_format = target.fb_format_info,
        };
    }

    pub inline fn clearRenderTarget(self: *Self, clear_color: Color32) void {
        const c: u32 = mapRGBA(
            &self.fb_format,
            clear_color._0,
            clear_color._1,
            clear_color._2,
            clear_color._3,
        );
        @memset(self.frame.buffer, c);
    }

    // Draw routines
    pub inline fn putPixelF(self: *Self, x: f32, y: f32, c: Color32) void {
        dbg.assert(self.frame.width > 0);
        dbg.assert(self.frame.height > 0);
        dbg.assert(@abs(x) <= 1.0);
        dbg.assert(@abs(y) <= 1.0);
        const W_DIV_2: f32 = @"f32"(self.frame.width) / 2.0;
        const H_DIV_2: f32 = @"f32"(self.frame.height) / 2.0;
        const sx = x * W_DIV_2;
        const sy = y * H_DIV_2;

        self.putPixel(@intFromFloat(sx), @intFromFloat(sy), c);
    }

    inline fn normalizeCoordinates(self: *const Self, x: i32, y: i32) [2]i32 {
        dbg.assert(self.frame.width > 0);
        dbg.assert(self.frame.height > 0);
        dbg.assert(@abs(x * 2) <= self.frame.width);
        dbg.assert(@abs(y * 2) <= self.frame.height);
        dbg.assert(self.frame.width % 2 == 0);
        dbg.assert(self.frame.height % 2 == 0);
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
        const nx: i32, const ny: i32 = self.normalizeCoordinates(x, y);
        self.frame.buffer[(self.frame.pitch / self.fb_format.bytes_per_pixel) * @"u32"(ny) + @"u32"(nx)] = mapRGBA(
            &self.fb_format,
            c._0,
            c._1,
            c._2,
            c._3,
        );
    }

    pub fn drawLineNaive(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, c: Color32) void {
        const dx = x1 - x0;
        const dy = y1 - y0;
        if (@abs(dx) >= @abs(dy)) {
            var x_start, const y_start, const x_end = if (x0 < x1) .{ x0, y0, x1 } else .{ x1, y1, x0 };
            const a = @"f32"(dy) / @"f32"(dx);
            var y: f32 = @floatFromInt(y_start);
            while (x_start <= x_end) : (x_start += 1) {
                self.putPixel(x_start, @intFromFloat(y), c);
                y += a;
            }
        } else {
            const x_start, var y_start, const y_end = if (y0 < y1) .{ x0, y0, y1 } else .{ x1, y1, y0 };
            const a = @"f32"(dx) / @"f32"(dy);
            var x: f32 = @floatFromInt(x_start);
            while (y_start <= y_end) : (y_start += 1) {
                self.putPixel(@intFromFloat(x), y_start, c);
                x += a;
            }
        }
    }

    inline fn drawBrLine(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, c: Color32) void {
        const pitch = (self.frame.pitch / self.fb_format.bytes_per_pixel);
        const color = mapRGBA(
            &self.fb_format,
            c._0,
            c._1,
            c._2,
            c._3,
        );
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

    inline fn drawHorizLine(self: *Self, nx0: i32, nx1: i32, ny: i32, c: Color32) void {
        const color: u32 = mapRGBA(&self.fb_format, c._0, c._1, c._2, c._3);
        const len: i32 = nx1 - nx0;

        const start: usize = if (len >= 0)
            (self.frame.pitch / self.fb_format.bytes_per_pixel) * @"u32"(ny) + @"u32"(nx0)
        else
            (self.frame.pitch / self.fb_format.bytes_per_pixel) * @"u32"(ny) + @"u32"(nx1);

        @memset(self.frame.buffer[start..(start + @abs(len) + 1)], color);
    }

    inline fn drawVertiLine(self: *Self, ny0: i32, ny1: i32, nx: i32, c: Color32) void {
        const color: u32 = mapRGBA(&self.fb_format, c._0, c._1, c._2, c._3);
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

    inline fn drawDiagLine(self: *Self, nx0: i32, ny0: i32, nx1: i32, ny1: i32, c: Color32) void {
        const color: u32 = mapRGBA(&self.fb_format, c._0, c._1, c._2, c._3);
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
        const nx0, const ny0 = self.normalizeCoordinates(x0, y0);
        const nx1, const ny1 = self.normalizeCoordinates(x1, y1);

        if (y0 == y1) {
            self.drawHorizLine(nx0, nx1, ny0, c);
            return;
        } else if (x0 == x1) {
            self.drawVertiLine(ny0, ny1, nx0, c);
            return;
        } else if (y1 - y0 == x1 - x0) {
            self.drawDiagLine(nx0, ny0, nx1, ny1, c);
        }

        self.drawBrLine(nx0, ny0, nx1, ny1, c);
    }

    pub fn drawTriangle(self: *Self, p0: i32x2, p1: i32x2, p2: i32x2, color: Color32) void {
        self.drawLine(p0._0, p0._1, p1._0, p1._1, color);
        self.drawLine(p0._0, p0._1, p2._0, p2._1, color);
        self.drawLine(p1._0, p1._1, p2._0, p2._1, color);
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

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}
