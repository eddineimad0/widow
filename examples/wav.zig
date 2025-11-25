//! Microsoft RIFF Wave format decoding.
//! only common format are supported (PCM, float)

const std = @import("std");

const mem = std.mem;
const io = std.io;
const log = std.log;

//-----------------------
// Constants
//-----------------------
// FOURCC
const RIFF = @as(u32, 0x46464952); // "RIFF"
const WAVE = @as(u32, 0x45564157); // "WAVE"
const FACT = @as(u32, 0x74636166); // "fact"
const FMT = @as(u32, 0x20746d66); // "fmt "
const DATA = @as(u32, 0x61746164); // "data"
// Format tags
const WAVE_FORMAT_UNKNOWN = @as(u16, 0x0000);
const WAVE_FORMAT_PCM = @as(u16, 0x0001);
const WAVE_FORMAT_IEEE_FLOAT = @as(u16, 0x0003);

const CHUNK_HEADER_SIZE = 8;

const VALIDATE_WAVE_FILE = true; // TODO: compile options module

//----------------------------
// Types
//----------------------------

pub const Audio = struct {
    samples: []align(4) const u8,
    channels_count: u16,
    samples_rate: u32,
    bits_per_sample: u16,
    is_float: bool,
};

pub const WavDecodeError = error{
    Not_Wav_Stream,
    Invalid_Wav_Stream,
    Unsupported_Sample_Rate,
    Unsupported_Sample_Format,
    Unsupported_Channel_Count,
} || io.Reader.Error;

const WaveChunk = struct {
    fourcc: u32,
    size: u32,
};

const FmtChunk = struct {
    chunk: WaveChunk,
    sample_frames_per_sec: u32,
    avg_bytes_per_sec: u32,
    fmt_tag: u16,
    num_channels: u16,
    block_align: u16,
    bits_per_sample: u16,
};

const FactChunk = struct {
    chunk: WaveChunk,
    num_sample_frames: u32,
};

const DataChunk = struct {
    chunk: WaveChunk,
    data: []align(4) const u8,
};

pub const WaveFormat = struct {
    frequency: u32,
    byte_rate: u32,
    format: u16,
    encoding: u16,
    channels_count: u16,
    block_align: u16,
    bits_per_sample: u16,
};

//--------------------------
// Functions
//--------------------------

fn readNextChunk(r: *io.Reader) WavDecodeError!WaveChunk {
    var chunk_header: [CHUNK_HEADER_SIZE]u8 = undefined;
    try r.readSliceAll(&chunk_header);
    var chunk: WaveChunk = .{ .fourcc = 0, .size = 0 };
    chunk.fourcc = mem.readInt(u32, chunk_header[0..4], .little);
    chunk.size = mem.readInt(u32, chunk_header[4..], .little);
    if (chunk.size & 1 == 1) {
        //  If a chunk body has an odd number of bytes,
        // it must be followed by a padding byte with value 0.
        chunk.size += 1;
    }
    return chunk;
}

fn parseFmtChunk(r: *io.Reader, fc: *FmtChunk) WavDecodeError!void {
    fc.fmt_tag = try r.takeInt(u16, .little);
    fc.num_channels = try r.takeInt(u16, .little);
    fc.sample_frames_per_sec = try r.takeInt(u32, .little);
    fc.avg_bytes_per_sec = try r.takeInt(u32, .little);
    fc.block_align = try r.takeInt(u16, .little);
    fc.bits_per_sample = try r.takeInt(u16, .little);
    if (fc.chunk.size > 16) {
        const ext_size = try r.takeInt(u16, .little);
        // for WAVE_FORMAT_IEEE_FLOAT the ext_size is set to 0
        // anything else is not supported by us.
        if (ext_size != 0) {
            return WavDecodeError.Unsupported_Sample_Format;
        }
    }
}

fn parseDataChunk(
    allocator: mem.Allocator,
    r: *io.Reader,
    dc: *DataChunk,
) (mem.Allocator.Error || WavDecodeError)!void {

    // allocate a 4 byts aligned memory region
    const samples = try allocator.alignedAlloc(u8, .@"4", dc.chunk.size);
    errdefer allocator.free(samples);

    try r.readSliceAll(samples);

    dc.data = samples;
}

