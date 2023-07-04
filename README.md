## Introduction

Widow is a simple windowing library written in zig.

## Supported Platforms
Currently Widow only supports windows os. 

## Examples
All API functions are well documented and you can check out the examples for more details on how to use.

You can get a window up and running
```zig
const std = @import("std");
const widow = @import("widow");
const allocator = std.heap.c_allocator;

pub fn main() void {

    // Start by creating a WidowContext instance.
    // the context is at the heart of the library and keeps track of monitors,clipboard,events...
    // only one instance is needed and allocating any more would be a waste of memory.
    var widow_cntxt = widow.WidowContext.create(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_cntxt.destroy(allocator);

    // create a WindowBuilder instance.
    var builder = widow.WindowBuilder.init(
        "Simple window", // Title
        800, // Width
        600, // Height
        widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create our window,
    var mywindow = builder.withResize(true).withDPIScaling(false).build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // deinitialize when done.
    defer mywindow.deinit();
}
```

## Contributing
You can open an issue to detail a bug you encountered or propose a feature you wish to be added.  
You can also fork the project and then create a pull request.

## Dependecies
- [zigwin32](https://github.com/marlersoft/zigwin32/tree/b70e7f818d77a0c0f39b0bd9c549e16439ff5780): Provides binding for Win32 API.

