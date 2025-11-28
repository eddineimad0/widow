const std = @import("std");
const widow = @import("widow");
const wav = @import("wav.zig");
const EventType = widow.event.EventType;
const EventQueue = widow.event.EventQueue;
const KeyCode = widow.input.keyboard.KeyCode;
const audio = widow.audio;

var gpa_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    defer std.debug.assert(gpa_allocator.deinit() == .ok);
    const allocator = gpa_allocator.allocator();

    const ctx = widow.createWidowContext(allocator, .{ .force_single_instance = true }) catch |err| {
        if (err == error.Instance_Already_Exists) {
            // only allow one instance
            widow.dialog.showMessageDialog("Another instance of audio_stream.exe is already running\n only one can run at a time");
            return;
        }
        return err;
    };
    defer widow.destroyWidowContext(allocator, ctx);

    var sink = try audio.AudioSink.init(allocator, .{
        .samples_rate_hint = .@"44100Hz",
        .num_channels_hint = .stereo,
        .stream_buffer_frames = 2048,
    }, null);
    defer sink.deinit(allocator);
    std.debug.print("Sink Stream buffer:\n", .{});
    std.debug.print("bytesize={d}\n", .{sink.stream_buffer.bytesize});
    std.debug.print("frames_count={d}\n", .{sink.stream_buffer.frames_count});
    std.debug.print("frame_bytessize={d}\n", .{sink.stream_buffer.frame_bytesize});
    std.debug.print("samples_per_frame={d}\n", .{sink.stream_buffer.samples_per_frame});
    std.debug.print("samples_per_second={d}\n", .{sink.stream_buffer.samples_rate});
    std.debug.print("Frame description:\n", .{});
    std.debug.print("number of channels={t}\n", .{sink.stream_buffer.frame_desc.num_channels});
    std.debug.print("sample format={t}\n", .{sink.stream_buffer.frame_desc.sample_format});
    const sound = try prepareAudioSamples(allocator);
    defer allocator.free(sound);
    var written: usize = 0;
    while (written < sound.len) {
        try sink.update();
        const samples = sink.waitBufferReady(null);
        const dst: []f32 = @ptrCast(samples);
        const src = sound[written..];
        @memset(dst, 0);
        const limit = @min(dst.len, src.len);
        @memcpy(dst[0..limit], src[0..limit]);
        written += limit;
        sink.submitBuffer();
    }
}

fn prepareAudioSamples(allocator: std.mem.Allocator) ![]const f32 {
    const filedata = @embedFile("data/UntitledTrack01.wav");
    var reader = std.io.Reader.fixed(filedata);
    const audio_data = try wav.decode(allocator, &reader, null);
    defer allocator.free(audio_data.samples);
    std.debug.print("Audio:\n", .{});
    std.debug.print("channels count={d}\n", .{audio_data.channels_count});
    std.debug.print("samples rate={d}\n", .{audio_data.samples_rate});
    std.debug.print("bit per sample={d}\n", .{audio_data.bits_per_sample});
    std.debug.print("is float format={}\n", .{audio_data.is_float});
    const i16_samples: []const i16 = @ptrCast(audio_data.samples);
    const final_samples = try allocator.alloc(f32, i16_samples.len);
    convertInt16ToFloat32(final_samples, i16_samples);
    return final_samples;
}

/// converts sample in {-32768,32767} range to [-1.0,1.0)
fn convertInt16ToFloat32(dst: []f32, src: []const i16) void {
    std.debug.assert(dst.len == src.len); // samples count should be the same
    const I16_MAX = std.math.maxInt(i16); // 32767
    const _1_DIV_32768 = @as(f32, 1.0) / @as(f32, I16_MAX + 1);
    for (0..src.len) |i| {
        dst[i] = @floatFromInt(src[i]);
        dst[i] *= _1_DIV_32768;
    }
}
