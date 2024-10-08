const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const math = std.math;
const Allocator = std.mem.Allocator;
const blas = @import("../blas.zig");

pub const utils = @import("utils.zig");
pub const Error = utils.Error;
pub const Config = @import("config.zig").Config;
pub const ConfigInternal = @import("config.zig").ConfigInternal;

pub const ElementOrder = enum {
    row_major,
    column_major,
    neither,
};

pub fn ArrayInternal(comptime dtype: type, comptime array_config: ConfigInternal(dtype)) type {
    return struct {
        const Self = @This();
        pub const config = array_config;

        owned: bool,
        allocator: Allocator,
        shape: [config.dim]usize,
        stride: [config.dim]usize,
        data: []dtype,

        pub const Iter = utils.IndexIter(config.dim);

        pub fn init(allocator: Allocator, shape: [config.dim]usize) !Self {
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
            const copy = try Self.init(self.allocator, self.shape);
            var linear_index: usize = 0;
            var iter = Self.Iter.init(self.shape);

            while (iter.next()) |index| : (linear_index += 1) {
                copy.data[linear_index] = self.get(index) catch {
                    @panic("Unreachable error: index out of bounds");
                };
            }

            return copy;
        }

        pub fn view(self: Self, slices: [config.dim]utils.Slice) !Self {
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

            const linear_index = self.getLinearIndex(min_index) catch {
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

        pub fn debugPrint(self: Self) void {
            print("Array[{}](shape={any}, stride={any})\n", .{ config.dtype, self.shape, self.stride });

            for (0..config.dim) |_| print("[", .{});

            var increments: usize = 0;
            var index: [config.dim]usize = undefined;
            @memset(&index, 0);
            while (true) {
                const linear_index = self.getLinearIndex(index) catch unreachable;

                print("{}", .{self.data[linear_index]});

                var loop_break = false;
                increments = 0;
                for (0..index.len) |i| {
                    const reversed = index.len - i - 1;
                    index[reversed] += 1;

                    if (index[reversed] < self.shape[reversed]) {
                        loop_break = true;
                        break;
                    }

                    increments += 1;
                    index[reversed] = 0;
                }

                if (increments == 0) print(", ", .{});

                for (0..increments) |_| print("]", .{});
                if (!loop_break) break;
                if (increments > 0) {
                    print("\n", .{});
                    if (increments > 1) print("\n", .{});
                    for (0..config.dim - increments) |_| print(" ", .{});
                    for (0..increments) |_| print("[", .{});
                }
            }
            print("\n", .{});
        }

        pub fn set(self: Self, index: [config.dim]usize, value: dtype) !void {
            const linear_index = try self.getLinearIndex(index);
            self.data[linear_index] = value;
        }

        pub fn get(self: Self, index: [config.dim]usize) !dtype {
            const linear_index = try self.getLinearIndex(index);
            return self.data[linear_index];
        }

        fn getLinearIndex(self: Self, index: [config.dim]usize) !usize {
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
            return blas.add(Self, self, other);
        }

        pub fn sub(self: Self, other: Self) !Self {
            return blas.sub(Self, self, other);
        }

        pub fn mul(self: Self, other: Self) !Self {
            return blas.mul(Self, self, other);
        }

        pub fn div(self: Self, other: Self) !Self {
            return blas.div(Self, self, other);
        }

        pub fn matMul(self: Self, other: Self) !Self {
            return blas.matMul(Self, self, other);
        }

        pub fn broadcastToShape(self: Self, shape: [config.dim]usize) !Self {
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

        pub fn reshape(self: Self, reshape_struct: anytype) !ArrayReshape(reshape_struct, config) {
            // TODO: can be heavily optimized if data is contiguous
            const ReshapeArray = ArrayReshape(reshape_struct, config);
            const info = utils.get_reshape_info(reshape_struct);

            var shape: [ReshapeArray.config.dim]usize = undefined;
            inline for (0.., info.fields) |i, field| {
                shape[i] = @field(reshape_struct, field.name);
            }

            const self_total = utils.get_total_size(&self.shape) catch unreachable;
            const new_total = try utils.get_total_size(&shape);

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

        pub fn elementOrder(self: Self) ElementOrder {
            if (Self.config.dim == 1) {
                return .neither;
            }

            const shape = self.shape;
            const stride = self.stride;

            if (stride[stride.len - 1] == 1) {
                if (stride[stride.len - 2] == shape[shape.len - 1]) {
                    return .column_major;
                }
            } else if (self.stride[self.stride.len - 2] == 1) {
                if (stride[stride.len - 1] == shape[shape.len - 2]) {
                    return .row_major;
                }
            }

            return .row_major;
        }

        pub fn isBlasable(self: Self) bool {
            return self.elementOrder() != .neither;
        }

        pub fn elementWiseCompatible(self: Self, other: Self) bool {
            var result = true;
            for (self.shape, self.stride, other.shape, other.stride) |d1, s1, d2, s2| {
                result = result and (d1 == d2) and (s1 == s2);
            }
            return result;
        }
    };
}

fn ArrayReshape(reshape_struct: anytype, config: anytype) type {
    const info = utils.get_reshape_info(reshape_struct);
    var copy_config = config;
    copy_config.dim = info.fields.len;
    return ArrayInternal(config.dtype, copy_config);
}

const array_type = @import("../array.zig");

fn TestArray(dtype: type, dim: usize) type {
    switch (dtype) {
        i8, f64 => return array_type.Array(dtype, .{ .dim = dim }),
        else => @compileError("Oops"),
    }
}

test "init" {
    const size: usize = 2;
    const arr = try TestArray(f64, size).init(std.testing.allocator, .{ 2, 3 });
    defer arr.deinit();

    assert(arr.owned == true);
    assert(arr.data.len == 6);

    assert(arr.shape.len == size);
    assert(arr.shape[0] == 2);
    assert(arr.shape[1] == 3);

    assert(arr.stride.len == size);
    assert(arr.stride[0] == 3);
    assert(arr.stride[1] == 1);
}

test "zeros" {
    const size: usize = 3;
    const arr = try TestArray(i8, size).zeros(std.testing.allocator, .{ 2, 4, 5 });
    defer arr.deinit();

    for (arr.data) |value| {
        assert(value == 0);
    }
}

test "clone" {
    const arr = try TestArray(f64, 2).zeros(std.testing.allocator, .{ 10, 9 });
    defer arr.deinit();

    const cloned = try arr.clone();
    defer cloned.deinit();

    assert(cloned.owned == true);

    assert(cloned.shape.len == 2);
    assert(cloned.shape[0] == 10);
    assert(cloned.shape[1] == 9);

    assert(cloned.stride.len == 2);
    assert(cloned.stride[0] == 9);
    assert(cloned.stride[1] == 1);
}

test "view" {
    const size: usize = 2;
    const arr = try TestArray(f64, size).init(std.testing.allocator, .{ 10, 8 });
    defer arr.deinit();

    const view = try arr.view(.{
        .{ .lo = 1, .hi = 9 },
        .{ .hi = 7, .st = 2 },
    });

    assert(view.owned == false);

    assert(view.shape[0] == 8);
    assert(view.shape[1] == 4);

    assert(view.stride[0] == 8);
    assert(view.stride[1] == 2);

    const view_view = try view.view(.{
        .{ .lo = 0, .hi = 8, .st = 3 },
        .{ .hi = 3 },
    });

    assert(view_view.owned == false);

    assert(view_view.shape[0] == 3);
    assert(view_view.shape[1] == 3);

    assert(view_view.stride[0] == 24);
    assert(view_view.stride[1] == 2);
}

test "permute" {
    var arr = try TestArray(f64, 4).init(std.testing.allocator, .{ 3, 4, 5, 6 });
    defer arr.deinit();

    try arr.permute(.{ 0, 2, 3, 1 });

    assert(arr.shape[0] == 3);
    assert(arr.shape[1] == 5);
    assert(arr.shape[2] == 6);
    assert(arr.shape[3] == 4);

    assert(arr.stride[0] == 4 * 5 * 6);
    assert(arr.stride[1] == 6);
    assert(arr.stride[2] == 1);
    assert(arr.stride[3] == 5 * 6);

    try std.testing.expectError(
        Error.MissingIndex,
        arr.permute(.{ 0, 2, 3, 0 }),
    );
}

test "transpose" {
    var arr = try TestArray(f64, 4).init(std.testing.allocator, .{ 2, 3, 4, 5 });
    defer arr.deinit();

    try arr.transpose(0, 2);

    assert(arr.shape[0] == 4);
    assert(arr.shape[1] == 3);
    assert(arr.shape[2] == 2);
    assert(arr.shape[3] == 5);

    assert(arr.stride[0] == 5);
    assert(arr.stride[1] == 5 * 4);
    assert(arr.stride[2] == 5 * 4 * 3);
    assert(arr.stride[3] == 1);
}

test "set-get" {
    const arr = try TestArray(f64, 2).zeros(std.testing.allocator, .{ 2, 3 });
    defer arr.deinit();

    const index = [2]usize{ 1, 2 };
    const v1 = try arr.get(index);

    assert(v1 == 0);

    try arr.set(index, 5);
    const v2 = try arr.get(index);
    assert(v2 == 5);
}

test "reshape" {
    const arr = try TestArray(f64, 2).zeros(std.testing.allocator, .{ 3, 4 });
    defer arr.deinit();

    const res = try arr.reshape(.{ 2, 3, 2 });
    defer res.deinit();

    assert(res.shape.len == 3);
    assert(res.shape[0] == 2);
    assert(res.shape[1] == 3);
    assert(res.shape[2] == 2);

    try std.testing.expectError(
        Error.NotCompatibleOrBroadcastable,
        arr.reshape(.{ 2, 4, 2 }),
    );
}

test "array-internal" {
    _ = @import("config.zig");
    _ = @import("utils.zig");
}
