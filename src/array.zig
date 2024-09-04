const array = @import("array/array.zig");
const cfg = @import("array/config.zig");

pub const Config = cfg.ArrayConfig;
pub const Error = array.Error;

pub fn Array(comptime dtype: type, comptime config: Config(dtype)) type {
    return array.ArrayInternal(dtype, cfg.ArrayConfigInternal(dtype).init(config));
}

test "array-internal" {
    _ = @import("array/array.zig");
}
