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
    event_loop: while (true) {
        try mywindow.pollEvents();

        var event: widow.event.Event = undefined;

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => {
                    break :event_loop;
                },
                EventType.Keyboard => |*key| {
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

        rend.clearRenderTarget(0.0, 0.0, 0.0, 0.0);
        // { // putPixelF
        //     rend.putPixelF(0, 0, .FAV_RED);
        //     rend.putPixelF(-1.0, 1.0, .FAV_RED);
        //     rend.putPixelF(1.0, 1.0, .FAV_RED);
        //     rend.putPixelF(-1.0, -1.0, .FAV_RED);
        //     rend.putPixelF(1.0, -1.0, .FAV_RED);
        // }

        // { // putPixel
        //     const h_div_2 = @"i32"(rend.frame.height / 2);
        //     // rend.putPixel(-w_div_2, h_div_2, .FAV_RED);
        //     // rend.putPixel(w_div_2, h_div_2, .FAV_RED);
        //     // rend.putPixel(-w_div_2, -h_div_2, .FAV_RED);
        //     // 3 horizontal points
        //     rend.putPixel(-1, h_div_2, .FAV_RED);
        //     rend.putPixel(0, h_div_2, .FAV_RED);
        //     rend.putPixel(1, h_div_2, .FAV_RED);
        //     // 3 vertical points
        //     rend.putPixel(0, h_div_2, .FAV_RED);
        //     rend.putPixel(0, h_div_2 - 1, .FAV_RED);
        //     rend.putPixel(0, h_div_2 - 2, .FAV_RED);
        //     // + in the middle
        //     rend.putPixel(0, 0, .FAV_RED);
        //     rend.putPixel(0, 0 - 1, .FAV_RED);
        //     rend.putPixel(0, 0 + 1, .FAV_RED);
        //     rend.putPixel(0 - 1, 0, .FAV_RED);
        //     rend.putPixel(0 + 1, 0, .FAV_RED);
        // }

        { // DrawLine
            const w_div_2 = @"i32"(rend.frame.width / 2);
            const h_div_2 = @"i32"(rend.frame.height / 2);
            rend.drawBrLine(0, 0, w_div_2, h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, w_div_2, -h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, -w_div_2, h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, -w_div_2, -h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, w_div_2 - 350, h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, w_div_2 - 350, -h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, -w_div_2 + 350, h_div_2, .FAV_RED);
            rend.drawBrLine(0, 0, -w_div_2 + 350, -h_div_2, .FAV_RED);
            rend.drawBrLine(-w_div_2, 0, w_div_2, 0, .FAV_RED); // horizontal line
            rend.drawBrLine(0, h_div_2, 0, -h_div_2, .FAV_RED); // vertical line
        }

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
    const color = std.mem.readInt(u32, &argb, .big);
    for (framebuffer) |*pixel|
        pixel.* = color;
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

pub const RgbaF32 = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    const Self = @This();

    pub const BLACK = Self{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const WHITE = Self{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
    pub const TRANSPARENT = Self{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 0.0 };
    pub const RED = Self{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
    pub const GREEN = Self{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
    pub const BLUE = Self{ .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 };
    pub const LIGHTGRAY = Self{ .r = 0.78, .g = 0.78, .b = 0.78, .a = 1.0 };
    pub const GRAY = Self{ .r = 0.51, .g = 0.51, .b = 0.51, .a = 1.0 };
    pub const DARKGRAY = Self{ .r = 0.31, .g = 0.31, .b = 0.31, .a = 1.0 };
    pub const YELLOW = Self{ .r = 0.99, .g = 0.98, .b = 0.00, .a = 1.0 };
    pub const GOLD = Self{ .r = 1.00, .g = 0.80, .b = 0.00, .a = 1.0 };
    pub const ORANGE = Self{ .r = 1.00, .g = 0.63, .b = 0.00, .a = 1.0 };
    pub const PINK = Self{ .r = 1.00, .g = 0.43, .b = 0.76, .a = 1.0 };
    pub const MAROON = Self{ .r = 0.75, .g = 0.13, .b = 0.22, .a = 1.0 };
    pub const LIME = Self{ .r = 0.00, .g = 0.62, .b = 0.18, .a = 1.0 };
    pub const DARKGREEN = Self{ .r = 0.00, .g = 0.46, .b = 0.17, .a = 1.0 };
    pub const SKYBLUE = Self{ .r = 0.40, .g = 0.75, .b = 1.00, .a = 1.0 };
    pub const DARKBLUE = Self{ .r = 0.00, .g = 0.32, .b = 0.67, .a = 1.0 };
    pub const PURPLE = Self{ .r = 0.78, .g = 0.48, .b = 1.00, .a = 1.0 };
    pub const VIOLET = Self{ .r = 0.53, .g = 0.24, .b = 0.75, .a = 1.0 };
    pub const DARKPURPLE = Self{ .r = 0.44, .g = 0.12, .b = 0.49, .a = 1.0 };
    pub const BEIGE = Self{ .r = 0.83, .g = 0.69, .b = 0.51, .a = 1.0 };
    pub const BROWN = Self{ .r = 0.50, .g = 0.42, .b = 0.31, .a = 1.0 };
    pub const DARKBROWN = Self{ .r = 0.30, .g = 0.25, .b = 0.18, .a = 1.0 };
    pub const MAGENTA = Self{ .r = 1.00, .g = 0.00, .b = 1.00, .a = 1.0 };
    pub const FAV_RED = Self{ .r = 859, .g = 0.412, .b = 0.412, .a = 1.0 };
};

pub const ColorF32 = RgbaF32;

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

    const Self = @This();

    pub fn init(target: widow.gfx.Canvas) Self {
        var pixels: []u32 = &.{};
        var w: u32, var h: u32, var pitch: u32 = .{ 0, 0, 0 };
        const success = target.getSoftwareBuffer(&pixels, &w, &h, &pitch);
        std.debug.assert(success);
        std.debug.print("Software framebuffer:({}x{}) with pitch:{}\n", .{ w, h, pitch });
        return .{ .target = target, .frame = .{
            .buffer = pixels,
            .width = w,
            .height = h,
            .pitch = pitch,
        } };
    }

    pub inline fn clearRenderTarget(self: *Self, r: f32, g: f32, b: f32, a: f32) void {
        const color: u32 = mapRGBA(
            &self.target.fb_format_info,
            @intFromFloat(255 * r),
            @intFromFloat(255 * g),
            @intFromFloat(255 * b),
            @intFromFloat(255 * a),
        );
        @memset(self.frame.buffer, color);
    }

    // Draw routines
    pub inline fn putPixelF(self: *Self, x: f32, y: f32, c: ColorF32) void {
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

    pub fn putPixel(self: *Self, x: i32, y: i32, c: ColorF32) void {
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
        dbg.print("Coloring ({},{}) => ({}x{})\n", .{ x, y, nx, ny });
        self.frame.buffer[(self.frame.pitch / 4) * @"u32"(ny) + @"u32"(nx)] = mapRGBA(
            &self.target.fb_format_info,
            @intFromFloat(255 * c.r),
            @intFromFloat(255 * c.g),
            @intFromFloat(255 * c.b),
            @intFromFloat(255 * c.a),
        );
    }

    pub fn drawLine(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, c: ColorF32) void {
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

    pub fn drawBrLine(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, c: ColorF32) void {
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
                self.putPixel(x, y, c);
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
                self.putPixel(x, y, c);
                if (d < 0) {
                    d += d_inc0;
                } else {
                    d += d_inc1;
                    x += x_inc;
                }
            }
        }
    }
    // pub fn drawWuLine(self: *Self, x0: i32, y0: i32, x1: i32, y1: i32, c: ColorF32) void {}

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
