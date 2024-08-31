const assert = @import("std").debug.assert;

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

test "numerical expects dim" {
    _ = ArrayConfig(f32){ .dim = 1 };
    _ = ArrayConfig(f64){ .dim = 1 };
    _ = ArrayConfig(f128){ .dim = 1 };
    _ = ArrayConfig(comptime_float){ .dim = 1 };

    _ = ArrayConfig(u8){ .dim = 1 };
    _ = ArrayConfig(i8){ .dim = 1 };
    _ = ArrayConfig(u64){ .dim = 1 };
    _ = ArrayConfig(i64){ .dim = 1 };
    _ = ArrayConfig(comptime_int){ .dim = 1 };
}

test "custom expects zero" {
    const Data = struct {
        a: i8,
        b: i8,
    };

    _ = ArrayConfig(Data){
        .dim = 2,
        .zero = Data{ .a = 0, .b = 0 },
    };
}

test "internal from external" {
    const config = ArrayConfig(f64){ .dim = 3 };
    const internal = ArrayConfigInternal(f64).init(config);

    assert(internal.dtype == f64);
    assert(internal.dim == 3);
    assert(internal.zero == 0.0);
}
