const std = @import("std");
const win32_com = @import("win32api/com.zig");
const win32_ole = @import("win32api/ole32.zig");
const win32_krnl = @import("win32api/kernel32.zig");
const win32_error = @import("win32api/error_codes.zig");
const common = @import("common");

const mem = std.mem;
const io = std.io;
const dbg = std.debug;
const common_audio = common.audio;
const win32 = std.os.windows;

const CLSID_KSDATAFORMAT_SUBTYPE_IEEE_FLOAT = win32.GUID.parse("{00000003-0000-0010-8000-00aa00389b71}");
const AUDCLNT_E_DEVICE_INVALIDATED = @as(win32.HRESULT, -2004287484);
pub const DEVICE_STATE_ACTIVE = @as(u32, 1);
pub const DEVICE_STATE_DISABLED = @as(u32, 2);
pub const DEVICE_STATE_NOTPRESENT = @as(u32, 4);
pub const DEVICE_STATE_UNPLUGGED = @as(u32, 8);

const WasapiError = error{
    COMCreateFail,
    COMInitFail,
    WasapiDeviceInitFail,
    WasapiDeviceActivateFail,
    WasapiSetEventFail,
    WasapiRegisterNotifClientFail,
};

var notif_client = WasapiNotifClient{
    .imm_notif_client = .{
        .vtable = &WasapiNotifClientVtable,
    },
    .default_device_change_event = undefined,
};
const com_sucks = struct {
    /// IUnknown
    fn QueryInterface(
        self: *const win32_com.IUnknown,
        riid: *const win32.GUID,
        ppvObject: ?*?*anyopaque,
    ) callconv(.winapi) win32.HRESULT {
        _ = self;
        _ = riid;
        _ = ppvObject;
        return win32.E_NOINTERFACE;
    }
    fn AddRef(_: *const win32_com.IUnknown) callconv(.winapi) u32 {
        return 2;
    }
    fn Release(_: *const win32_com.IUnknown) callconv(.winapi) u32 {
        return 1;
    }

    /// IMMNotificationClient
    fn OnDeviceStateChanged(
        self: *const win32_com.IMMNotificationClient,
        pwstrDeviceId: ?[*:0]const u16,
        dwNewState: u32,
    ) callconv(.winapi) win32.HRESULT {
        _ = self;
        _ = pwstrDeviceId;
        _ = dwNewState;
        return win32.S_OK;
    }

    fn OnDeviceAdded(
        self: *const win32_com.IMMNotificationClient,
        pwstrDeviceId: ?[*:0]const u16,
    ) callconv(.winapi) win32.HRESULT {
        _ = self;
        _ = pwstrDeviceId;
        return win32.S_OK;
    }

    fn OnDeviceRemoved(
        self: *const win32_com.IMMNotificationClient,
        pwstrDeviceId: ?[*:0]const u16,
    ) callconv(.winapi) win32.HRESULT {
        _ = self;
        _ = pwstrDeviceId;
        return win32.S_OK;
    }

    fn OnDefaultDeviceChanged(
        self: *const win32_com.IMMNotificationClient,
        flow: win32_com.EDataFlow,
        role: win32_com.ERole,
        pwstrDefaultDeviceId: ?[*:0]const u16,
    ) callconv(.winapi) win32.HRESULT {
        _ = pwstrDefaultDeviceId;
        if (flow == win32_com.EDataFlow.eRender and role == win32_com.ERole.eConsole) {
            const client: *const WasapiNotifClient = @ptrCast(self);
            _ = win32_krnl.SetEvent(client.default_device_change_event);
        }
        return win32.S_OK;
    }

    fn OnPropertyValueChanged(
        self: *const win32_com.IMMNotificationClient,
        pwstrDeviceId: ?[*:0]const u16,
        key: win32_com.PROPERTYKEY,
    ) callconv(.winapi) win32.HRESULT {
        _ = self;
        _ = pwstrDeviceId;
        _ = key;
        return win32.S_OK;
    }
};

