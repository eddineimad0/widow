const std = @import("std");
const defs = @import("./defs.zig");
const module = @import("./module.zig");
const winapi = @import("win32");
const winapi_sys_info = winapi.system.system_information;
const winapi_windows_and_messaging = winapi.ui.windows_and_messaging;
const GetModuleHandleExA = winapi.system.library_loader.GetModuleHandleExA;
const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT =
    winapi.system.library_loader.GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS =
    winapi.system.library_loader.GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = winapi.ui.hi_dpi.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2;
const PROCESS_PER_MONITOR_DPI_AWARE = winapi.ui.hi_dpi.PROCESS_PER_MONITOR_DPI_AWARE;
const VER_GREATER_EQUAL = winapi.system.system_servieces.VER_GREATER_EQUAL;
//     Foundation::{HWND, STATUS_SUCCESS},
//     Graphics::Gdi::HMONITOR,
//     System::{
//         SystemInformation::{
//             VerSetConditionMask, OSVERSIONINFOEXW, VER_BUILDNUMBER, VER_MAJORVERSION,
//             VER_MINORVERSION, VER_SERVICEPACKMAJOR, VER_SERVICEPACKMINOR,
//         },
//         SystemServices::VER_GREATER_EQUAL,
//     },
//     UI::{
//         WindowsAndMessaging::{
//             LoadCursorW, RegisterClassExW, UnregisterClassW, CS_HREDRAW, CS_OWNDC, CS_VREDRAW,
//             IDC_ARROW, WNDCLASSEXW,
//         },
//     },
// };

const WINDOW_CLASS_NAME = "WIDOW_CLASS";

const Win32Flags = struct {
    is_win7_or_above: bool,
    is_win_vist_or_above: bool,
    is_win8point1_or_above: bool,
    is_win10b1607_or_above: bool,
    is_win10b1703_or_above: bool,
};

const Win32Handles = struct {
    main_class: u16,
    helper_class: u16,
    helper_window: isize,
    // main_class_name: ?[]u8
    ntdll: ?module.HINSTANCE,
    user32: ?module.HINSTANCE,
    shcore: ?module.HINSTANCE,
    hinstance: module.HINSTANCE, // the hinstance of the process
};

const LoadedFunctions = struct {
    RtlVerifyVersionInfo: ?defs.proc_RtlVerifyVersionInfo,
    SetProcessDPIAware: ?defs.proc_SetProcessDPIAware,
    SetProcessDpiAwareness: ?defs.proc_SetProcessDpiAwareness,
    SetProcessDpiAwarenessContext: ?defs.proc_SetProcessDpiAwarenessContext,
    GetDpiForMonitor: ?defs.proc_GetDpiForMonitor,
    GetDpiForWindow: ?defs.proc_GetDpiForWindow,
    AdjustWindowRectExForDpi: ?defs.proc_AdjustWindowRectExForDpi,
    EnableNonClientDpiScaling: ?defs.EnableNonClientDpiScaling,
};

const Win32 = struct {
    flags: Win32Flags,
    handles: Win32Handles,
    functions: LoadedFunctions,
};

pub const IntenalErrors = error{
    FailedToGetModuleHandle,
    IncompleteInit,
};

const Internals = struct {
    win32: Win32,

    const Self = @This();

    pub fn init() !Self {
        var self: Self = undefined;
        // Determine the current HInstance.
        var hinstance: ?module.HINSTANCE = null;
        if (GetModuleHandleExA(
            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT | GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
            @intToPtr(?[*:0]const u8, @ptrToInt(&WINDOW_CLASS_NAME)),
            &hinstance,
        ) == 0) {
            const e = winapi.foundation.GetLastError();
            std.log.warn("Error Code {}", .{e});
            return error.FailedToGetModuleHandle;
        }
        self.win32.handles.hinstance = hinstance.?;
        // // Register the window class
        // self.win32.window_class_handle = register_window_class(
        //     self.module_handles.hinstance,
        //     self.window_class_name(),
        //     self.win32.res_icon_name,
        // )?;
        //
        // // Load the required libraries.
        // match self.load_libraries() {
        //     Ok(_) => {}
        //     Err(value) => return Err(value.to_string()),
        // };
        //
        // // Setup win32 version fields.
        // if self.is_win32_version_minimum(6, 0, (0, 0)) {
        //     self.win32.is_win_vista_or_above = true;
        //
        //     if self.is_win32_version_minimum(6, 1, (0, 0)) {
        //         self.win32.is_win7_or_above = true;
        //
        //         if self.is_win32_version_minimum(6, 3, (0, 0)) {
        //             self.win32.is_win8point1_or_above = true;
        //
        //             if self.is_win10_build_minimum(1607) {
        //                 self.win32.is_win10_1607_or_above = true;
        //
        //                 if self.is_win10_build_minimum(1703) {
        //                     self.win32.is_win10_1703_or_above = true;
        //                 }
        //             }
        //         }
        //     }
        // }
        //
        // // Declare DPI Awareness.
        // unsafe {
        //     if self.win32.is_win10_1703_or_above {
        //         self.functions.win32_SetProcessDpiAwarenessContext.unwrap()(
        //             DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
        //         );
        //     } else if self.win32.is_win8point1_or_above {
        //         self.functions.win32_SetProcessDpiAwareness.unwrap()(PROCESS_PER_MONITOR_DPI_AWARE);
        //     } else if self.win32.is_win_vista_or_above {
        //         self.functions.win32_SetProcessDPIAware.unwrap()();
        //     }
        // };
        //
        // self.create_helper_window()?;
        //
        // // Poll the current connected monitors.
        // self.devices.init_monitors();
        //
        // // register raw_input_devices
        //
        // self.is_initialized = true;
        // let r_mouse_id = RAWINPUTDEVICE {
        //     usUsagePage: 0x01,
        //     usUsage: 0x02,
        //     dwFlags: 0,
        //     hwndTarget: 0,
        // };
        // let result =
        //     unsafe { RegisterRawInputDevices(&r_mouse_id, 1, size_of_val(&r_mouse_id) as u32) };
        // if result == 0 {
        //     return Err("Failed to register Raw Device".to_owned());
        // }
        // Ok(())
        return error.IncompleteInit;
    }
};

test "test internal init" {
    // const std = @import("std");
    const testing = std.testing;
    const result = Internals.init();
    try testing.expectError(error.IncompleteInit, result);
}
