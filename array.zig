const print = @import("std").debug.print;
const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Struct = std.builtin.Type.Struct;

fn ArrayConfig(dtype: type) type {
    const type_info = @typeInfo(dtype);
    return switch (type_info) {
        .Int, .ComptimeInt, .Float, .ComptimeFloat => blk: {
            break :blk struct {
                const Self = @This();

                dim: usize,

                pub fn get_zero(self: Self) dtype {
                    _ = self;
                    return 0;
                }
            };
        },
        else => blk: {
            break :blk struct {
                const Self = @This();

                dim: usize,
                zero: dtype,

                pub fn get_zero(self: Self) dtype {
                    return self.zero;
                }
            };
        },
    };
}

fn ArrayConfigInternal(dtype: type) type {
    return struct {
        const Self = @This();

        dtype: type,
        dim: usize,
        zero: dtype,

        pub fn init(config: ArrayConfig(dtype)) Self {
            return Self{
                .dtype = dtype,
                .dim = config.dim,
                .zero = config.get_zero(),
            };
        }
    };
}

pub fn Array(comptime dtype: type, comptime array_config: ArrayConfig(dtype)) type {
    return struct {
        const Self = @This();
        const config = ArrayConfigInternal(dtype).init(array_config);

        owned: bool,
        allocator: Allocator,
        shape: [config.dim]usize,
        stride: [config.dim]usize,
        data: []dtype,

        fn init(allocator: Allocator, shape: [config.dim]usize) !Self {
            var stride: [config.dim]usize = undefined;

            var total: usize = 1;
            for (0..shape.len) |i| {
                const dim = shape[shape.len - i - 1];
                stride[shape.len - i - 1] = total;

                if (math.maxInt(usize) / dim < total) {
                    return error.Overflow;
                }
                total *= dim;
            }

            const data = try allocator.alloc(dtype, total);

            return Self{
                .owned = true,
                .allocator = allocator,
                .shape = shape,
                .stride = stride,
                .data = data,
            };
        }

        pub fn deinit(self: Self) void {
            if (self.owned) {
                self.allocator.free(self.data);
            }
        }

        pub fn zeros(allocator: Allocator, shape: [config.dim]usize) !Self {
            const array = try Self.init(allocator, shape);
            @memset(array.data, config.zero);
            return array;
        }

        pub fn set(self: Self, index: [config.dim]usize, value: dtype) !void {
            var value_index: usize = 0;
            for (index, self.stride, self.shape) |i, stride, dim| {
                if (i >= dim) {
                    return error.IndexOutOfBounds;
                }
                value_index += i * stride;
            }

            self.data[value_index] = value;
        }

        pub fn get(self: Self, index: [config.dim]usize) !dtype {
            var value_index: usize = 0;
            for (index, self.stride, self.shape) |i, stride, dim| {
                if (i >= dim) {
                    return error.IndexOutOfBounds;
                }
                value_index += i * stride;
            }

            return self.data[value_index];
        }
    };
}

fn index_verify(index_struct: anytype) Struct {
    const T = @TypeOf(index_struct);
    const type_info = @typeInfo(T);

    if (type_info != .Struct) {
        @compileError("Index must be anonymous struct");
    }

    const struct_info = type_info.Struct;
    inline for (struct_info.fields) |field| {
        // TODO: verify types
        _ = field;
    }

    return struct_info;
}

fn index_extract(comptime info: Struct, index_struct: anytype) [info.fields.len]usize {
    var index: [info.fields.len]usize = undefined;

    inline for (0..info.fields.len, info.fields) |i, field| {
        index[i] = @field(index_struct, field.name);
    }

    return index;
}

fn shape_verify(comptime shape_struct: anytype) Struct {
    const T = @TypeOf(shape_struct);
    const type_info = @typeInfo(T);

    if (type_info != .Struct) {
        @compileError("Shape must be anonymous struct");
    }

    const struct_info = type_info.Struct;
    inline for (struct_info.fields) |field| {
        // TODO: verify types
        _ = field;
    }

    return struct_info;
}

fn shape_extract(allocator: Allocator, comptime info: Struct, comptime shape_struct: anytype) ![]usize {
    var shape = try allocator.alloc(usize, info.fields.len);

    inline for (0..info.fields.len, info.fields) |i, field| {
        shape[i] = @field(shape_struct, field.name);
    }

    return shape;
}