const WasapiNotifClientVtable: win32_com.IMMNotificationClient.VTable = .{
    .base = .{
        .QueryInterface = com_sucks.QueryInterface,
        .AddRef = com_sucks.AddRef,
        .Release = com_sucks.Release,
    },
    .OnDeviceStateChanged = com_sucks.OnDeviceStateChanged,
    .OnDeviceAdded = com_sucks.OnDeviceAdded,
    .OnDeviceRemoved = com_sucks.OnDeviceRemoved,
    .OnDefaultDeviceChanged = com_sucks.OnDefaultDeviceChanged,
    .OnPropertyValueChanged = com_sucks.OnPropertyValueChanged,
};

const WasapiNotifClient = extern struct {
    imm_notif_client: win32_com.IMMNotificationClient,
    default_device_change_event: win32.HANDLE,
};

const WasapiBackend = struct {
    device_enumerator: *win32_com.IMMDeviceEnumerator,
    device: *win32_com.IMMDevice,
    audio_client: *win32_com.IAudioClient,
    audio_render_client: *win32_com.IAudioRenderClient,
    buffer_ready_event: win32.HANDLE,
    wave_format: win32_com.WAVEFORMATEXTENSIBLE,
    buff_duration: i64, // in 100 nano-seconds units
    notification_client: *const WasapiNotifClient,
};

pub const Win32AudioSinkError = error{
    NoAudioRenderDevice,
    AudioRenderDeviceSwitchFail,
} || WasapiError;

