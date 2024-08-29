pub fn ArrayConfig(dtype: type) type {
    const type_info = @typeInfo(dtype);
    return switch (type_info) {
        .Int, .ComptimeInt, .Float, .ComptimeFloat => blk: {
            break :blk struct {
                const Self = @This();

                dim: usize,

                pub fn get_zero(self: Self) dtype {
                    _ = self;
                    return 0;
                }
            };
        },
        else => blk: {
            break :blk struct {
                const Self = @This();

                dim: usize,
                zero: dtype,

                pub fn get_zero(self: Self) dtype {
                    return self.zero;
                }
            };
        },
    };
}

pub fn ArrayConfigInternal(dtype: type) type {
    return struct {
        const Self = @This();

        dtype: type,
        dim: usize,
        zero: dtype,

        pub fn init(config: ArrayConfig(dtype)) Self {
            return Self{
                .dtype = dtype,
                .dim = config.dim,
                .zero = config.get_zero(),
            };
        }
    };
}
