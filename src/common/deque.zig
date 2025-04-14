const std = @import("std");

const mem = std.mem;
const math = std.math;
const dbg = std.debug;

pub fn Deque(comptime T: type) type {
    return struct {
        data: []T,
        size: usize,
        front: usize,

        const Self = @This();

        /// create a new `Deque`, the allocator is used to allocate the backing buffer.
        /// `deinit()` should be called to free the buffer.
        /// capacity can't be 0 and is adjusted to a power of 2
        pub fn init(
            allocator: mem.Allocator,
            capacity: usize,
        ) (mem.Allocator.Error || error{CapacityZero})!Self {
            if (capacity == 0) {
                return error.CapacityZero;
            }

            const final_capacity = if (((capacity - 1) & capacity) == 0)
                capacity
            else
                math.ceilPowerOfTwoAssert(usize, capacity);

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

        inline fn writeIndex(self: *const Self) usize {
            return (self.front + self.size) % self.data.len;
        }

        //WARN: Shouldn't be called if the dequeue isn't full since it doesn't
        // handle all cases, so keep it private and watch how you use it.
        fn doubleCapacity(self: *Self, a: mem.Allocator) mem.Allocator.Error!void {
            dbg.assert(self.isFull());
            const new_capacity = self.data.len * 2;
            const new_buffer = try a.alloc(T, new_capacity);
            const first_copy_size = self.data.len - self.front;
            @memcpy(new_buffer[0..first_copy_size], self.data[self.front..]);
            @memcpy(
                new_buffer[first_copy_size..(first_copy_size + self.writeIndex())],
                self.data[0..self.writeIndex()],
            );

            a.free(self.data);
            self.data = new_buffer;
            self.front = 0;
        }

        fn copyDataBuffer(self: *Self, dst_buffer: []T) void {
            dbg.assert(self.size <= dst_buffer.len);
            if (self.writeIndex() > self.front) {
                @memcpy(dst_buffer[0..self.size], self.data[self.front..(self.front + self.size)]);
            } else {
                const first_copy_size = self.data.len - self.front;
                @memcpy(dst_buffer[0..first_copy_size], self.data[self.front..]);
                @memcpy(
                    dst_buffer[first_copy_size..(first_copy_size + self.writeIndex())],
                    self.data[0..self.writeIndex()],
                );
            }
        }

        /// new_capacity can't be 0 and is adjusted to a power of 2
        /// Will only work if the current `deque` size is less or equal to the new_capacity
        /// otherwise false is returned
        pub fn shrinkCapacity(
            self: *Self,
            a: mem.Allocator,
            new_capacity: usize,
        ) (mem.Allocator.Error || error{CapacityZero})!bool {
            if (new_capacity == 0) return error.CapacityZero;

            if(self.size > new_capacity){
                return false;
            }


            const final_capacity = if (((new_capacity - 1) & new_capacity) == 0)
                new_capacity
            else
                math.ceilPowerOfTwoAssert(usize, new_capacity);

            if (self.data.len <= final_capacity) {
                return true;
            }

            if (self.isEmpty()) {
                self.data = try a.realloc(self.data, final_capacity);
            } else {
                const new_buffer = try a.alloc(T, new_capacity);
                self.copyDataBuffer(new_buffer);
                a.free(self.data);
                self.data = new_buffer;
            }

            self.front = 0;
            return true;
        }

        /// Returns `true` if the queue is empty and `false` otherwise.
        pub inline fn isEmpty(self: *const Self) bool {
            return self.size == 0;
        }

        /// Returns `true` if the queue is full and `false` otherwise.
        pub inline fn isFull(self: *const Self) bool {
            return self.size == self.data.len;
        }

        pub inline fn getCapacity(self:*const Self) usize {
            return self.data.len;
        }

        pub fn pushBack(self: *Self, a: mem.Allocator, item: *const T) mem.Allocator.Error!void {
            if (self.isFull()) {
                try self.doubleCapacity(a);
            }

            self.data[self.writeIndex()] = item.*;
            self.size += 1;
        }

        pub fn popFront(self: *Self, output: *T) bool {
            if (self.isEmpty()) {
                return false;
            }

            output.* = self.data[self.front];
            self.front = (self.front + 1) % self.data.len;
            self.size -= 1;
            return true;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.front = 0;
            self.size = 0;
        }
    };
}

test "deque_create_destory" {
    const testing = std.testing;
    var d = try Deque(u8).init(testing.allocator, 10);
    defer d.deinit(testing.allocator);
    try testing.expectEqual(d.data.len, 16);
    try testing.expectEqual(d.size, 0);
    try testing.expectEqual(d.front, 0);
    try testing.expect(d.isEmpty());

    try testing.expectError(error.CapacityZero, Deque(u8).init(testing.allocator, 0));
}

test "deque_pushBack_popFront" {
    const testing = std.testing;
    var d = try Deque(u8).init(testing.allocator, 5);
    defer d.deinit(testing.allocator);
    try d.pushBack(testing.allocator, &10);
    try testing.expect(!d.isEmpty());
    try testing.expectEqual(d.size, 1);
    var data: u8 = 0;
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 10);
    try testing.expect(d.isEmpty());
    try testing.expect(!d.isFull());
    try testing.expectEqual(d.size, 0);

    try d.pushBack(testing.allocator, &20);
    try d.pushBack(testing.allocator, &30);
    try testing.expectEqual(d.size, 2);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 20);
    try testing.expectEqual(d.size, 1);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 30);
    try testing.expectEqual(d.size, 0);
    try testing.expect(d.isEmpty());
    try testing.expect(!d.isFull());
}

