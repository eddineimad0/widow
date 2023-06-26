const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        pub const Node = struct {
            next: ?*Node = null,
            data: T,
        };

        head: ?*Node,
        allocator: std.mem.Allocator,

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = null,
                .allocator = allocator,
            };
        }

        /// Empties the queue, and releases all alocated memory.
        pub fn deinit(self: *Self) void {
            var current = self.head orelse return;
            while (current.next) |next| {
                self.allocator.destroy(current);
                current = next;
            }
            self.allocator.destroy(current);
            self.head = null;
        }

        /// Appends `item` to the queue.
        pub fn append(self: *Self, item: *const T) !void {
            var node = try self.allocator.create(Node);
            node.next = null;
            node.data = item.*;
            var current = self.head orelse {
                self.head = node;
                return;
            };
            std.debug.assert(self.head != null);
            while (current.next) |next| {
                current = next;
            }
            current.next = node;
        }

        /// Gets the first item in the queue or returns `null` if there is none.
        pub fn get(self: *const Self) ?*T {
            const head = self.head orelse return null;
            return &head.data;
        }

        /// Removes the first item from the queue, returns whether item was actually removed.
        pub fn removeFront(self: *Self) bool {
            const head = self.head orelse return false;
            self.head = head.next;
            self.allocator.destroy(head);
            return true;
        }

        /// Removes the first item in the queue and returns it's value,
        /// or returns `null` if there is none.
        pub fn popFront(self: *Self) ?T {
            const first = self.get() orelse return null;
            const item = first.*;
            _ = self.removeFront();
            return item;
        }
    };
}

// The std library has an unmanged linked list
pub fn LinkedList(comptime T: type) type {
    return struct {
        pub const Node = struct {
            next: ?*Node = null,
            data: T,
        };

        head: ?*Node,
        len: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = null,
                .len = 0,
                .allocator = allocator,
            };
        }

        /// Empties the queue, and releases all alocated memory.
        pub fn deinit(self: *Self) void {
            var current = self.head orelse return;
            while (current.next) |next| {
                self.allocator.destroy(current);
                current = next;
            }
            self.allocator.destroy(current);
            self.head = null;
            self.len = 0;
        }

        /// Appends `item` to the list.
        pub fn append(self: *Self, item: *const T) !void {
            var node = try self.allocator.create(Node);
            node.next = null;
            node.data = item.*;
            self.len += 1;
            var current = self.head orelse {
                std.debug.assert(self.head == null);
                self.head = node;
                return;
            };
            while (current.next) |next| {
                current = next;
            }
            current.next = node;
        }

        /// Gets the first item in the list or returns `null` if there is none.
        pub fn get(self: *Self) ?*T {
            const head = self.head orelse return null;
            return &head.data;
        }

        /// Gets the element at position 'index' or returns `null` if there is none.
        /// Same as array indexing with 0 corresponding to the first element.
        pub fn getAt(self: *Self, index: usize) ?*T {
            var current = self.head orelse return null;
            for (0..index) |_| {
                current = current.next orelse return null;
            }
            return &current.data;
        }

        /// Returns the position of the element that matches the predicate.
        pub fn find(self: *const Self, target: *const T, predicate: *const fn (*const T, *const T) bool) ?usize {
            var current = self.head orelse return null;
            var index: usize = 0;
            while (current.next) |next| {
                if (predicate(&current.data, target)) {
                    return index;
                }
                current = next;
                index += 1;
            }

            // last chance
            if (predicate(&current.data, target)) {
                return index;
            } else {
                return null;
            }
        }

        /// Removes the first item from the list, returns whether item was actually removed.
        pub fn removeFront(self: *Self) bool {
            const head = self.head orelse return false;
            self.head = head.next;
            self.allocator.destroy(head);
            self.len -= 1;
            return true;
        }

        /// Removes the nth item from the list, returns whether item was actually removed.
        pub fn removeAt(self: *Self, index: usize) bool {
            var current = self.head orelse return false;
            var previous: ?*Node = null;
            for (0..index) |_| {
                previous = current;
                current = current.next orelse return false;
            }
            if (previous) |prev| {
                prev.next = current.next;
            } else {
                self.head = current.next;
                std.debug.assert(self.head == null);
                std.debug.assert(previous == null);
            }
            self.allocator.destroy(current);
            self.len -= 1;
            return true;
        }

        /// Removes the first item in the list and returns it's value,
        /// or returns `null` if there is none.
        pub fn popFront(self: *Self) ?T {
            const first = self.get() orelse return null;
            const item = first.*;
            _ = self.removeFront();
            return item;
        }
    };
}

test "Queue test" {
    const testing = std.testing;
    var int_queue = Queue(u32).init(testing.allocator);
    const int_array = [5]u32{ 1, 2, 3, 4, 5 };
    try int_queue.append(&int_array[0]);
    try int_queue.append(&int_array[1]);
    try int_queue.append(&int_array[2]);
    try int_queue.append(&int_array[3]);
    try int_queue.append(&int_array[4]);
    const first = int_queue.get();
    try testing.expect(first.?.* == 1);
    const result = int_queue.removeFront();
    try testing.expect(result);
    const second = int_queue.popFront() orelse 0;
    try testing.expect(second == 2);
    const third = int_queue.get();
    try testing.expect(third.?.* == 3);
    int_queue.deinit();
}

test "LinkedList test" {
    const testing = std.testing;
    var float_list = LinkedList(f64).init(testing.allocator);
    defer float_list.deinit();
    const float_array = [5]f64{ 1.0, 2.1, 3.2, 4.3, 5.4 };
    try float_list.append(&float_array[0]);
    try float_list.append(&float_array[1]);
    try float_list.append(&float_array[2]);
    try float_list.append(&float_array[3]);
    try float_list.append(&float_array[4]);
    try testing.expect(float_list.len == 5);
    _ = float_list.getAt(4);
    const first = float_list.get();
    try testing.expect(first.?.* == 1.0);
    const result = float_list.removeFront();
    try testing.expect(result);
    const second = float_list.popFront() orelse 0.0;
    try testing.expect(second == 2.1);
    const third = float_list.get();
    try testing.expect(third.?.* == 3.2);
    const fourth = float_list.getAt(1);
    try testing.expect(fourth.?.* == 4.3);
    _ = float_list.removeAt(1);
    try testing.expect(float_list.len == 2); // only 3 lefts, in the list.
}
