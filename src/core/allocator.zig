const std = @import("std");
pub const gpa = std.heap.c_allocator;

pub const DefaultAllocator = struct {
    const Self = @This();

    pub fn alloc(comptime T: type, size: usize) ?[]T {
        return gpa.alloc(T, size) catch null;
    }

    pub fn s_alloc(comptime T: type) ?*T {
        return gpa.create(T) catch null;
    }

    pub fn calloc(comptime T: type, size: usize) ?[]T {
        const ptr = Self.alloc(T, size) catch null;
        std.mem.set(T, ptr, 0);
        return ptr;
    }

    pub fn realloc(old_ptr: anytype, new_size: usize) ?[]@TypeOf(old_ptr) {
        return gpa.realloc(old_ptr, new_size);
    }

    pub fn free(ptr: anytype) void {
        gpa.free(ptr);
    }

    pub fn s_free(ptr: anytype) void {
        gpa.destroy(ptr);
    }
};