pub fn decode(
    allocator: mem.Allocator,
    r: *io.Reader,
) (mem.Allocator.Error || WavDecodeError)!Audio {
    var required_chunks: struct {
        fmt: bool,
        data: bool,
    } = .{ .fmt = false, .data = false };
    var wav_out = Audio{
        .samples = &.{},
        .channels_count = 0,
        .samples_rate = 0,
        .bits_per_sample = 0,
        .is_float = false,
    };
    wav_out.samples = &.{};

    errdefer {
        if (wav_out.samples.len > 0) {
            allocator.free(wav_out.samples);
        }
    }

    // read RIFF chunk
    const riff_chunk = readNextChunk(r) catch |err| {
        log.err("[WaveDecoder]: Could not read RIFF chunk\n", .{});
        return err;
    };

    const riff_type: u32 = try r.takeInt(u32, .little);
    if (riff_chunk.fourcc != RIFF or riff_type != WAVE) {
        return WavDecodeError.Not_Wav_Stream;
    }
    //wav_out.size = wave_chunk.size + 8; // the total number of bytes in the stream
    const RIFF_END = riff_chunk.size - @sizeOf(@TypeOf(riff_type));
    var data_read: usize = 0;

    while (data_read < RIFF_END) {
        const wave_chunk = readNextChunk(r) catch |err| {
            log.info("[WaveDecoder]: Unexpected end of WAVE file\n", .{});
            return err;
        };

        switch (wave_chunk.fourcc) {
            FMT => {
                var fmt_chunk: FmtChunk = undefined;
                fmt_chunk.chunk = wave_chunk;
                if (fmt_chunk.chunk.size < 16) {
                    log.info("[WaveDecoder]: Invalid fmt chunk size \n", .{});
                    return WavDecodeError.Invalid_Wav_Stream;
                }
                parseFmtChunk(r, &fmt_chunk) catch |err| {
                    log.info("[WaveDecoder]: Unexpected end of WAVE file\n", .{});
                    return err;
                };
                wav_out.channels_count = fmt_chunk.num_channels;
                wav_out.samples_rate = fmt_chunk.sample_frames_per_sec;
                wav_out.bits_per_sample = fmt_chunk.bits_per_sample;
                wav_out.is_float = switch (fmt_chunk.fmt_tag) {
                    WAVE_FORMAT_PCM => false,
                    WAVE_FORMAT_IEEE_FLOAT => true,
                    else => return WavDecodeError.Unsupported_Sample_Format,
                };

                if (VALIDATE_WAVE_FILE) {
                    // bassrt.assertEq(
                    //     fmt_chunk.avg_bytes_per_sec,
                    //     @as(u32, fmt_chunk.block_align) * @as(u32, fmt_chunk.sample_frames_per_sec),
                    //     "FMT chunk fields not consistent\n",
                    // );

                    // if (fmt_chunk.fmt_tag == WAVE_FORMAT_IEEE_FLOAT) {
                    //     bassrt.assertEq(
                    //         fmt_chunk.bits_per_sample,
                    //         32,
                    //         "FMT format is float but the bits per sample isn't 32\n",
                    //     );
                    // }
                }

                required_chunks.fmt = true;
            },
            FACT => {
                // FACT chunk is only important for non PCM formats
                // since we don't handle those we don't care about it
                // but we will store it for now
                var fact_chunk: FactChunk = undefined;
                fact_chunk.chunk = wave_chunk;
                fact_chunk.num_sample_frames = try r.takeInt(u32, .little);
            },
            DATA => {
                var data_chunk: DataChunk = undefined;
                data_chunk.chunk = wave_chunk;
                try parseDataChunk(allocator, r, &data_chunk);
                wav_out.samples = data_chunk.data;
                required_chunks.data = true;
                // DATA might not be the last chunk in the file
                // but it's all we care about once we read it we can break
                break;
            },
            else => {
                std.debug.print("[WaveDecoder] Unknown chunk type {x}\n", .{wave_chunk.fourcc});
                const discarded = try r.discard(.limited(wave_chunk.size));
                if (discarded != wave_chunk.size) {
                    return WavDecodeError.Invalid_Wav_Stream;
                }
            },
        }
        data_read += wave_chunk.size + CHUNK_HEADER_SIZE;
    }

    if (!required_chunks.data or !required_chunks.fmt) {
        // The FMT chunk and the DATA chunk are obligatory for a WAVE file
        return WavDecodeError.Invalid_Wav_Stream;
    }

    return wav_out;
}
