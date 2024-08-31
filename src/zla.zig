const std = @import("std");
const array = @import("array.zig");
const cfg = @import("config.zig");

pub fn Array(dtype: type, config: cfg.ArrayConfig(dtype)) type {
    return array.ArrayInternal(dtype, cfg.ArrayConfigInternal(dtype).init(config));
}

test "test-all" {
    _ = @import("array.zig");
    _ = @import("config.zig");
    _ = @import("index_iter.zig");
}
