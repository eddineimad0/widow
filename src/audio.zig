const std = @import("std");
const common = @import("common");
const platform = @import("platform");

const mem = std.mem;
const io = std.io;
const dbg = std.debug;

const AudioSinkBackend = platform.AudioSink;

/// An audio sink is just interface to the audio device use by the window
/// it doesn't do any mixing or volume control it simply takes
/// a buffer of audio samples and writes it to the audio device
pub const AudioSink = struct {
    /// a slice into our audio buffer memory
    slice: []align(4) u8,
    stream_buffer: common.audio.StreamBuffer,
    backend: AudioSinkBackend,
    pending_frames: u32,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, asdesc: common.audio.AudioSinkDescription) !AudioSink {
        var sbuff: common.audio.StreamBuffer = undefined;
        var backend = try AudioSinkBackend.init(asdesc, &sbuff);
        errdefer backend.deinit();
        return .{
            .slice = try allocator.alignedAlloc(u8, .@"4", sbuff.bytesize),
            .stream_buffer = sbuff,
            .backend = backend,
            .pending_frames = 0,
        };
    }

    pub inline fn deinit(sink: *Self, allocator: mem.Allocator) void {
        sink.backend.deinit();
        allocator.free(sink.slice);
    }

    pub fn waitDeviceReady(sink: *Self, timeout: ?u32) ![]align(4) u8 {
        const remaining_frames = try sink.backend.waitBufferReady(timeout);
        dbg.assert(remaining_frames <= sink.stream_buffer.frames_count);
        const frames_to_write: u32 = sink.stream_buffer.frames_count - remaining_frames;
        const samples_to_fill = frames_to_write * sink.stream_buffer.frame_bytesize;
        sink.pending_frames = frames_to_write;
        return sink.slice[0..samples_to_fill];
    }

    pub fn writeFrames(sink: *Self, samples: []align(4) u8) !void {
        const samples_to_fill = sink.pending_frames * sink.stream_buffer.frame_bytesize;
        dbg.assert(samples_to_fill == samples.len);
        try sink.backend.write(samples, sink.pending_frames);
        sink.pending_frames = 0;
    }
};
