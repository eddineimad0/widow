const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        pub const Node = std.TailQueue(T).Node;
        pub const Self = @This();

        head: ?*Node,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = null,
                .allocator = allocator,
            };
        }

        /// Empties the queue, and releases all alocated memory.
        pub fn deinit(self: *Self) void {
            var current = self.head orelse return;
            var prev: *Node = undefined;
            while (current.next) |next| {
                prev = current;
                self.allocator.destroy(prev);
                current = next;
            }
            self.allocator.destroy(current);
            self.head = null;
        }

        /// Appends `item` to the queue.
        pub fn put(self: *Self, item: *const T) !void {
            var node = try self.allocator.create(Node);
            node.next = null;
            node.data = item.*;
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

        /// Gets the first item in the queue or returns `null` if there is none.
        pub fn get(self: *Self) ?*T {
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
            _ = self.remove_front();
            return item;
        }
    };
}

test "Queue tests" {
    const testing = std.testing;
    var int_queue = Queue(u32).init(testing.allocator);
    const int_array = [5]u32{ 1, 2, 3, 4, 5 };
    try int_queue.put(&int_array[0]);
    try int_queue.put(&int_array[1]);
    try int_queue.put(&int_array[2]);
    try int_queue.put(&int_array[3]);
    try int_queue.put(&int_array[4]);
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
