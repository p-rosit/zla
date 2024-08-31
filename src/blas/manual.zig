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
    dtype: type,
    comptime Array: type,
    self: Array,
    other: Array,
    comptime op: fn (dtype, dtype) callconv(.Inline) dtype,
) !Array {
    // TODO: can be optimized with single for loop if arrays are compatible
    const shape = try self.get_broadcast_shape(other);
    const result = try Array.init(self.allocator, shape);

    const a1 = self.broadcast_to_shape(shape) catch @panic("Unreachable");
    const a2 = other.broadcast_to_shape(shape) catch @panic("Unreachable");

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

pub fn matmul(comptime Array: type, self: Array, other: Array) !Array {
    _ = self;
    _ = other;
    @compileError("Not implemented");

    const size = Array.config.dim;
    const arithmetic = Array.config.arithmetic;

    const shape: [size]usize = undefined;
    const m = shape[size - 2];
    const n = shape[size - 1];
    const k = self.shape[size - 1];

    while (iter.next()) |index| {
        for (0..m) |i| {
            for (0..n) |j| {
                var temp = Array.config.zero;

                for (0..k) |k| {
                    temp = arithmetic.add(
                        temp,
                        arithmetic.mul(
                            self.get(self_index) catch unreachable,
                            other.get(other_index) catch unreachable,
                        ),
                    );
                }

                result.set(result_index, temp) catch unreachable;
            }
        }
    }
}
