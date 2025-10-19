const std = @import("std");
const widow = @import("widow");
const gl = @import("gl");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

var gl_procs: gl.ProcTable = undefined;

// exporting these 2 symbols forces window to use dedicated gpu when creating
// opengl context.
export const NvOptimusEnablement: c_int = 1;
export const AmdPowerXpressRequestHighPerformance: c_int = 1;

const VERTEX_SHADER_SRC =
    \\#version 420 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\out vec4 verColor;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\  verColor = vec4(aColor,1.0);
    \\}
;

const FRAG_SHADER_SRC =
    \\#version 420 core
    \\in vec4 verColor;
    \\out vec4 fragColor;
    \\void main()
    \\{
    \\    fragColor = verColor;
    \\}
;

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    const ctx = try widow.createWidowContext(allocator);
    defer widow.destroyWidowContext(allocator, ctx);

    // the window will require an event queue to
    // send events.
    var ev_queue = try EventQueue.init(allocator, 256);
    defer ev_queue.deinit();

    // create a WindowBuilder.
    var builder = widow.WindowBuilder.init();
    // customize the window.
    var mywindow = builder.withTitle("Simple Window")
        .withSize(640, 480)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withDecoration(true)
        .withResize(true)
        .build(ctx, null) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // closes the window when done.
    defer mywindow.deinit();
    mywindow.focus();

    _ = mywindow.setEventQueue(&ev_queue);

    var gl_canvas = try mywindow.createCanvas();
    defer gl_canvas.deinit();
    var pbuff: [1024]u8 = undefined;
    var p_wr = std.io.Writer.fixed(&pbuff);
    const success = gl_canvas.getDriverInfo(&p_wr);
    if (success) {
        std.debug.print("{s}\n", .{p_wr.buffered()});
    }
    std.debug.print("Render API:{t}\n", .{gl_canvas.getDriverName()});
    std.debug.print("Framebuffer pixel format :{t}\n", .{gl_canvas.getPixelFormatInfo().fmt});
    _ = gl_canvas.makeCurrent();
    const ok = gl_canvas.setSwapInterval(.Synced);
    std.debug.print("VSync:{s}\n", .{if (ok) "ON" else "OFF"});

    if (!gl_procs.init(widow.opengl.loaderFunc)) return error.glInitFailed;

    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);
    const client_size = mywindow.getClientSize();
    gl.Viewport(0, 0, client_size.physical_width, client_size.physical_height);

    const vertx_shader = try loadVertexShader(VERTEX_SHADER_SRC);
    const frag_shader = try loadFragShader(FRAG_SHADER_SRC);
    const render_prg = try linkRenderProgram(vertx_shader, frag_shader);
    gl.UseProgram(render_prg);

    event_loop: while (true) {
        try mywindow.pollEvents();

        var event: widow.event.Event = undefined;

        while (ev_queue.popEvent(&event)) {
            switch (event) {
                EventType.WindowClose => |window_id| {
                    std.debug.print("closing Window #{}\n", .{window_id});
                    break :event_loop;
                },
                EventType.Keyboard => |*key| {
                    if (key.state.isPressed()) {
                        if (key.keycode == KeyCode.Q) {
                            // let's request closing the window on
                            // pressing Q key
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
                    gl.Viewport(0, 0, ev.new_size.physical_width, ev.new_size.physical_height);
                },
                else => continue,
            }
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);
        try drawTriangle();
        _ = gl_canvas.swapBuffers();
    }
}

fn loadVertexShader(src: [*:0]const u8) !gl.uint {
    const vertx_shader = gl.CreateShader(gl.VERTEX_SHADER);
    if (vertx_shader == 0) {
        return error.ShaderNoMem;
    }
    gl.ShaderSource(vertx_shader, 1, @ptrCast(&src), null);
    gl.CompileShader(vertx_shader);
    var sucess: gl.int = 0;
    gl.GetShaderiv(vertx_shader, gl.COMPILE_STATUS, &sucess);
    if (sucess == 0) {
        var log: [512]u8 = undefined;
        var written: gl.sizei = 0;
        gl.GetShaderInfoLog(vertx_shader, log.len, &written, @ptrCast(&log));
        std.log.err("Vertex Shader : {s}", .{log[0..@intCast(written)]});
        return error.ShaderSyntax;
    }
    return vertx_shader;
}

fn loadFragShader(src: [*:0]const u8) !gl.uint {
    const frag_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
    if (frag_shader == 0) {
        return error.ShaderNoMem;
    }
    gl.ShaderSource(frag_shader, 1, @ptrCast(&src), null);
    gl.CompileShader(frag_shader);
    var sucess: gl.int = 0;
    gl.GetShaderiv(frag_shader, gl.COMPILE_STATUS, &sucess);
    if (sucess == 0) {
        var log: [512]u8 = undefined;
        var written: gl.sizei = 0;
        gl.GetShaderInfoLog(frag_shader, log.len, &written, @ptrCast(&log));
        std.log.err("Fragment Shader : {s}", .{log[0..@intCast(written)]});
        return error.ShaderSyntax;
    }
    return frag_shader;
}

fn linkRenderProgram(vertx_shader: gl.uint, frag_shader: gl.uint) !gl.uint {
    const prg = gl.CreateProgram();
    if (prg == 0) {
        return error.ProgramNoMem;
    }
    gl.AttachShader(prg, vertx_shader);
    gl.AttachShader(prg, frag_shader);
    gl.LinkProgram(prg);
    var success: gl.int = 0;
    gl.GetProgramiv(prg, gl.LINK_STATUS, &success);
    if (success == 0) {
        var log: [512]u8 = undefined;
        var written: gl.sizei = 0;
        gl.GetProgramInfoLog(prg, log.len, &written, @ptrCast(&log));
        std.log.err("Render Program : {s}", .{log[0..@intCast(written)]});
        return error.ShaderSyntax;
    }
    gl.DeleteShader(vertx_shader);
    gl.DeleteShader(frag_shader);
    return prg;
}

fn drawTriangle() !void {
    const verticies = [_]f32{
        // layout position(x,y,z), color(r,g,b)
        0.0,
        0.5,
        0.0,
        1.0,
        0.0,
        0.0,
        0.5,
        -0.5,
        0.0,
        0.0,
        1.0,
        0.0,
        -0.5,
        -0.5,
        0.0,
        0.0,
        0.0,
        1.0,
    };
    var vbos = [1]gl.uint{0};
    var vaos = [1]gl.uint{0};

    gl.GenVertexArrays(vaos.len, &vaos);
    gl.BindVertexArray(vaos[0]);

    gl.GenBuffers(vbos.len, @ptrCast(&vbos));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbos[0]);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @sizeOf(f32) * verticies.len,
        @ptrCast(&verticies),
        gl.STATIC_DRAW,
    );
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(
        1,
        3,
        gl.FLOAT,
        gl.FALSE,
        6 * @sizeOf(f32),
        3 * @sizeOf(f32),
    );
    gl.EnableVertexAttribArray(1);

    gl.DrawArrays(gl.TRIANGLES, 0, 3);
}
