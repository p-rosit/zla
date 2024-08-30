const print = @import("std").debug.print;
const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Struct = std.builtin.Type.Struct;
const cfg = @import("config.zig");
const idx = @import("index_iter.zig");

pub const Error = error{
    Overflow,
    OutOfBounds,
    MissingIndex,
    NotCompatibleOrBroadcastable,
};

pub fn Array(comptime dtype: type, comptime config: cfg.ArrayConfig(dtype)) type {
    return ArrayInternal(dtype, cfg.ArrayConfigInternal(dtype).init(config));
}

pub fn ArrayInternal(comptime dtype: type, comptime array_config: cfg.ArrayConfigInternal(dtype)) type {
    return struct {
        const Self = @This();
        const config = array_config;

        owned: bool,
        allocator: Allocator,
        shape: [config.dim]usize,
        stride: [config.dim]usize,
        data: []dtype,

        const Iter = idx.IndexIter(config.dim);

        fn init(allocator: Allocator, shape: [config.dim]usize) !Self {
            var stride: [config.dim]usize = undefined;

            var total: usize = 1;
            for (0..shape.len) |i| {
                const dim = shape[shape.len - i - 1];
                stride[shape.len - i - 1] = total;

                if (math.maxInt(usize) / dim < total) {
                    return Error.Overflow;
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

        pub fn clone(self: Self) !Self {
            const copy = try Self.zeros(self.allocator, self.shape);
            var linear_index: usize = 0;
            var iter = Self.Iter.init(self.shape);

            while (iter.next()) |index| : (linear_index += 1) {
                copy.data[linear_index] = self.get(index) catch {
                    @panic("Unreachable error: index out of bounds");
                };
            }

            return copy;
        }

        pub fn view(self: Self, slices: [config.dim]Slice) !Self {
            var min_index: [config.dim]usize = undefined;
            var shape: [config.dim]usize = undefined;
            var stride: [config.dim]usize = undefined;

            for (0.., slices) |i, slice| {
                if (self.shape[i] < slice.lo and self.shape[i] < slice.hi) {
                    return Error.OutOfBounds;
                }

                min_index[i] = slice.lo;
                shape[i] = slice.size();
                stride[i] = self.stride[i] * slice.st;
            }

            const linear_index = self.get_linear_index(min_index) catch {
                @panic("Unreachable error: index out of bounds");
            };

            return Self{
                .owned = false,
                .allocator = self.allocator,
                .shape = shape,
                .stride = stride,
                .data = self.data[linear_index..],
            };
        }

        pub fn permute(self: *Self, permutation: [config.dim]usize) !void {
            var index_exists: [config.dim]bool = undefined;
            @memset(&index_exists, false);

            for (permutation) |i| {
                if (!(i < config.dim)) return Error.OutOfBounds;
                index_exists[i] = true;
            }

            var all_exist = true;
            for (index_exists) |exists| {
                all_exist = all_exist and exists;
            }

            if (!all_exist) return Error.MissingIndex;

            const shape = self.shape;
            const stride = self.stride;
            for (0.., permutation) |destination, source| {
                self.shape[destination] = shape[source];
                self.stride[destination] = stride[source];
            }
        }

        pub fn transpose(self: *Self, index1: usize, index2: usize) !void {
            if (!(index1 < config.dim and index2 < config.dim)) {
                return Error.OutOfBounds;
            }

            const shape = self.shape[index1];
            self.shape[index1] = self.shape[index2];
            self.shape[index2] = shape;

            const stride = self.stride[index1];
            self.stride[index1] = self.stride[index2];
            self.stride[index2] = stride;
        }

        pub fn set(self: Self, index: [config.dim]usize, value: dtype) !void {
            const linear_index = try self.get_linear_index(index);
            self.data[linear_index] = value;
        }

        pub fn get(self: Self, index: [config.dim]usize) !dtype {
            const linear_index = try self.get_linear_index(index);
            return self.data[linear_index];
        }

        fn get_linear_index(self: Self, index: [config.dim]usize) !usize {
            var linear_index: usize = 0;
            for (index, self.stride, self.shape) |i, stride, dim| {
                if (i >= dim) {
                    return Error.OutOfBounds;
                }
                linear_index += i * stride;
            }

            return linear_index;
        }

        pub fn add(self: Self, other: Self) !Self {
            const shape = try self.get_broadcast_shape(other);
            const result = try Self.init(self.allocator, shape);

            const a1 = self.broadcast_to_shape(shape) catch @panic("Unreachable");
            const a2 = other.broadcast_to_shape(shape) catch @panic("Unreachable");

            var linear_index: usize = 0;
            var iter = Self.Iter.init(shape);
            while (iter.next()) |index| {
                const v1 = a1.get(index) catch @panic("Unreachable");
                const v2 = a2.get(index) catch @panic("Unreachable");

                result.data[linear_index] = v1 + v2;

                linear_index += 1;
            }

            return result;
        }

        pub fn broadcast_to_shape(self: Self, shape: [config.dim]usize) !Self {
            var brd = self;

            for (&brd.shape, &brd.stride, shape) |*brd_dim, *brd_stride, dim| {
                if (brd_dim.* == 1) {
                    brd_dim.* = dim;
                    brd_stride.* = 0;
                } else if (brd_dim.* != dim) {
                    return Error.NotCompatibleOrBroadcastable;
                }
            }

            return brd;
        }

        pub fn get_broadcast_shape(self: Self, other: Self) ![config.dim]usize {
            var shape: [config.dim]usize = undefined;

            for (0.., self.shape, other.shape) |i, shape1, shape2| {
                if (shape1 != shape2 and shape1 != 1 and shape2 != 1) {
                    return Error.NotCompatibleOrBroadcastable;
                }
                shape[i] = @max(shape1, shape2);
            }

            return shape;
        }

        pub fn reshape(self: Self, reshape_struct: anytype) !ArrayReshape(reshape_struct, config) {
            // TODO: can be heavily optimized if data is contiguous
            const ReshapeArray = ArrayReshape(reshape_struct, config);
            const info = get_reshape_info(reshape_struct);

            var shape: [ReshapeArray.config.dim]usize = undefined;
            inline for (0.., info.fields) |i, field| {
                shape[i] = @field(reshape_struct, field.name);
            }

            const self_total = self.data.len;
            const new_total = try get_total_size(&shape);

            if (self_total != new_total) {
                return Error.NotCompatibleOrBroadcastable;
            }

            var linear_index: usize = 0;
            const array = try ReshapeArray.init(self.allocator, shape);
            var iter = Self.Iter.init(self.shape);
            while (iter.next()) |index| : (linear_index += 1) {
                array.data[linear_index] = self.get(index) catch unreachable;
            }

            return array;
        }
    };
}

fn ArrayReshape(reshape_struct: anytype, config: anytype) type {
    const info = get_reshape_info(reshape_struct);
    return ArrayInternal(config.dtype, cfg.ArrayConfigInternal(config.dtype){
        .dtype = config.dtype,
        .dim = info.fields.len,
        .zero = config.zero,
    });
}

fn get_total_size(shape: []usize) !usize {
    var total: usize = 1;

    for (shape) |dim| {
        if (math.maxInt(usize) / dim < total) {
            return Error.Overflow;
        }
        total *= dim;
    }

    return total;
}

fn get_reshape_info(reshape_struct: anytype) Struct {
    const T = @TypeOf(reshape_struct);
    const type_info = @typeInfo(T);

    if (type_info != .Struct) {
        @compileError("New shape must be struct");
    }

    const struct_info = type_info.Struct;
    inline for (struct_info.fields) |field| {
        // TODO: verify index is usize or similar
        _ = field;
    }

    return struct_info;
}

pub const Slice = struct {
    lo: usize = 0,
    hi: usize,
    st: usize = 1,

    pub fn size(self: Slice) usize {
        if (self.st == 0) {
            @panic("Cannot get size of slice if stride is zero");
        }

        if (self.hi < self.lo) {
            return 0;
        } else {
            return 1 + (self.hi - self.lo - 1) / self.st;
        }
    }
};
