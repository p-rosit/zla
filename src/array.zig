const array = @import("array/array.zig");
pub const Config = array.Config;
pub const ConfigInternal = array.ConfigInternal;
pub const utils = array.utils;
pub const Error = array.Error;

pub fn Array(comptime dtype: type, comptime config: Config(dtype)) type {
    return array.ArrayInternal(dtype, ConfigInternal(dtype).init(config));
}

test "array-internal" {
    _ = @import("array/array.zig");
}
