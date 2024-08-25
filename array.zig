const print = @import("std").debug.print;
const Allocator = @import("std").mem.Allocator;
const Struct = @import("std").builtin.Type.Struct;


pub fn Array(
    dtype: type,
    comptime config: struct {
        zero: ?(fn () dtype) = null,
    },
) type {
    const type_info = @typeInfo(dtype);
    const zero_func: fn () dtype = switch (type_info) {
        .Int, .ComptimeInt, .Float, .ComptimeFloat => numeric_zero(dtype),
        else => if (config.zero == null) @compileError("Missing zero") else config.zero.?,
    };

    return struct {
        const Self = @This();

        allocator: Allocator,
        data: []dtype,

        fn zero() dtype {
            return zero_func();
        }

        pub fn zeros(allocator: Allocator, shape_struct: anytype) !Self {
            const info = shape_verify(shape_struct);
            const shape = shape_extract(info, shape_struct);

            const total = try total_size(&shape);

            const data = try allocator.alloc(dtype, total);
            for (data) |*value| {
                value.* = Self.zero();
            }

            return Self{ .allocator = allocator, .data = data };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.data);
        }
    };
}

fn shape_verify(shape_struct: anytype) Struct {
    const T = @TypeOf(shape_struct);
    const type_info = @typeInfo(T);

    if (type_info != .Struct) {
        @compileError("Shape must be anonymous struct");
    }

    const struct_info = type_info.Struct;
    inline for (struct_info.fields) |field| {
        _ = field;
    }

    return struct_info;
}

fn shape_extract(info: Struct, shape_struct: anytype) [info.fields.len]usize {
    var shape: [info.fields.len]usize = undefined;

    inline for (0..info.fields.len, info.fields) |i, field| {
        shape[i] = @field(shape_struct, field.name);
    }

    return shape;
}

fn total_size(shape: []const usize) !usize {
    var total: usize = 1;
    for (shape) |dim| {
        total *= dim;
    }

    if (total > 100_000) {
        return error.Overflow;
    }

    return total;
}

fn numeric_zero(dtype: type) (fn () dtype) {
    const numeric = struct {
        pub fn zero() dtype {
            return 0;
        }
    };

    return numeric.zero;
}