pub const Win32AudioSink = struct {
    wasapi: WasapiBackend,

    pub fn init(
        desc: common_audio.AudioSinkDescription,
        sbuff: *common_audio.StreamBuffer,
        err_wr: *io.Writer,
    ) Win32AudioSinkError!Win32AudioSink {
        return try createAudioSink(desc, sbuff, err_wr);
    }

    pub fn deinit(sink: *Win32AudioSink) void {
        _ = sink.wasapi.audio_client.Stop();
        _ = sink.wasapi.audio_render_client.IUnknown.Release();
        _ = sink.wasapi.audio_client.IUnknown.Release();
        _ = sink.wasapi.device.IUnknown.Release();
        _ = sink.wasapi.device_enumerator.IUnknown.Release();
        win32.CloseHandle(sink.wasapi.buffer_ready_event);
        win32.CloseHandle(sink.wasapi.notification_client.default_device_change_event);
        win32_ole.CoUninitialize();
    }

    pub fn update(sink: *Win32AudioSink) Win32AudioSinkError!void {
        if (sink.checkForDeviceChange()) {
            try sink.switchDefaultDevice();
        }
    }

    /// returns the amount of frames are left in the buffer
    /// or null if it couldn't because the device got invalidated
    pub fn waitBufferReady(sink: *Win32AudioSink, timeout: ?u32) ?u32 {
        const wait_time: u32 = if (timeout) |t| t else win32.INFINITE;
        win32.WaitForSingleObject(sink.wasapi.buffer_ready_event, wait_time) catch |err| {
            dbg.assert(err == error.WaitTimeOut);
            return null;
        };
        var pad: u32 = 0;
        const getpad_result = sink.wasapi.audio_client.GetCurrentPadding(&pad);
        if (win32_ole.FAILED(getpad_result)) {
            @branchHint(.unlikely);
            return null;
        }
        return pad;
    }

    /// writes a bunch of audio frames to an empty space in the audio buffer
    /// caller must make sure there is an empty space and the amount of frames fits
    /// into the space.
    /// if the client is invalidated it does nothing
    pub fn write(sink: *Win32AudioSink, samples: []const u8, num_frames: u32) void {
        dbg.assert(num_frames != 0);
        var buff_ptr: ?[*]u8 = null;
        const get_result = sink.wasapi.audio_render_client.GetBuffer(num_frames, &buff_ptr);
        if (win32_ole.FAILED(get_result) or buff_ptr == null) {
            @branchHint(.unlikely);
            return; // we failed
        }

        @memcpy(buff_ptr.?[0..samples.len], samples);
        _ = sink.wasapi.audio_render_client.ReleaseBuffer(num_frames, 0);
    }

    /// Checks if the default audio rendering device was changed and attempt to switch to it
    /// returns true if a change happend, false otherwise
    inline fn checkForDeviceChange(sink: *Win32AudioSink) bool {
        win32.WaitForSingleObject(
            sink.wasapi.notification_client.default_device_change_event,
            0,
        ) catch return false; // no change
        return true;
    }

    /// switches the current audio rendering device to the new default one
    /// it also set the audio format for the new device to the one use
    /// during initialization of the AudioSink
    /// # Error
    /// this function only fails if the default audio device is changed(unplugged or through settings) again
    /// while we are switching, that however should never happend in practice
    /// because the process will run this code faster than user can modify his environement
    fn switchDefaultDevice(sink: *Win32AudioSink) Win32AudioSinkError!void {
        var device: ?*win32_com.IMMDevice = null;
        var audio_client: ?*win32_com.IAudioClient = null;
        var render_client: ?*win32_com.IAudioRenderClient = null;
        errdefer {
            if (device) |d| _ = d.IUnknown.Release();
            if (audio_client) |ac| _ = ac.IUnknown.Release();
            if (render_client) |rc| _ = rc.IUnknown.Release();
        }

        const enumerate_result = sink.wasapi.device_enumerator.GetDefaultAudioEndpoint(
            .eRender,
            .eConsole,
            &device,
        );
        if (win32_ole.FAILED(enumerate_result) or device == null) {
            return Win32AudioSinkError.NoAudioRenderDevice;
        }

        const activate_result = device.?.Activate(
            win32_com.IID_IAudioClient,
            win32_ole.CLSCTX_ALL,
            null,
            @ptrCast(&audio_client),
        );
        if (win32_ole.FAILED(activate_result) or audio_client == null) {
            return Win32AudioSinkError.AudioRenderDeviceSwitchFail;
        }

        const init_result = audio_client.?.Initialize(
            win32_com.AUDCLNT_SHAREMODE_SHARED,
            win32_com.AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                win32_com.AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY |
                win32_com.AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
            sink.wasapi.buff_duration,
            0,
            @ptrCast(&sink.wasapi.wave_format),
            null,
        );
        if (win32_ole.FAILED(init_result)) {
            return Win32AudioSinkError.AudioRenderDeviceSwitchFail;
        }

        const eventset_result = audio_client.?.SetEventHandle(sink.wasapi.buffer_ready_event);
        if (win32_ole.FAILED(eventset_result)) {
            return Win32AudioSinkError.AudioRenderDeviceSwitchFail;
        }

        const getservice_result = audio_client.?.GetService(
            win32_com.IID_IAudioRenderClient,
            @ptrCast(&render_client),
        );
        if (win32_ole.FAILED(getservice_result) or render_client == null) {
            return Win32AudioSinkError.AudioRenderDeviceSwitchFail;
        }

        const start_result = audio_client.?.Start();
        if (win32_ole.FAILED(start_result)) {
            return Win32AudioSinkError.AudioRenderDeviceSwitchFail;
        }

        errdefer unreachable;
        _ = sink.wasapi.audio_render_client.IUnknown.Release();
        _ = sink.wasapi.audio_client.Stop();
        _ = sink.wasapi.audio_client.IUnknown.Release();
        _ = sink.wasapi.device.IUnknown.Release();
        sink.wasapi.device = device.?;
        sink.wasapi.audio_client = audio_client.?;
        sink.wasapi.audio_render_client = render_client.?;
    }
};

