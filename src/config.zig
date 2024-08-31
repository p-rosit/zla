const assert = @import("std").debug.assert;

pub fn ArrayConfig(dtype: type) type {
    const type_info = @typeInfo(dtype);
    return switch (type_info) {
        .Int, .ComptimeInt, .Float, .ComptimeFloat => blk: {
            break :blk struct {
                const Self = @This();

                blas: BlasType = .manual,
                dim: usize,

                pub inline fn add(self: Self, a: dtype, b: dtype) dtype {
                    _ = self;
                    return a + b;
                }

                pub inline fn sub(self: Self, a: dtype, b: dtype) dtype {
                    _ = self;
                    return a - b;
                }

                pub fn get_blas(self: Self) BlasType {
                    return self.blas;
                }

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
                add: fn (dtype, dtype) callconv(.Inline) dtype,
                sub: fn (dtype, dtype) callconv(.Inline) dtype,

                pub inline fn add(self: Self, a: dtype, b: dtype) dtype {
                    return self.add(a, b);
                }

                pub inline fn sub(self: Self, a: dtype, b: dtype) dtype {
                    return self.sub(a, b);
                }

                pub fn get_blas(self: Self) BlasType {
                    _ = self;
                    return .manual;
                }

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

        blas: BlasType,
        dtype: type,
        dim: usize,
        zero: dtype,
        arithmetic: type,

        pub fn init(config: ArrayConfig(dtype)) Self {
            const Temp = struct {
                pub inline fn add(a: dtype, b: dtype) dtype {
                    return config.add(a, b);
                }

                pub inline fn sub(a: dtype, b: dtype) dtype {
                    return config.sub(a, b);
                }
            };

            return Self{
                .blas = config.get_blas(),
                .dtype = dtype,
                .dim = config.dim,
                .zero = config.get_zero(),
                .arithmetic = Temp,
            };
        }
    };
}

const BlasType = enum {
    manual,
    openblas,
};

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

const Data = struct {
    a: i8,
    b: i8,

    pub inline fn add(self: Data, other: Data) Data {
        return Data{
            .a = self.a + other.a,
            .b = self.b + other.b,
        };
    }
    pub inline fn sub(self: Data, other: Data) Data {
        return Data{
            .a = self.a - other.a,
            .b = self.b - other.b,
        };
    }
};

test "custom type expects zero" {
    _ = ArrayConfig(Data){
        .dim = 2,
        .zero = Data{ .a = 0, .b = 0 },
        .add = Data.add,
        .sub = Data.sub,
    };
}

test "internal from external" {
    const config = ArrayConfig(f64){ .dim = 3 };
    const internal = ArrayConfigInternal(f64).init(config);

    assert(internal.blas == .manual);
    assert(internal.dtype == f64);
    assert(internal.dim == 3);
    assert(internal.zero == 0.0);
}
