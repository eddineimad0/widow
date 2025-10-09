const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

// TOOD: resize framebuffer on resize
pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    const ctx = try widow.createWidowContext(allocator, null);
    defer widow.destroyWidowContext(allocator, ctx);

    var ev_queue = try EventQueue.init(allocator, 256);
    defer ev_queue.deinit();

    var builder = widow.WindowBuilder.init();
    var mywindow = builder.withTitle("Software rendered Window")
        .withSize(640, 480)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withDecoration(true)
        .withResize(true)
        .withEventQueue(&ev_queue)
        .withFrameBuffer(&.{
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
    var success = sw_canvas.getDriverInfo(&p_wr);
    if (success) {
        std.debug.print("{s}\n", .{p_wr.buffered()});
    }
    std.debug.print("Render API:{s}\n", .{sw_canvas.getDriverName()});

    var pixels: []u32 = &.{};
    var w: u32, var h: u32, var pitch: u32 = .{ 0, 0, 0 };
    success = sw_canvas.getSoftwareBuffer(&pixels, &w, &h, &pitch);
    std.debug.print("Software framebuffer:({}x{}) with pitch:{}\n", .{ w, h, pitch });

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
                        "Window logical size (w:{}xh:{})\t physical size (w:{}xh:{})\t scale factor {}\n",
                        .{
                            ev.new_size.logical_width,
                            ev.new_size.logical_height,
                            ev.new_size.physical_width,
                            ev.new_size.physical_height,
                            ev.new_size.scale,
                        },
                    );
                },
                else => continue,
            }
        }

        renderWeirdGradient(pixels);
        _ = sw_canvas.swapBuffers();
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
