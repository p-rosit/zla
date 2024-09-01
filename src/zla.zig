const std = @import("std");
const array = @import("array.zig");
const cfg = @import("config.zig");

pub fn Array(dtype: type, config: cfg.ArrayConfig(dtype)) type {
    return array.Array(dtype, config);
}

test "make type" {
    _ = Array(f64, .{.dim=3});
}

test "test-internal" {
    _ = @import("array.zig");
    _ = @import("config.zig");
    _ = @import("index_iter.zig");
}
