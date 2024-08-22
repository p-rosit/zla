const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;

pub const Error = error{
    Overflow,
};

pub fn Array(dtype: type) type {
    return struct {
        const Self = @This();

        data: []dtype,

        pub fn zeros(allocator: Allocator, shape: []const usize) !Self {
            _ = allocator;

            const total = try total_size(shape);
            print("Total size: {}\n", .{total});

            var data = try allocator.alloc();

            return Self{};
        }
    };
}

fn total_size(shape: []const usize) !usize {
    var total: usize = 1;
    for (shape) |dim| {
        total *= dim;
    }

    if (total > 100_000) {
        return Error.Overflow;
    }

    return total;
}
