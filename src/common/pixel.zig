//============
// Constants
//============
pub const ALPHA_OPAQUE = 255;
pub const ALPHA_TRANSPARENT = 0;

//============
// Types
//============
const PixelChannelOrder = enum(u4) {
    none = 0,
    rgb = 1,
    bgr = 2,
    rgba = 3,
    rgbx = 4,
    argb = 5,
    xrgb = 6,
    bgra = 7,
    bgrx = 8,
    abgr = 9,
    xbgr = 10,
};

const PixelChannelLayout = enum(u3) {
    none = 0,
    @"565" = 1,
    @"888" = 2,
    @"8888" = 3,
    @"2101010" = 4,
};

pub const PixelFormatDesc = packed struct(u32) {
    bits: u8,
    bytes: u4,
    order: PixelChannelOrder,
    layout: PixelChannelLayout,
    _reserved: u13 = 0,
};

// | Format Name                        | Bits | Channels                      | Common Usage                                                 |
// | ---------------------------------- | ---- | ----------------------------- | ------------------------------------------------------------ |
// | **RGBA8888 / ARGB8888 / BGRA8888** | 32   | 8 bits per R, G, B, A         | Most modern desktop, mobile, and game engines                |
// | **RGB888**                         | 24   | 8 bits per R, G, B            | Common for physical displays (monitors usually ignore alpha) |
// | **RGB565**                         | 16   | 5 bits R, 6 bits G, 5 bits B  | Older/embedded devices, microcontrollers                     |
// | **ARGB2101010**                    | 32   | 10 bits per R, G, B, 2 bits A | HDR and high-end monitors (increasingly common)              |
pub const PixelFormat = enum(u32) {
    Unknown = 0,
    rgb_565 = @bitCast(PixelFormatDesc{
        .bits = 16,
        .bytes = 2,
        .order = .rgb,
        .layout = .@"565",
    }),
    bgr_565 = @bitCast(PixelFormatDesc{
        .bits = 16,
        .bytes = 2,
        .order = .bgr,
        .layout = .@"565",
    }),
    rgb_888 = @bitCast(PixelFormatDesc{
        .bits = 24,
        .bytes = 3,
        .order = .rgb,
        .layout = .@"888",
    }),
    bgr_888 = @bitCast(PixelFormatDesc{
        .bits = 24,
        .bytes = 3,
        .order = .bgr,
        .layout = .@"888",
    }),
    rgba_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .rgba,
        .layout = .@"8888",
    }),
    rgbx_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .rgbx,
        .layout = .@"8888",
    }),
    bgra_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .bgra,
        .layout = .@"8888",
    }),
    bgrx_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .bgrx,
        .layout = .@"8888",
    }),
    argb_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .argb,
        .layout = .@"8888",
    }),
    xrgb_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .xrgb,
        .layout = .@"8888",
    }),
    argb_2101010 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .argb,
        .layout = .@"2101010",
    }),
    xrgb_2101010 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .xrgb,
        .layout = .@"2101010",
    }),
    abgr_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .abgr,
        .layout = .@"8888",
    }),
    xbgr_8888 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .xbgr,
        .layout = .@"8888",
    }),
    abgr_2101010 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .abgr,
        .layout = .@"2101010",
    }),
    xbgr_2101010 = @bitCast(PixelFormatDesc{
        .bits = 32,
        .bytes = 4,
        .order = .xbgr,
        .layout = .@"2101010",
    }),
};

pub const PixelFormatInfo = struct {
    fmt: PixelFormat,
    red: struct {
        mask: u32,
        loss: u8,
        shift: u8,
    },
    green: struct {
        mask: u32,
        loss: u8,
        shift: u8,
    },
    blue: struct {
        mask: u32,
        loss: u8,
        shift: u8,
    },
    alpha: struct {
        mask: u32,
        loss: u8,
        shift: u8,
    },
    bytes_per_pixel: u8,
    bits_per_pixel: u8,
};

