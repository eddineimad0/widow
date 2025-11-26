const std = @import("std");
const common = @import("common");
const platform = @import("platform");

const mem = std.mem;
const io = std.io;
const dbg = std.debug;

const AudioSinkBackend = platform.AudioSink;
pub const AudioSinkError = platform.AudioSinkError;

/// An audio sink is just interface to a platform audio device,
/// it doesn't do any mixing or volume control, it simply checks
/// if the audio buffer needs more samples and provides a slice
/// for the user to write them
/// # Platform APIs
/// * on windows it uses WASAPI
/// * on linux it uses ALSA
pub const AudioSink = struct {
    /// a slice into our audio buffer memory
    slice: []align(4) u8,
    stream_buffer: common.audio.StreamBuffer,
    backend: AudioSinkBackend,
    pending: struct {
        frames: u32,
        samples: []align(4) u8,
    },

    const Self = @This();

    /// initializes and AudioSink that matches the given description
    /// we pick the default audio rendering device.
    /// # Parameters
    /// `allocator`: use to allocate internal audio buffer memory, the same allocator should be use with [`AudioSink.deinit`]
    /// `asdesc`: a description of the requested AudioSink properties such as audio format number of frames...
    /// `err_wr`: optional writer that receives a detailed error message and platform error code.
    /// # Errors
    /// the returned errors depend on the platform backend but if it fails it usually because
    /// we couldn't create an AudioSink that matches the description or couldn't find any audio rendering device to use.
    /// # Note
    /// haven't tested if creating more than 1 sink is possible, it might fail or it might succeed and cause a bug
    /// don't do it
    pub fn init(
        allocator: mem.Allocator,
        asdesc: common.audio.AudioSinkDescription,
        err_wr: ?*io.Writer,
    ) (mem.Allocator.Error || AudioSinkError)!AudioSink {
        var sbuff: common.audio.StreamBuffer = undefined;
        var discarding = io.Writer.Discarding.init(&.{});
        const err_writer = if (err_wr) |wr| wr else &discarding.writer;
        var backend = try AudioSinkBackend.init(asdesc, &sbuff, err_writer);
        errdefer backend.deinit();
        return .{
            .slice = try allocator.alignedAlloc(u8, .@"4", sbuff.bytesize),
            .stream_buffer = sbuff,
            .backend = backend,
            .pending = .{
                .frames = 0,
                .samples = &.{},
            },
        };
    }

    pub inline fn deinit(sink: *Self, allocator: mem.Allocator) void {
        sink.backend.deinit();
        allocator.free(sink.slice);
    }

    /// this function updates the AudioSink state
    /// this includes:
    /// * switching audio rendering device if the user environement has changed (new default device or current device was unplugged)
    /// if a call to this function finds the device in an invalid state
    /// it attempts as best as it can to recover from that if it fails an error is returned
    /// # Error
    /// [`AudioSinkError.NoAudioRenderDevice`]: the previous audio hardware was unplugged and we couldn't grab a new one
    /// [`AudioSinkError.AudioRenderDeviceSwitchFail`]: we tried to switch to the new default device but we failed (unlikley to happen)
    /// we stick the old device in that case
    pub inline fn update(sink: *Self) AudioSinkError!void {
        try sink.backend.update();
    }

    /// this function blocks the calling thread and waits
    /// for a free block in the audio buffer, it then returns a
    /// slice into that block memory that the caller can fill with audio samples
    /// to be played.
    /// once the returned slice is fully filled caller should call [`AudioSink.submitBuffer`]
    /// so that the samples can be flushed to the audio buffer
    /// # Parameters
    /// `timeout`: an optional number of milliseconds upon which the function stops waiting
    /// and returns an empty slice
    /// # NOTE
    /// to avoid audio glitches it is best to minimize the time spent between
    /// [`AudioSink.waitBufferReady`] returning the slice and calling [`AudioSink.submitBuffer`]
    pub fn waitBufferReady(sink: *Self, timeout: ?u32) []align(4) u8 {
        const remaining_frames = sink.backend.waitBufferReady(timeout);
        if (remaining_frames) |rf| {
            dbg.assert(rf <= sink.stream_buffer.frames_count);
            const frames_to_write: u32 = sink.stream_buffer.frames_count - rf;
            const samples_to_fill = frames_to_write * sink.stream_buffer.frame_bytesize;
            sink.pending.frames = frames_to_write;
            sink.pending.samples = sink.slice[0..samples_to_fill];
        }
        return sink.pending.samples;
    }

    /// flushes the samples written to the audio buffer
    pub inline fn submitBuffer(sink: *Self) void {
        if (sink.pending.frames == 0) {
            dbg.assert(sink.pending.samples.len == 0);
            return;
        }
        sink.backend.write(sink.pending.samples, sink.pending.frames);
        sink.pending.frames = 0;
        sink.pending.samples = &.{};
    }
};
