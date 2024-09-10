const std = @import("std");
const assert = std.debug.assert;
const array = @import("../array.zig");
const array_internal = @import("../array/array.zig");
const array_utils = @import("../array/utils.zig");

pub fn add(comptime Array: type, self: Array, other: Array) !Array {
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.add);
}

pub fn sub(comptime Array: type, self: Array, other: Array) !Array {
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.sub);
}

pub fn mul(comptime Array: type, self: Array, other: Array) !Array {
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.mul);
}

pub fn div(comptime Array: type, self: Array, other: Array) !Array {
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.div);
}

pub inline fn operator(
    comptime dtype: type,
    comptime Array: type,
    self: Array,
    other: Array,
    comptime op: fn (dtype, dtype) callconv(.Inline) dtype,
) !Array {
    // TODO: can be optimized with single for loop if arrays are compatible
    const shape = try array_utils.get_broadcast_shape(Array.config.dim, self.shape, other.shape);
    const result = try Array.init(self.allocator, shape);

    const a1 = self.broadcastToShape(shape) catch @panic("Unreachable");
    const a2 = other.broadcastToShape(shape) catch @panic("Unreachable");

    var linear_index: usize = 0;
    var iter = Array.Iter.init(shape);
    while (iter.next()) |index| {
        const v1 = a1.get(index) catch @panic("Unreachable");
        const v2 = a2.get(index) catch @panic("Unreachable");

        result.data[linear_index] = op(v1, v2);

        linear_index += 1;
    }

    return result;
}

pub fn matMul(comptime Array: type, self: Array, other: Array) !Array {
    if (Array.config.dim < 2) {
        @compileError("Array dimension must be 2 or more to matrix multiply");
    }

    const size = Array.config.dim;
    const arithmetic = Array.config.arithmetic;
    const Iter = array_utils.IndexIter(size - 2);

    var shape: [size]usize = undefined;
    var self_shape: [size]usize = undefined;
    var other_shape: [size]usize = undefined;

    try get_matmul_shapes(Array, self, other, &shape, &self_shape, &other_shape);

    const a1 = self.broadcastToShape(self_shape) catch unreachable;
    const a2 = other.broadcastToShape(other_shape) catch unreachable;
    const result = try Array.init(self.allocator, shape);

    const m = shape[size - 2];
    const n = shape[size - 1];
    const k = self.shape[size - 1];

    var partial_shape: [size - 2]usize = undefined;
    @memcpy(&partial_shape, shape[0 .. size - 2]);
    var iter = Iter.init(partial_shape);
    while (iter.next()) |index| {
        for (0..m) |i| {
            for (0..n) |j| {
                var result_index: [size]usize = undefined;
                var self_index: [size]usize = undefined;
                var other_index: [size]usize = undefined;
                @memcpy(result_index[0 .. size - 2], &index);
                @memcpy(self_index[0 .. size - 2], &index);
                @memcpy(other_index[0 .. size - 2], &index);
                self_index[size - 2] = i;
                other_index[size - 1] = j;
                result_index[size - 2] = i;
                result_index[size - 1] = j;

                var temp = Array.config.zero;
                for (0..k) |idx| {
                    self_index[size - 1] = idx;
                    other_index[size - 2] = idx;

                    temp = arithmetic.add(
                        temp,
                        arithmetic.mul(
                            a1.get(self_index) catch unreachable,
                            a2.get(other_index) catch unreachable,
                        ),
                    );
                }

                result.set(result_index, temp) catch unreachable;
            }
        }
    }

    return result;
}

fn get_matmul_shapes(Array: type, self: Array, other: Array, shape: *[Array.config.dim]usize, self_shape: *[Array.config.dim]usize, other_shape: *[Array.config.dim]usize) !void {
    const size = Array.config.dim;

    if (self.shape[size - 1] != other.shape[size - 2]) {
        return array.Error.NotCompatibleOrBroadcastable;
    }

    var partial_self: [size - 2]usize = undefined;
    var partial_other: [size - 2]usize = undefined;
    @memcpy(&partial_self, self.shape[0 .. size - 2]);
    @memcpy(&partial_other, other.shape[0 .. size - 2]);

    const partial_broadcast = try array_utils.get_broadcast_shape(size - 2, partial_self, partial_other);
    @memcpy(shape[0 .. size - 2], &partial_broadcast);
    @memcpy(self_shape[0 .. size - 2], &partial_broadcast);
    @memcpy(other_shape[0 .. size - 2], &partial_broadcast);

    shape[size - 2] = self.shape[size - 2];
    shape[size - 1] = other.shape[size - 1];
    @memcpy(self_shape[size - 2 .. size], self.shape[size - 2 .. size]);
    @memcpy(other_shape[size - 2 .. size], other.shape[size - 2 .. size]);
}

test "matMul" {
    const Arr = array.Array(usize, .{ .dim = 1 });
    const a_lin = try Arr.init(std.testing.allocator, .{1 * 3 * 4 * 5});
    const b_lin = try Arr.init(std.testing.allocator, .{2 * 1 * 5 * 6});
    defer a_lin.deinit();
    defer b_lin.deinit();

    for (0..a_lin.shape[0]) |i| try a_lin.set(.{i}, i);
    for (0..b_lin.shape[0]) |i| try b_lin.set(.{i}, i);

    const a = try a_lin.reshape(.{ 1, 3, 4, 5 });
    const b = try b_lin.reshape(.{ 2, 1, 5, 6 });
    defer a.deinit();
    defer b.deinit();

    const res = try a.matMul(b);
    defer res.deinit();

    assert(res.shape.len == 4);
    assert(res.shape[0] == 2);
    assert(res.shape[1] == 3);
    assert(res.shape[2] == 4);
    assert(res.shape[3] == 6);
}