test "deque_mixed_operations" {
    const testing = std.testing;
    var d = try Deque(i32).init(testing.allocator, 4);
    defer d.deinit(testing.allocator);

    try d.pushBack(testing.allocator, &-1);
    try d.pushBack(testing.allocator, &0);
    try d.pushBack(testing.allocator, &1);
    try d.pushBack(testing.allocator, &2); // [-1, 0, 1, 2] - Full
    try testing.expectEqual(d.size, 4);
    try testing.expect(d.isFull());
    try testing.expect(!d.isEmpty());
    var data: i32 = 0;
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, -1);
    try testing.expectEqual(d.size, 3);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 0);
    try testing.expectEqual(d.size, 2);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 1);
    try testing.expectEqual(d.size, 1);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 2);
    try testing.expectEqual(d.size, 0);
}

test "deque_wrap_around" {
    const testing = std.testing;
    var d = try Deque(i32).init(testing.allocator, 4);
    defer d.deinit(testing.allocator);

    try d.pushBack(testing.allocator, &1);
    try d.pushBack(testing.allocator, &2);
    try d.pushBack(testing.allocator, &3); //  r        w
    try d.pushBack(testing.allocator, &4); // [1, 2, 3, 4] - Full

    var data: i32 = 0;
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 1); //    r      w
    try testing.expectEqual(d.size, 3); // [_, 2, 3, 4]

    //  w  r
    try d.pushBack(testing.allocator, &5); // [5, 2, 3, 4] - Full

    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 2);
    try testing.expectEqual(d.size, 3);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 3);
    try testing.expectEqual(d.size, 2);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 4);
    try testing.expectEqual(d.size, 1);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 5);
    try testing.expectEqual(d.size, 0);
    // no more
    try testing.expect(d.isEmpty());
    try testing.expect(!d.isFull());
    try testing.expect(!d.popFront(&data));
    try testing.expectEqual(data, 5);
    try testing.expectEqual(d.size, 0);

    try d.pushBack(testing.allocator, &6); //  r     w
    try d.pushBack(testing.allocator, &7); // [_, 6, 7, _]
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 6);
    try testing.expectEqual(d.size, 1);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 7);
    try testing.expectEqual(d.size, 0);

    try testing.expect(d.isEmpty());
    try testing.expect(!d.isFull());
    try testing.expect(!d.popFront(&data));
    try testing.expectEqual(data, 7);
    try testing.expectEqual(d.size, 0);
}