pub fn createAudioSink(desc: common_audio.AudioSinkDescription, sbuff: *common_audio.StreamBuffer, err_wr: *io.Writer) Win32AudioSinkError!Win32AudioSink {
    const result = win32_ole.CoInitializeEx(null, win32.COINIT.MULTITHREADED);
    if (result != win32.S_OK and result != win32.S_FALSE) {
        return WasapiError.COMInitFail;
    }

    var device_enumerator: ?*win32_com.IMMDeviceEnumerator = null;
    var device: ?*win32_com.IMMDevice = null;
    var audio_client: ?*win32_com.IAudioClient = null;
    var render_client: ?*win32_com.IAudioRenderClient = null;
    errdefer {
        if (device_enumerator) |de| {
            _ = de.IUnknown.Release();
        }
        if (device) |dev| {
            _ = dev.IUnknown.Release();
        }
        if (audio_client) |ac| {
            _ = ac.IUnknown.Release();
        }
        if (render_client) |rc| {
            _ = rc.IUnknown.Release();
        }
    }

    { // acquiring the audio client
        const create_result = win32_ole.CoCreateInstance(
            win32_com.CLSID_MMDeviceEnumerator,
            null,
            win32_ole.CLSCTX_ALL,
            win32_com.IID_IMMDeviceEnumerator,
            @ptrCast(&device_enumerator),
        );

        if (win32_ole.FAILED(create_result) or device_enumerator == null) {
            err_wr.print("COM HRESULT = {d}", .{create_result}) catch {};
            return WasapiError.COMCreateFail;
        }

        const enumerate_result = device_enumerator.?.GetDefaultAudioEndpoint(
            .eRender,
            .eConsole,
            &device,
        );

        if (win32_ole.FAILED(enumerate_result) or device == null) {
            err_wr.print("HRESULT = {d}", .{enumerate_result}) catch {};
            return Win32AudioSinkError.NoAudioRenderDevice;
        }

        const activate_result = device.?.Activate(
            win32_com.IID_IAudioClient,
            win32_ole.CLSCTX_ALL,
            null,
            @ptrCast(&audio_client),
        );

        if (win32_ole.FAILED(activate_result) or audio_client == null) {
            err_wr.print("HRESULT = {d}", .{activate_result}) catch {};
            return WasapiError.WasapiDeviceActivateFail;
        }
    }

    var wave_fmt = mem.zeroes(win32_com.WAVEFORMATEXTENSIBLE);
    var buff_duration: i64 = 0;
    { // setting the wave format

        // request float 32bit format
        wave_fmt.Format.nChannels = @intFromEnum(desc.num_channels_hint);
        wave_fmt.Format.nSamplesPerSec = @intFromEnum(desc.samples_rate_hint);
        wave_fmt.Format.wFormatTag = win32_com.WAVE_FORMAT_EXTENSIBLE;
        wave_fmt.Format.wBitsPerSample = 32;
        wave_fmt.Format.nBlockAlign = (wave_fmt.Format.nChannels * wave_fmt.Format.wBitsPerSample) / 8;
        wave_fmt.Format.nAvgBytesPerSec = wave_fmt.Format.nSamplesPerSec * wave_fmt.Format.nBlockAlign;
        wave_fmt.Format.cbSize = 22; // this should always equal the number of valid bytes after wave_fmt.Format
        wave_fmt.Samples.wValidBitsPerSample = 32;
        switch (desc.num_channels_hint) {
            .mono => wave_fmt.dwChannelMask = win32_com.SPEAKER_FRONT_CENTER,
            .stereo => wave_fmt.dwChannelMask = win32_com.SPEAKER_FRONT_LEFT | win32_com.SPEAKER_FRONT_RIGHT,
        }
        wave_fmt.SubFormat = CLSID_KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;

        const sample_rate: f64 = @floatFromInt(@intFromEnum(desc.samples_rate_hint));
        // in 100 nanoseconds units
        const denom: f64 = sample_rate / (std.time.ns_per_s / 100);
        const numer: f64 = @floatFromInt(desc.stream_buffer_frames);
        buff_duration = @intFromFloat(numer / denom);

        const init_result = audio_client.?.Initialize(
            win32_com.AUDCLNT_SHAREMODE_SHARED,
            win32_com.AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                win32_com.AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY |
                win32_com.AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
            buff_duration,
            0,
            @ptrCast(&wave_fmt),
            null,
        );

        if (win32_ole.FAILED(init_result)) {
            err_wr.print("HRESULT = {d}", .{init_result}) catch {};
            return WasapiError.WasapiDeviceInitFail;
        }
    }

    { // check kernel mix format
        var buffer_frames: u32 = 0;
        const getbuffsize_result = audio_client.?.GetBufferSize(&buffer_frames);
        if (win32_ole.FAILED(getbuffsize_result)) {
            err_wr.print("HRESULT = {d}", .{getbuffsize_result}) catch {};
            return WasapiError.WasapiDeviceInitFail;
        }
        dbg.assert(buffer_frames == desc.stream_buffer_frames);

        sbuff.* = .{
            .frames_count = buffer_frames,
            .frame_bytesize = @sizeOf(f32) * @intFromEnum(desc.num_channels_hint),
            .samples_per_frame = @intFromEnum(desc.num_channels_hint),
            .bytesize = buffer_frames * @sizeOf(f32) * @intFromEnum(desc.num_channels_hint),
            .samples_rate = desc.samples_rate_hint,
            .frame_desc = .{
                .sample_format = .ieee_f32,
                .num_channels = desc.num_channels_hint,
            },
        };
    }

    // set the event for notifications
    const buff_wait_event = win32.CreateEventEx(
        null,
        "WIDOW_WASAPI_BUFFER_EVENT",
        0,
        win32.SYNCHRONIZE | win32.EVENT_MODIFY_STATE,
    ) catch return WasapiError.WasapiSetEventFail;
    errdefer win32.CloseHandle(buff_wait_event);
    const eventset_result = audio_client.?.SetEventHandle(buff_wait_event);
    if (win32_ole.FAILED(eventset_result)) {
        err_wr.print("HRESULT = {d}", .{eventset_result}) catch {};
        return WasapiError.WasapiSetEventFail;
    }

    { // get render client
        const getservice_result = audio_client.?.GetService(
            win32_com.IID_IAudioRenderClient,
            @ptrCast(&render_client),
        );

        if (win32_ole.FAILED(getservice_result) or render_client == null) {
            err_wr.print("HRESULT = {d}", .{getservice_result}) catch {};
            return WasapiError.WasapiDeviceInitFail;
        }
    }

    { // fill buffer with silence and start
        var buff_ptr: ?[*]u8 = null;
        const getbuffer_result = render_client.?.GetBuffer(sbuff.frames_count, &buff_ptr);
        if (win32_ole.FAILED(getbuffer_result) or buff_ptr == null) {
            err_wr.print("HRESULT = {d}", .{getbuffer_result}) catch {};
            return WasapiError.WasapiDeviceInitFail;
        }
        const buff_slice = buff_ptr.?[0..sbuff.frames_count];
        @memset(buff_slice, sbuff.frame_desc.sample_format.getSilenceValue());
        _ = render_client.?.ReleaseBuffer(sbuff.frames_count, 0);
        const start_result = audio_client.?.Start();
        if (win32_ole.FAILED(start_result)) {
            err_wr.print("HRESULT = {d}", .{start_result}) catch {};
            return WasapiError.WasapiDeviceInitFail;
        }
    }

    const default_device_change_event = win32.CreateEventEx(
        null,
        "WIDOW_WASAPI_DEVICE_EVENT",
        0,
        win32.SYNCHRONIZE | win32.EVENT_MODIFY_STATE,
    ) catch return WasapiError.WasapiRegisterNotifClientFail;
    errdefer win32.CloseHandle(default_device_change_event);
    notif_client.default_device_change_event = default_device_change_event;

    const register_notif_result = device_enumerator.?.RegisterEndpointNotificationCallback(@ptrCast(&notif_client));
    if (win32_ole.FAILED(register_notif_result)) {
        err_wr.print("HRESULT = {d}", .{register_notif_result}) catch {};
        return WasapiError.WasapiRegisterNotifClientFail;
    }

    return Win32AudioSink{
        .wasapi = .{
            .device_enumerator = device_enumerator.?,
            .device = device.?,
            .audio_client = audio_client.?,
            .audio_render_client = render_client.?,
            .buffer_ready_event = buff_wait_event,
            .wave_format = wave_fmt,
            .buff_duration = buff_duration, // in 100 nano-seconds units
            .notification_client = &notif_client,
        },
    };
}
