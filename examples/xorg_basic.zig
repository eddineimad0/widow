const std = @import("std");
const widow = @import("widow");
const EventType = widow.EventType;
const VirtualCode = widow.keyboard_and_mouse.VirtualCode;
var gpa_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();
    // first we need to preform some platform specific initialization.
    // an options tuple can be passed to customize the platform init
    // e.g on windows we can set the WNDClass name to a comptime string of our choice,
    try widow.initWidowPlatform(.{ .wnd_class = "Zig_is_awesome" });
    // clean up code to be called, when done using the library.
    defer widow.deinitWidowPlatform();

    var widow_cntxt = widow.WidowContext.init(allocator) catch {
        std.debug.print("Failed to Allocate a WidowContext instance\n", .{});
        return;
    };
    // destroy it when done.
    defer widow_cntxt.deinit();

    // create a WindowBuilder.
    // this action might fail if we fail to allocate space for the title.
    var builder = widow.WindowBuilder.init(
        "Simple window",
        800,
        600,
        &widow_cntxt,
    ) catch |err| {
        std.debug.print("Failed to create a window builder {}\n", .{err});
        return;
    };

    // create the window,
    var mywindow = builder.build() catch |err| {
        std.debug.print("Failed to build the window,{}\n", .{err});
        return;
    };

    // No longer nedded.
    builder.deinit();
    // closes the window when done.
    defer mywindow.deinit();
    std.time.sleep(5 * std.time.ns_per_s);
}
