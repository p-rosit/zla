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

                pub fn get_zero(self: Self) dtype {
                    _ = self;
                    return 0;
                }
            };
        },
        else => blk: {
            break :blk struct {
                const Self = @This();

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
        zero: dtype,

        pub fn init(config: ArrayConfig(dtype)) Self {
            return Self{
                .dtype = dtype,
                .zero = config.get_zero(),
            };
        }
    };
}

pub fn Array(comptime dtype: type, comptime config: ArrayConfig(dtype)) type {
    const config_internal = ArrayConfigInternal(dtype).init(config);

    return struct {
        const Self = @This();
        const array_config = config_internal;

        owned: bool,
        allocator: Allocator,
        shape: []usize,
        stride: []usize,
        data: []dtype,

        fn internal_init(allocator: Allocator, shape: []usize) !Self {
            const stride = try allocator.alloc(usize, shape.len);

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

        pub fn init(allocator: Allocator, shape_struct: anytype) !Self {
            const shape_info = shape_verify(shape_struct);
            const shape = try shape_extract(allocator, shape_info, shape_struct);
            return Self.internal_init(allocator, shape);
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.shape);
            self.allocator.free(self.stride);
            if (self.owned) {
                self.allocator.free(self.data);
            }
        }

        pub fn zeros(allocator: Allocator, shape_struct: anytype) !Self {
            const array = try Self.init(allocator, shape_struct);
            @memset(array.data, array_config.zero);
            return array;
        }

        pub fn set(self: Self, index_struct: anytype, value: dtype) !void {
            const info = index_verify(index_struct);
            const index = index_extract(info, index_struct);

            if (index.len != self.stride.len) {
                return error.IndexError;
            }

            var value_index: usize = 0;
            for (index, self.stride, self.shape) |i, stride, dim| {
                if (i >= dim) {
                    return error.IndexOutOfBounds;
                }
                value_index += i * stride;
            }

            self.data[value_index] = value;
        }

        pub fn get(self: Self, index_struct: anytype) !dtype {
            const info = index_verify(index_struct);
            const index = index_extract(info, index_struct);

            if (index.len != self.stride.len) {
                return error.IndexError;
            }

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
