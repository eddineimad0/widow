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

## Usage
There are 2 ways to use widow in your project.
### Using the package manager
Add a dependency entry in you `build.zig.zon`.
```
.{
    .name = "Your project's name",
    .version = "0.1.0",

    .dependencies = .{
        .widow = .{
            .url = "https://github.com/eddineimad0/widow/archive/refs/tags/v0.1.1.tar.gz",
            .hash = "1220ed79771ad164d3954585fea3201e3bd0c73da2040fcad9a79a5c78afea5141e1"
        }
    }
}
```
You can choose a different release and copy it's url, as for the hash every release contains
the hash value under `ZON Hash` section.

Next declare the dependency in you `build.zig` and add it to your build step.
```
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Executable-Name",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const remote_dep = b.dependency("widow", .{
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("widow", remote_dep.module("widow"));
    b.installArtifact(exe);
}
```
### Manually adding the library.
Downaload one of the releases to your computer and copy the unziped folder
to a folder in the root of you project folder, next declare the dependency
inside your `build.zig` and add it to the build step.
In the following example we put it inside the libs folder.
```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Executable-Name",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const local_dep = b.anonymousDependency("libs/widow/", @import("libs/widow/build.zig"), .{
         .target = target,
         .optimize = optimize,
    });

    exe.addModule("widow", local_dep.module("widow"));
    b.installArtifact(exe);
}
```


## Contributing

You can open an issue to detail a bug you encountered or propose a feature you wish to be added.  
You can also fork the project and then create a pull request.

## Dependecies

- [zigwin32](https://github.com/marlersoft/zigwin32): Provides binding for Win32 API.
