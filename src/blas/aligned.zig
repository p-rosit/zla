const std = @import("std");
const assert = std.debug.assert;

pub fn add(comptime Array: type, self: Array, other: Array) !Array {
    assert(self.elementWiseCompatible(other));
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.add);
}

pub fn sub(comptime Array: type, self: Array, other: Array) !Array {
    assert(self.elementWiseCompatible(other));
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.sub);
}

pub fn mul(comptime Array: type, self: Array, other: Array) !Array {
    assert(self.elementWiseCompatible(other));
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.mul);
}

pub fn div(comptime Array: type, self: Array, other: Array) !Array {
    assert(self.elementWiseCompatible(other));
    return operator(Array.config.dtype, Array, self, other, Array.config.arithmetic.div);
}

inline fn operator(
    comptime dtype: type,
    comptime Array: type,
    self: Array,
    other: Array,
    comptime op: fn (dtype, dtype) callconv(.Inline) dtype,
) !Array {
    const result = try Array.init(self.allocator, self.shape);

    for (0.., self.data, other.data) |i, v1, v2| {
        result.data[i] = op(v1, v2);
    }

    return result;
}