//============
// Functions
//============
pub fn getPixelFormat(
    bits_per_pixel: u32,
    rmask: u32,
    gmask: u32,
    bmask: u32,
    amask: u32,
) PixelFormat {
    switch (bits_per_pixel) {
        16 => {
            if (rmask == 0xf800 and
                gmask == 0x07e0 and
                bmask == 0x001f and
                amask == 0x0) return .rgb_565;
            if (rmask == 0x001f and
                gmask == 0x07e0 and
                bmask == 0xf800 and
                amask == 0x0) return .bgr_565;
        },
        24 => {
            if (rmask == 0xff0000 and
                gmask == 0x00ff00 and
                bmask == 0x0000ff and
                amask == 0x0) return .rgb_888;

            if (rmask == 0x0000ff and
                gmask == 0x00ff00 and
                bmask == 0xff0000 and
                amask == 0x0) return .bgr_888;
        },
        32 => {
            if (rmask == 0x00FF0000 and
                gmask == 0x0000FF00 and
                bmask == 0x000000FF and
                amask == 0x00000000)
                return .xrgb_8888;

            if (rmask == 0xFF000000 and
                gmask == 0x00FF0000 and
                bmask == 0x0000FF00 and
                amask == 0x00000000)
                return .rgbx_8888;

            if (rmask == 0x000000FF and
                gmask == 0x0000FF00 and
                bmask == 0x00FF0000 and
                amask == 0x00000000)
                return .xbgr_8888;

            if (rmask == 0x0000FF00 and
                gmask == 0x00FF0000 and
                bmask == 0xFF000000 and
                amask == 0x00000000)
                return .bgrx_8888;

            if (rmask == 0x00FF0000 and
                gmask == 0x0000FF00 and
                bmask == 0x000000FF and
                amask == 0xFF000000)
                return .argb_8888;

            if (rmask == 0xFF000000 and
                gmask == 0x00FF0000 and
                bmask == 0x0000FF00 and
                amask == 0x000000FF)
                return .rgba_8888;

            if (rmask == 0x000000FF and
                gmask == 0x0000FF00 and
                bmask == 0x00FF0000 and
                amask == 0xFF000000)
                return .abgr_8888;

            if (rmask == 0x0000FF00 and
                gmask == 0x00FF0000 and
                bmask == 0xFF000000 and
                amask == 0x000000FF)
                return .bgra_8888;

            if (rmask == 0x3FF00000 and
                gmask == 0x000FFC00 and
                bmask == 0x000003FF and
                amask == 0x00000000)
                return .xrgb_2101010;

            if (rmask == 0x000003FF and
                gmask == 0x000FFC00 and
                bmask == 0x3FF00000 and
                amask == 0x00000000)
                return .xbgr_2101010;

            if (rmask == 0x3FF00000 and
                gmask == 0x000FFC00 and
                bmask == 0x000003FF and
                amask == 0xC0000000)
                return .argb_2101010;

            if (rmask == 0x000003FF and
                gmask == 0x000FFC00 and
                bmask == 0x3FF00000 and
                amask == 0xC0000000)
                return .abgr_2101010;
        },
        else => return .Unknown,
    }
    return .Unknown;
}

pub fn getPixelFormatInfo(
    bits_per_pixel: u8,
    rmask: u32,
    gmask: u32,
    bmask: u32,
    amask: u32,
    out: *PixelFormatInfo,
) void {
    const bytes_per_pixel = ((bits_per_pixel - 1) / 8) + 1;
    var mask: u32 = rmask;
    var rshift: u8, var rloss: u8 = .{ 0, 8 };
    if (rmask != 0) {
        while (mask & 1 == 0) : (mask >>= 1)
            rshift += 1;

        while (mask & 1 == 1) : (mask >>= 1)
            rloss -= 1;
    }

    mask = gmask;
    var gshift: u8, var gloss: u8 = .{ 0, 8 };
    if (gmask != 0) {
        while (mask & 1 == 0) : (mask >>= 1)
            gshift += 1;

        while (mask & 1 == 1) : (mask >>= 1)
            gloss -= 1;
    }

    mask = bmask;
    var bshift: u8, var bloss: u8 = .{ 0, 8 };
    if (bmask != 0) {
        while (mask & 1 == 0) : (mask >>= 1)
            bshift += 1;

        while (mask & 1 == 1) : (mask >>= 1)
            bloss -= 1;
    }

    mask = amask;
    var ashift: u8, var aloss: u8 = .{ 0, 8 };
    if (amask != 0) {
        while (mask & 1 == 0) : (mask >>= 1)
            ashift += 1;

        while (mask & 1 == 1) : (mask >>= 1)
            aloss -= 1;
    }

    out.* = .{
        .fmt = getPixelFormat(bits_per_pixel, rmask, gmask, bmask, amask),
        .red = .{
            .mask = rmask,
            .loss = rloss,
            .shift = rshift,
        },
        .green = .{
            .mask = gmask,
            .loss = gloss,
            .shift = gshift,
        },
        .blue = .{
            .mask = bmask,
            .loss = bloss,
            .shift = bshift,
        },
        .alpha = .{
            .mask = amask,
            .loss = aloss,
            .shift = ashift,
        },
        .bytes_per_pixel = bytes_per_pixel,
        .bits_per_pixel = bits_per_pixel,
    };
}

pub inline fn mapRGBA(fmt: *const PixelFormatInfo, r: u32, g: u32, b: u32, a: u32) u32 {
    return ((r >> fmt.red.loss) << fmt.red.shift) |
        ((g >> fmt.green.loss) << fmt.green.shift) |
        ((b >> fmt.blue.loss) << fmt.blue.shift) |
        ((a >> fmt.alpha.loss) << fmt.alpha.shift);
}

pub inline fn mapRGB(fmt: *const PixelFormatInfo, r: u32, g: u32, b: u32) u32 {
    return ((r >> fmt.red.loss) << fmt.red.shift) |
        ((g >> fmt.green.loss) << fmt.green.shift) |
        ((b >> fmt.blue.loss) << fmt.blue.shift) |
        fmt.alpha.mask;
}
