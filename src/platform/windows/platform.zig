const std = @import("std");
const common = @import("common");
const display = @import("display.zig");
const driver = @import("driver.zig");
const wndw = @import("window.zig");
const envinfo = @import("envinfo.zig");
const win32_gfx = @import("win32api/graphics.zig");
const win32_krnl = @import("win32api/kernel32.zig");
const win32_macros = @import("win32api/macros.zig");
const audio = @import("audio.zig");
const win32 = std.os.windows;

const mem = std.mem;
const dbg = std.debug;
const io = std.io;
const fmt = std.fmt;

pub const Window = wndw.Window;
pub const Canvas = wndw.Win32Canvas;
pub const AudioSink = audio.Win32AudioSink;
pub const AudioSinkError = audio.Win32AudioSinkError;
pub const WindowError = wndw.WindowError;

// Platform handles
pub const DisplayHandle = win32_gfx.HMONITOR;
pub const WindowHandle = win32.HWND;

pub const time = @import("time.zig");
pub const dialogbox = @import("dialogbox.zig");

pub const glLoaderFunc = @import("wgl.zig").glLoaderFunc;

pub const WidowContextError = error{
    Instance_Already_Exists,
} || driver.Win32DriverError || display.DisplayError;

pub const WidowContext = struct {
    helper_window: win32.HWND,
    allocator: mem.Allocator,
    driver: *const driver.Win32Driver,
    display_mgr: display.DisplayManager,
    windows_envinfo: envinfo.Win32EnvInfo,
    lock_file: ?win32.HANDLE,

    const Self = @This();
    fn init(a: mem.Allocator, comptime ctxt_options: common.WidowContextOptions) (mem.Allocator.Error ||
        WidowContextError ||
        WindowError)!Self {
        const d = try driver.Win32Driver.initSingleton(ctxt_options);
        errdefer driver.Win32Driver.deinitSingleton();
        const h = blk: { // create hidden window for system messages
            const helper_window = win32_gfx.CreateWindowExW(
                @bitCast(@as(u32, 0)),
                win32_macros.MAKEINTATOM(d.handles.helper_class),
                &[0:0]u16{},
                @bitCast(@as(u32, 0)),
                win32_gfx.CW_USEDEFAULT,
                win32_gfx.CW_USEDEFAULT,
                win32_gfx.CW_USEDEFAULT,
                win32_gfx.CW_USEDEFAULT,
                null,
                null,
                d.handles.hinstance,
                null,
            ) orelse {
                return WindowError.CreateFailed;
            };
            _ = win32_gfx.ShowWindow(helper_window, win32_gfx.SW_HIDE);
            break :blk helper_window;
        };
        errdefer _ = win32_gfx.DestroyWindow(h);

        var display_mgr = try display.DisplayManager.init(a);
        errdefer display_mgr.deinit(a);

        var platform_info = envinfo.getPlatformInfo(a) catch
            return mem.Allocator.Error.OutOfMemory;
        errdefer platform_info.deinit(a);

        var lock_file: ?win32.HANDLE = null;
        if (ctxt_options.force_single_instance) { // block other instances from running
            const bin_dir: ?[]const u8 = std.fs.path.dirname(platform_info.common.process.binary_path);
            if (bin_dir) |dir| {
                const file_path: [:0]const u8 = try fmt.allocPrintSentinel(
                    a,
                    "{s}\\{s}.widow.lock",
                    .{ dir, ctxt_options.win32.wndclass_name },
                    0,
                );
                defer a.free(file_path);
                lock_file = try createFileLock(file_path);
            }
        }

        return .{
            .driver = d,
            .helper_window = h,
            .display_mgr = display_mgr,
            .allocator = a,
            .windows_envinfo = platform_info,
            .lock_file = lock_file,
        };
    }
};

//------------
// Functions
//------------

pub fn createWidowContext(a: mem.Allocator, comptime ctxt_options: common.WidowContextOptions) (mem.Allocator.Error ||
    WidowContextError || WindowError)!*WidowContext {
    const ctx = try a.create(WidowContext);
    errdefer a.destroy(ctx);
    ctx.* = try WidowContext.init(a, ctxt_options);
    // register helper properties
    _ = win32_gfx.SetPropW(
        ctx.helper_window,
        display.HELPER_DISPLAY_PROP,
        @ptrCast(ctx),
    );
    return ctx;
}

