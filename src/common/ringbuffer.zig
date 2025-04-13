const std = @import("std");

const mem = std.mem;
const math = std.math;
const dbg = std.debug;

pub fn RingBuffer(comptime T: type) type {
    return struct {
        data: []T,
        write_index: usize,
        read_index: usize,

        const Self = @This();

        /// Allocate a new `RingBuffer`, `deinit()` should be called to free the buffer.
        pub fn init(
            allocator: mem.Allocator,
            capacity: usize,
        ) (mem.Allocator.Error || error{CapacityZero})!Self {
            if (capacity == 0) {
                return error.CapacityZero;
            }

            const final_capacity = if (((capacity - 1) & capacity) == 0)
                math.ceilPowerOfTwoAssert(usize, capacity)
            else
                capacity;

            dbg.assert(capacity > 0);
            const data = try allocator.alloc(T, final_capacity);

            return .{
                .data = data,
                .write_index = 0,
                .read_index = 0,
            };
        }

        /// Free the data backing a `RingBuffer` must be passed the same `Allocator` as
        /// `init()`.
        pub fn deinit(self: *Self, allocator: mem.Allocator) void {
            allocator.free(self.data);
            self.* = undefined;
        }

        /// Returns `index` modulo the length of the backing slice.
        pub inline fn mask(self: *const Self, index: usize) usize {
            return index & (self.data.len - 1);
        }

        /// Write `T` into the ring buffer. If the ring buffer is full, the
        /// oldest byte is overwritten.
        pub fn write(self: *Self, item: *const T) void {
            self.data[self.write_index] = item.*;
            self.write_index = self.mask(self.write_index + 1);
        }

        pub fn read(self: *Self) ?T {
            if (self.isEmpty()) return null;
            const item = self.data[self.read_index];
            self.read_index = self.mask(self.read_index + 1);
            return item;
        }

        /// Returns `true` if the ring buffer is empty and `false` otherwise.
        pub fn isEmpty(self: *const Self) bool {
            return self.write_index == self.read_index;
        }
    };
}
