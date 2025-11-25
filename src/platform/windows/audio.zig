const std = @import("std");
const win32_com = @import("win32api/com.zig");
const win32_ole = @import("win32api/ole32.zig");
const common = @import("common");

const mem = std.mem;
const dbg = std.debug;
const common_audio = common.audio;
const win32 = std.os.windows;

const CLSID_KSDATAFORMAT_SUBTYPE_IEEE_FLOAT = win32.GUID.parse("{00000003-0000-0010-8000-00aa00389b71}");

const WasapiBackend = struct {
    device_enumerator: *win32_com.IMMDeviceEnumerator,
    device: *win32_com.IMMDevice,
    audio_client: *win32_com.IAudioClient,
    audio_render_client: *win32_com.IAudioRenderClient,
    buffer_ready_event: win32.HANDLE,
};

pub const Win32AudioSink = struct {
    wasapi: WasapiBackend,

    pub fn init(desc: common_audio.AudioSinkDescription, sbuff: *common_audio.StreamBuffer) !Win32AudioSink {
        return try createAudioSink(desc, sbuff);
    }

    pub fn deinit(sink: *Win32AudioSink) void {
        win32.CloseHandle(sink.wasapi.buffer_ready_event);
        _ = sink.wasapi.audio_client.Stop();
        _ = sink.wasapi.audio_render_client.IUnknown.Release();
        _ = sink.wasapi.audio_client.IUnknown.Release();
        _ = sink.wasapi.device.IUnknown.Release();
        _ = sink.wasapi.device_enumerator.IUnknown.Release();
    }

    /// writes a bunch of audio frames to an empty space in the audio buffer
    /// caller must make sure there is an empty space and the amount of frames fits
    /// into the space.
    pub fn write(sink: *Win32AudioSink, samples: []const u8, num_frames: u32) !void {
        var buff_ptr: ?[*]u8 = null;
        const get_result = sink.wasapi.audio_render_client.GetBuffer(num_frames, &buff_ptr);
        if (win32_ole.FAILED(get_result) or buff_ptr == null) {
            return error.Fail; // TODO: we don't won't to crash once we ship so figure out a way to recover
        }
        @memcpy(buff_ptr.?[0..samples.len], samples);
        const release_result = sink.wasapi.audio_render_client.ReleaseBuffer(num_frames, 0);
        if (win32_ole.FAILED(release_result)) {
            return error.Fail; // TODO: we don't won't to crash once we ship so figure out a way to recover
        }
    }

    /// returns the amount of frames are left in the buffer
    pub fn waitBufferReady(sink: *Win32AudioSink, timeout: ?u32) !u32 {
        const wait_time: u32 = if (timeout) |t| t else win32.INFINITE;
        win32.WaitForSingleObject(sink.wasapi.buffer_ready_event, wait_time) catch |err| {
            dbg.assert(err == error.WaitTimeOut);
            return 0;
        };
        var pad: u32 = 0;
        const getpad_result = sink.wasapi.audio_client.GetCurrentPadding(&pad);
        if (win32_ole.FAILED(getpad_result)) {
            return error.Fail; // TODO: we don't won't to crash once we ship so figure out a way to recover
        }
        return pad;
    }
};

pub fn createAudioSink(desc: common_audio.AudioSinkDescription, sbuff: *common_audio.StreamBuffer) !Win32AudioSink {
    // NOTE COM is already intialized when WidowContext is created so skip doing that

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
            return error.Fail;
        }

        const enumerate_result = device_enumerator.?.GetDefaultAudioEndpoint(
            .eRender,
            .eConsole,
            &device,
        );

        if (win32_ole.FAILED(enumerate_result) or device == null) {
            return error.Fail;
        }

        const activate_result = device.?.Activate(
            win32_com.IID_IAudioClient,
            win32_ole.CLSCTX_ALL,
            null,
            @ptrCast(&audio_client),
        );

        if (win32_ole.FAILED(activate_result) or audio_client == null) {
            return error.Fail;
        }
    }

    { // setting the wave format

        // request float 32bit format
        var wave_fmt = mem.zeroes(win32_com.WAVEFORMATEXTENSIBLE);
        wave_fmt.Format.nChannels = @intFromEnum(desc.num_channels_hint);
        wave_fmt.Format.nSamplesPerSec = @intFromEnum(desc.samples_rate_hint);
        wave_fmt.Format.wFormatTag = win32_com.WAVE_FORMAT_EXTENSIBLE;
        wave_fmt.Format.wBitsPerSample = 32;
        wave_fmt.Format.nBlockAlign = (wave_fmt.Format.nChannels * wave_fmt.Format.wBitsPerSample) / 8;
        wave_fmt.Format.nAvgBytesPerSec = wave_fmt.Format.nSamplesPerSec * wave_fmt.Format.nBlockAlign;
        wave_fmt.Format.cbSize = 22;
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
        const buff_duration: i64 = @intFromFloat(numer / denom);
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
            return error.Fail; // TODO: better errors
        }
    }

    { // check kernel mix format
        var buffer_frames: u32 = 0;
        const getbuffsize_result = audio_client.?.GetBufferSize(&buffer_frames);
        if (win32_ole.FAILED(getbuffsize_result)) {
            return error.Fail; // TODO: better errors
        }

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
    const buff_wait_event = try win32.CreateEventEx(
        null,
        "WASAPI_BUFFER_EVENT",
        0,
        win32.SYNCHRONIZE | win32.EVENT_MODIFY_STATE,
    );
    errdefer win32.CloseHandle(buff_wait_event);
    const eventset_result = audio_client.?.SetEventHandle(buff_wait_event);
    if (win32_ole.FAILED(eventset_result)) {
        return error.Fail; // TODO: better errors
    }

    { // get render client
        const getservice_result = audio_client.?.GetService(
            win32_com.IID_IAudioRenderClient,
            @ptrCast(&render_client),
        );

        if (win32_ole.FAILED(getservice_result) or render_client == null) {
            return error.Fail; // TODO: better errors
        }
    }

    { // fill buffer with silence and start
        var buff_ptr: ?[*]u8 = null;
        const getbuffer_result = render_client.?.GetBuffer(sbuff.frames_count, &buff_ptr);
        if (win32_ole.FAILED(getbuffer_result) or buff_ptr == null) {
            return error.Fail; // TODO: better errors
        }
        const buff_slice = buff_ptr.?[0..sbuff.frames_count];
        @memset(buff_slice, sbuff.frame_desc.sample_format.getSilenceValue());
        _ = render_client.?.ReleaseBuffer(sbuff.frames_count, 0);
        //TODO: this will fail unless we set the event for event driven
        const start_result = audio_client.?.Start();
        if (win32_ole.FAILED(start_result)) {
            return error.Fail; // TODO: better errors
        }
    }

    return Win32AudioSink{
        .wasapi = .{
            .device_enumerator = device_enumerator.?,
            .device = device.?,
            .audio_client = audio_client.?,
            .audio_render_client = render_client.?,
            .buffer_ready_event = buff_wait_event,
        },
    };
}

fn decodeSampleFormat(wavfmt: *win32_com.WAVEFORMATEX) !common_audio.SampleFormat {
    if (wavfmt.wFormatTag == win32_com.WAVE_FORMAT_PCM) {
        return switch (wavfmt.wBitsPerSample) {
            8 => .pcm_s8,
            16 => .pcm_s16,
            24 => .pcm_s24,
            32 => .pcm_s32,
            else => return error.FAIL,
        };
    } else {
        if (wavfmt.wBitsPerSample == 32) {
            return .ieee_f32;
        }
        return error.FAIL;
    }
}
