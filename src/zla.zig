const std = @import("std");

pub fn Zla(T: type, dimension: comptime_int) type {
    return struct {
        const Self = @This();
        shape: [dimension]?usize,
        stride: [dimension]usize,
        start_index: usize,
        linear_array: []T,

        pub fn init(allocator: std.mem.Allocator, shape: [dimension]?usize) !Self {
            var stride: [dimension]usize = undefined;

            var total_size: usize = 1;
            for (0..shape.len) |i| {
                stride[shape.len - i - 1] = total_size;
                total_size = std.math.mul(
                    usize,
                    total_size,
                    shape[shape.len - i - 1] orelse 1,
                ) catch return error.OutOfMemory;
            }
            const arr = try allocator.alloc(T, total_size);

            return .{
                .shape = shape,
                .stride = stride,
                .start_index = 0,
                .linear_array = arr,
            };
        }

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.linear_array);
        }

        pub fn get(self: Self, index: [dimension]usize) *T {
            var linear_index: usize = 0;
            for (self.shape, self.stride, index) |shape, stride, idx| {
                if (shape) |s| if (idx >= s) @panic("Index out of bounds");
                linear_index += stride * idx;
            }
            return &self.linear_array[linear_index];
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

test "get index" {
    var data: [6]i32 = .{ 0, 0, 0, 0, 0, 0 };
    var fba = std.heap.FixedBufferAllocator.init(@ptrCast(&data));

    const a: Zla(i32, 2) = try .init(fba.allocator(), .{ 2, 3 });
    @memset(&data, 0); // allocator initializes data with "garbage"
    defer a.deinit(fba.allocator());

    // Before
    // 0 0 0
    // 0 0 0
    a.get(.{ 1, 0 }).* = 1;
    a.get(.{ 0, 1 }).* = 2;
    // After
    // 0 2 0
    // 1 0 0

    try std.testing.expectEqualSlices(i32, &.{ 0, 2, 0, 1, 0, 0 }, &data);
}