pub fn destroyWidowContext(a: mem.Allocator, ctx: *WidowContext) void {
    // unregister helper properties
    _ = win32_gfx.SetPropW(
        ctx.helper_window,
        display.HELPER_DISPLAY_PROP,
        null,
    );
    _ = win32_gfx.DestroyWindow(ctx.helper_window);
    ctx.display_mgr.deinit(ctx.allocator);
    driver.Win32Driver.deinitSingleton();
    ctx.windows_envinfo.deinit(ctx.allocator);
    if (ctx.lock_file) |file| {
        win32.CloseHandle(file);
    }
    a.destroy(ctx);
}

pub inline fn getPrimaryDisplay(ctx: *const WidowContext) ?DisplayHandle {
    for (ctx.display_mgr.displays.items) |*d| {
        if (d.is_primary) {
            return d.handle;
        }
    }
    return null;
}

pub inline fn getDisplayFromWindow(ctx: *WidowContext, w: *Window) ?DisplayHandle {
    const d = ctx.display_mgr.findWindowDisplay(w) catch return null;
    return d.handle;
}

pub fn getDisplayInfo(ctx: *WidowContext, h: DisplayHandle, info: *common.video_mode.DisplayInfo) bool {
    for (ctx.display_mgr.displays.items) |*d| {
        if (d.handle == h) {
            d.getCurrentVideoMode(&info.video_mode);
            info.name_len = d.name.len;
            dbg.assert(info.name_len <= info.name.len);
            const end = @min(info.name_len, info.name.len);
            @memcpy(info.name[0..end], d.name);
            return true;
        }
    }
    return false;
}

pub fn getOsName(ctx: *WidowContext, wr: *std.io.Writer) bool {
    var ver_info = mem.zeroes(win32_krnl.OSVERSIONINFOEXW);
    ver_info.dwOSVersionInfoSize = @sizeOf(@TypeOf(ver_info));
    const ok = win32_krnl.RtlGetVersion(&ver_info);
    dbg.assert(ok == win32.NTSTATUS.SUCCESS);

    wr.writeAll("Windows ") catch return false;

    if (ctx.driver.hints.is_stupid_win11) {
        wr.writeAll("11 ") catch return false;
    } else if (ctx.driver.hints.is_win10b1607_or_above) {
        wr.writeAll("10 ") catch return false;
    }
    //NOTE: never tried running widow on these
    // platform and i don't know if it can
    else if (ctx.driver.hints.is_win8point1_or_above) {
        wr.writeAll("8.1 ") catch return false;
    } else if (ctx.driver.hints.is_win7_or_above) {
        wr.writeAll("7 ") catch return false;
    } else if (ctx.driver.hints.is_win_vista_or_above) {
        wr.writeAll("Vista ") catch return false;
    } else {
        wr.writeAll("XP or older ") catch return false;
    }

    wr.print(
        "({d}.{d}.{d}), ",
        .{ ver_info.dwMajorVersion, ver_info.dwMinorVersion, ver_info.dwBuildNumber },
    ) catch return false;

    switch (ver_info.wProductType) {
        win32_krnl.VER_NT_WORKSTATION => wr.writeAll("NT Workstation") catch return false,
        win32_krnl.VER_NT_DOMAIN_CONTROLLER => wr.writeAll("NT Domain Controller") catch return false,
        win32_krnl.VER_NT_SERVER => wr.writeAll("NT Server") catch return false,
        else => {},
    }
    return true;
}

pub inline fn getRuntimeEnvInfo(ctx: *WidowContext) *const common.envinfo.RuntimeEnv {
    return &ctx.windows_envinfo.common;
}

/// attempt to create a lock file so that running multiple instances of the application can be detected
fn createFileLock(file_path: [:0]const u8) WidowContextError!win32.HANDLE {
    const lock_file = win32_krnl.CreateFileA(
        file_path.ptr,
        win32_krnl.GENERIC_WRITE,
        win32_krnl.FILE_SHARE_NONE,
        null,
        win32_krnl.CREATE_ALWAYS,
        win32_krnl.FILE_ATTRIBUTE_NORMAL | win32_krnl.FILE_FLAG_DELETE_ON_CLOSE,
        null,
    );
    if (lock_file == win32.INVALID_HANDLE_VALUE and
        win32.GetLastError() == win32.Win32Error.SHARING_VIOLATION)
    {
        return WidowContextError.Instance_Already_Exists;
    }
    return lock_file;
}

test "platform_unit_test" {
    @import("std").testing.refAllDecls(display);
    @import("std").testing.refAllDecls(driver);
    @import("std").testing.refAllDecls(@import("dynlib.zig"));
}
