## Introduction

Widow is a simple library for creating rendering windows and reading inputs written in zig.

## Supported Platforms

Currently Widow supports windows Os and Linux (x11).
there is no current plan to support any other platforms.

## Examples

All API functions are well documented and you can check out the examples
for more details on how to use.

The following sample creates a window.

```zig
const std = @import("std");
const widow = @import("widow");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    // first we need to preform some platform specific initialization.
    // and build a context for the current platform.
    // the context also keep a copy of the allocator you pass it
    // to use it for all allocations done by the library.
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
        .withSize(800, 600)
        .withResize(true)
        .withDPIAware(true)
        .withPosition(200, 200)
        .withDecoration(true)
        .build(ctx, null) catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // closes the window when done.
    defer mywindow.deinit();

    _ = mywindow.setEventQueue(&ev_queue);

    event_loop: while (true) {
        // wait until an event is posted.
        try mywindow.waitEvent();

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
                    }
                },

                else => continue,
            }
        }
    }
}
```

## Minimum Zig Version

✅ [0.15.1](https://ziglang.org/documentation/0.15.1/)
The main branch will stick to stable zig releases.

## Dependecies
- [zigglgen](https://github.com/castholm/zigglgen): OpenGL binding used in the `gl_triangle.zig` example
