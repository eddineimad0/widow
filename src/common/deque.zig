const std = @import("std");

const mem = std.mem;
const math = std.math;
const dbg = std.debug;

pub fn Deque(comptime T: type) type {
    return struct {
        data: []T,
        size:usize,
        front:usize,

        const Self = @This();

        /// create a new `Deque`, the allocator is used to allocate the backing buffer.
       /// `deinit()` should be called to free the buffer.
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
                .size = 0,
                .front = 0,
            };
        }

        /// Free the data backing the `Deque` must be passed the same `Allocator` as
        /// `init()`.
        pub fn deinit(self: *Self, allocator: mem.Allocator) void {
            allocator.free(self.data);
            self.* = undefined;
        }

        pub inline fn writeIndex(self: *const Self) usize {
            return (self.front + self.size) % self.data.len;
        }

        pub fn doubleCapacity(self:*Self,a:mem.Allocator)mem.Allocator.Error!void{
            const new_capacity = self.data.len * 2;
            const new_buffer = try a.alloc(T, new_capacity);
            if(self.writeIndex() >= self.front){
                @memcpy(new_buffer, self.data[self.front..]);
            }else{
                @memcpy(new_buffer, self.data[self.front..]);
                const amount_copied = self.data.len - self.front;
                @memcpy(new_buffer[amount_copied..], self.data[0..self.writeIndex()]);
            }
            a.free(self.data);
            self.data = new_buffer;
            self.front = 0;
        }


        /// Returns `true` if the queue is empty and `false` otherwise.
        pub inline fn isEmpty(self: *const Self) bool {
            return self.size == 0;
        }

        /// Returns `true` if the queue is full and `false` otherwise.
        pub inline fn isFull(self: *const Self) bool {
            return self.size == self.data.len;
        }

        pub fn pushBack(self:*Self,a:mem.Allocator,item:*const T)mem.Allocator.Error!void{
            if(self.isFull()){
                try self.doubleCapacity(a);
            }

            self.data[self.writeIndex()] = item.*;
            self.size += 1;
        }

        pub fn popFront(self:*Self, output:*T)bool{
            if(self.isEmpty()){
                return false;
            }

            output.* = self.data[self.front];
            self.front = (self.front + 1) % self.data.len;
            self.size -= 1;
            return true;

            // TODO: (Optional) Shrinking logic
        }
    };
}


test "deque" {
    //TODO: add unit tests.
}
