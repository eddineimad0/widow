//! Some usefule windows.h Macros.

const win32 = @import("std").os.windows;

/// Replacement for the `MAKEINTATOM` macro in the windows api.
pub inline fn MAKEINTATOM(atom: u16) ?[*:0]align(1) const u16 {
    return @ptrFromInt(atom);
}

/// Replacement for the `MAKEINTRESOURCESA` macro in the windows api.
pub inline fn MAKEINTRESOURCESA(comptime r: u16) ?[*:0]const u8 {
    return @ptrFromInt(r);
}

/// Replacement for the `MAKEINTRESOURCESW` macro in the windows api.
pub inline fn MAKEINTRESOURCESW(comptime r: u16) ?[*:0]align(1) const u16 {
    return @ptrFromInt(r);
}

pub inline fn hiWord(bits: usize) u16 {
    return @truncate((bits >> 16) & 0xFFFF);
}

pub inline fn loWord(bits: usize) u16 {
    return @truncate((bits & 0xFFFF));
}

pub inline fn getXLparam(bits: usize) i16 {
    return @bitCast(loWord(bits));
}

pub inline fn getYLparam(bits: usize) i16 {
    return @bitCast(hiWord(bits));
}

pub inline fn isHighSurrogate(surrogate: u16) bool {
    return (surrogate >= 0xD800 and surrogate <= 0xDBFF);
}

pub inline fn isLowSurrogate(surrogate: u16) bool {
    return (surrogate >= 0xDC00 and surrogate <= 0xDFFF);
}
