const std = @import("std");
const array = @import("array/array.zig");

pub fn Array(dtype: type, config: array.Config(dtype)) type {
    return array.Array(dtype, config);
}

test "make type" {
    _ = Array(f64, .{ .dim = 3 });
}
