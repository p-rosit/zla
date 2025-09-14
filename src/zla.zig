const std = @import("std");

pub fn Zla(T: type, dimension: comptime_int) type {
    return struct {
        const Self = @This();
        shape: [dimension]?usize,
        start_index: usize,
        linear_array: []T,

        pub fn init(allocator: std.mem.Allocator, shape: [dimension]?usize) !Self {
            var total_size: usize = 1;
            for (shape) |s| {
                total_size = std.math.mul(usize, total_size, s orelse 1) catch return error.OutOfMemory;
            }
            const arr = try allocator.alloc(T, total_size);
            return .{
                .shape = shape,
                .start_index = 0,
                .linear_array = arr,
            };
        }

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.linear_array);
        }
    };
}

test "just make type" {
    _ = Zla(i32, 1);
    _ = Zla(f32, 2);
    _ = Zla(struct { a: u8, b: u8 }, 2);
}

test "init and deinit" {
    const a: Zla(i32, 1) = try .init(std.testing.allocator, .{2});
    a.deinit(std.testing.allocator);
}