test "deque_resize" {
    const testing = std.testing;
    var d = try Deque(i32).init(testing.allocator, 2);
    defer d.deinit(testing.allocator);
    try testing.expectEqual(d.data.len, 2);

    try d.pushBack(testing.allocator, &5); //  r   w
    try d.pushBack(testing.allocator, &10); // [5, 10] - Full
    try testing.expectEqual(d.size, 2);
    try testing.expect(d.isFull());
    try testing.expect(!d.isEmpty());

    // Trigger resize by pushing back
    try d.pushBack(testing.allocator, &20); // Should resize (cap=4), becomes [5, 10, 20, X]
    try testing.expectEqual(d.data.len, 4);
    try testing.expectEqual(d.size, 3);
    try testing.expect(!d.isFull());
    try testing.expect(!d.isEmpty());
    var data: i32 = 0;
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 5); //    r    w
    try testing.expectEqual(d.size, 2); // [X, 10, 20, X]

    // Fill it up again
    try d.pushBack(testing.allocator, &40);
    try d.pushBack(testing.allocator, &80); // w   r
    try testing.expectEqual(d.size, 4); //   [80, 10, 20, 40] - Full
    try testing.expect(d.isFull());
    try testing.expect(!d.isEmpty());

    // Trigger another resize
    try d.pushBack(testing.allocator, &160); // Should resize (cap=8), becomes [10, 20, 40, 80, 160, X, X, X]
    try testing.expectEqual(d.data.len, 8); //                                 r                w
    try testing.expectEqual(d.size, 5);
    try testing.expect(!d.isFull());
    try testing.expect(!d.isEmpty());

    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 10);
    try testing.expectEqual(d.size, 4);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 20);
    try testing.expectEqual(d.size, 3);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 40);
    try testing.expectEqual(d.size, 2);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 80);
    try testing.expectEqual(d.size, 1);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data, 160);
    try testing.expectEqual(d.size, 0);
    try testing.expect(d.isEmpty());
    try testing.expect(!d.isFull());
}


test "deque_shrinking" {
    const INITIAL_CAP = 32;

    const testing = std.testing;
    var d = try Deque(usize).init(testing.allocator, INITIAL_CAP);
    defer d.deinit(testing.allocator);
    try testing.expectEqual(d.data.len, INITIAL_CAP);

    const FILL_COUNT = 8;
    for (0..FILL_COUNT)|i| {
        try d.pushBack(testing.allocator, &i);
    }
    try testing.expectEqual(d.size, FILL_COUNT);
    try testing.expectEqual(d.data.len, INITIAL_CAP);
    // [0,1,2,3,4,5,6,7,X,...]
    //  r               w

    try testing.expect(try d.shrinkCapacity(testing.allocator, FILL_COUNT));
    // [0,1,2,3,4,5,6,7]
    //  r+w
    try testing.expectEqual(d.size, FILL_COUNT);
    try testing.expectEqual(d.data.len, FILL_COUNT);
    var data:usize = undefined;
    for (0..FILL_COUNT)|i| {
        try testing.expect(d.popFront(&data));
        try testing.expectEqual(data,i);
    }
    try testing.expectEqual(d.size, 0);
    try testing.expectEqual(d.data.len, FILL_COUNT);

    // refill
    for (0..FILL_COUNT)|i| {
        try d.pushBack(testing.allocator, &i);
    }
    try testing.expectEqual(d.size, FILL_COUNT);
    try testing.expectEqual(d.data.len, FILL_COUNT);

    // keep only half
    for (0..(FILL_COUNT - 2))|i| {
        try testing.expect(d.popFront(&data));
        try testing.expectEqual(data,i);
    }
    for (0..2)|i| {
        try d.pushBack(testing.allocator, &i);
    }
    try testing.expectEqual(d.size, FILL_COUNT/2);
    try testing.expectEqual(d.data.len, FILL_COUNT);
    // [0,1,x,x,x,x,6,7]
    //     w        r

    try testing.expect(try d.shrinkCapacity(testing.allocator, FILL_COUNT/2));
    // [6,7,0,1]
    // r+w
    try testing.expectEqual(d.size, FILL_COUNT/2);
    try testing.expectEqual(d.data.len, FILL_COUNT/2);

    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data,6);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data,7);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data,0);
    try testing.expect(d.popFront(&data));
    try testing.expectEqual(data,1);

}
