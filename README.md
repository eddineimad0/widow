## Introduction

Widow is a simple windowing library written in zig.

## Supported Platforms

Currently Widow only supports windows os.

Support for linux is next on the line.

## Examples

All API functions are well documented and you can check out the examples for more details on how to use.

The following sample creates a window.

```zig
const std = @import("std");
const widow = @import("widow");
const allocator = std.heap.c_allocator;

pub fn main() void {

    // First we need to preform some platform specific initialization.
    widow.initWidowPlatform(.{}) catch {
        std.debug.print("Failed to start Widow library\n", .{});
    };
    // Clean up code to be called, when done using the library.
    defer widow.deinitWidowPlatform();


    // Start by creating a WidowContext instance.
    // the context is at the heart of the library and keeps track of monitors,clipboard,events...
    // only one instance is needed but you can create as many as you need.
    var widow_cntxt = widow.WidowContext.create(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // Destroy it when done.
    defer widow_cntxt.destroy(allocator);

    // Create a WindowBuilder.
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "Simple window",
        800,
        600,
        widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // Customize the window to your liking.
    _ = builder.withResize(true)
        .withDPIScaling(false)
        .withPosition(200, 200)
        .withSize(800, 600)
        .withDecoration(true);

    _ = builder.withTitle("Re:Simple Window") catch |err| {
        std.debug.print("Failed to change window title,{}\n", .{err});
        return;
    };

    // Create the window,
    var mywindow = builder.build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // Deinitialize when done.
    defer mywindow.deinit();
}
```

## Minimum Zig Version

0.11.0
The main branch will stick to stable zig releases.

## Contributing

You can open an issue to detail a bug you encountered or propose a feature you wish to be added.  
You can also fork the project and then create a pull request.

## Dependecies

- [zigwin32](https://github.com/marlersoft/zigwin32): Provides binding for Win32 API.
