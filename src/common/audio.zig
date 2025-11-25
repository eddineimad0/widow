///! audio streaming device
const std = @import("std");

///Channel count : this just number that represent how many sound waves are there in an audio stream.
///an audio stream that consist of one sound wave is said to be monomorphic hence `mono` audio
///if it contains 2 seperate sound waves it's called stereo
pub const ChannelCount = enum(u8) {
    mono = 1,
    stereo = 2,
};

/// A sample is just a number that represent the amplitude of signal (audio wave in this case).
/// sample rate/frequency: the number of samples per second. 44100Hz and 48000Hz are the most commonly used
/// in digital audio
pub const SamplesRate = enum(u32) {
    // Extreme lows
    @"8000Hz" = 8000,
    @"11025Hz" = 11025,
    @"16000Hz" = 16000,
    // Lows
    @"22050Hz" = 22050,
    @"24000Hz" = 24000,
    @"32000Hz" = 32000,
    // Most common
    @"44100Hz" = 44100,
    @"48000Hz" = 48000,
    // Highs
    @"88200Hz" = 88200,
    @"96000Hz" = 96000,
    @"176400Hz" = 176400,
    @"192000Hz" = 192000,
    // Extreme highs
    @"352800Hz" = 352800,
    @"384000Hz" = 384000,

    pub inline fn fromU32(value: u32) ?@This() {
        return switch (value) {
            8000 => .@"8000Hz",
            11025 => .@"11025Hz",
            16000 => .@"16000Hz",
            22050 => .@"22050Hz",
            24000 => .@"24000Hz",
            32000 => .@"32000Hz",
            44100 => .@"44100Hz",
            48000 => .@"48000Hz",
            88200 => .@"88200Hz",
            96000 => .@"96000Hz",
            176400 => .@"176400Hz",
            192000 => .@"192000Hz",
            352800 => .@"352800Hz",
            384000 => .@"384000Hz",
            else => null,
        };
    }
};

/// A sample can be encoded using various data format
/// although we enumerate a bunch here we're gonna stick to f32
/// thought our API
pub const SampleFormat = enum(u8) {
    const SampleFormatFields = packed struct {
        is_signed: u1,
        is_float: u1,
        bit_size: u6,
    };

    pcm_u8 = @bitCast(SampleFormatFields{ .is_signed = 0, .is_float = 0, .bit_size = 8 }),
    pcm_s8 = @bitCast(SampleFormatFields{ .is_signed = 1, .is_float = 0, .bit_size = 8 }),
    pcm_s16 = @bitCast(SampleFormatFields{ .is_signed = 1, .is_float = 0, .bit_size = 16 }),
    pcm_s24 = @bitCast(SampleFormatFields{ .is_signed = 1, .is_float = 0, .bit_size = 24 }),
    pcm_s32 = @bitCast(SampleFormatFields{ .is_signed = 1, .is_float = 0, .bit_size = 32 }),
    ieee_f32 = @bitCast(SampleFormatFields{ .is_signed = 1, .is_float = 1, .bit_size = 32 }),

    pub inline fn getByteSize(fmt: SampleFormat) u8 {
        const aff: SampleFormatFields = @bitCast(@intFromEnum(fmt));
        return aff.bit_size / 8;
    }

    pub inline fn getBitSize(fmt: SampleFormat) u8 {
        const aff: SampleFormatFields = @bitCast(@intFromEnum(fmt));
        return aff.bit_size;
    }

    pub inline fn getSilenceValue(fmt: SampleFormat) u8 {
        return switch (fmt) {
            .pcm_u8 => 0x80,
            else => 0x00,
        };
    }
};

/// A frame is a block of audio data containing a sample for each channel, in mono audio a frame is 1 sample,
/// in stereo it's 2 samples
pub const FrameDescription = struct {
    sample_format: SampleFormat,
    num_channels: ChannelCount,
};

/// holds a description of our audio stream buffer
pub const StreamBuffer = struct {
    /// the byte size of the entire audio buffer
    bytesize: u32,
    /// number of frames that the buffer can hold
    frames_count: u32,
    /// the size of one frame in bytes
    frame_bytesize: u32,
    /// number of samples per frame
    samples_per_frame: u16,
    /// number of samples read per second
    samples_rate: SamplesRate,
    /// a description of the buffer frames
    frame_desc: FrameDescription,
};

/// Provides a description of the desired audio sink properites
/// `samples_rate_hint` and `num_channels_hint` are just hints for the primary audio device
/// the actual hardware might or might not support them but
/// we try to get as close as possible to their values while prioritizing the sample rate
pub const AudioSinkDescription = struct {
    /// a hit to the requested sample rate
    samples_rate_hint: SamplesRate,
    /// a hint to how many channels are requested
    num_channels_hint: ChannelCount,
    /// how many frames should the buffer hold
    stream_buffer_frames: u16,

    pub const DEFAULT: @This() = .{
        .samples_rate_hint = .@"44100Hz",
        .num_channels_hint = .mono,
        .stream_buffer_frames = 2048,
    };
};
