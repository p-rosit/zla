const assert = @import("std").debug.assert;

pub fn Config(dtype: type) type {
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

                pub inline fn mul(self: Self, a: dtype, b: dtype) dtype {
                    _ = self;
                    return a * b;
                }

                pub inline fn div(self: Self, a: dtype, b: dtype) dtype {
                    _ = self;
                    return a / b;
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
                mul: fn (dtype, dtype) callconv(.Inline) dtype,
                div: fn (dtype, dtype) callconv(.Inline) dtype,

                pub inline fn add(self: Self, a: dtype, b: dtype) dtype {
                    return self.add(a, b);
                }

                pub inline fn sub(self: Self, a: dtype, b: dtype) dtype {
                    return self.sub(a, b);
                }

                pub inline fn mul(self: Self, a: dtype, b: dtype) dtype {
                    return self.mul(a, b);
                }

                pub inline fn div(self: Self, a: dtype, b: dtype) dtype {
                    return self.div(a, b);
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

pub fn ConfigInternal(dtype: type) type {
    return struct {
        const Self = @This();

        blas: BlasType,
        dtype: type,
        dim: usize,
        zero: dtype,
        arithmetic: type,

        pub fn init(config: Config(dtype)) Self {
            const Temp = struct {
                pub inline fn add(a: dtype, b: dtype) dtype {
                    return config.add(a, b);
                }

                pub inline fn sub(a: dtype, b: dtype) dtype {
                    return config.sub(a, b);
                }

                pub inline fn mul(a: dtype, b: dtype) dtype {
                    return config.mul(a, b);
                }

                pub inline fn div(a: dtype, b: dtype) dtype {
                    return config.div(a, b);
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
    _ = Config(f32){ .dim = 1 };
    _ = Config(f64){ .dim = 1 };
    _ = Config(f128){ .dim = 1 };
    _ = Config(comptime_float){ .dim = 1 };

    _ = Config(u8){ .dim = 1 };
    _ = Config(i8){ .dim = 1 };
    _ = Config(u64){ .dim = 1 };
    _ = Config(i64){ .dim = 1 };
    _ = Config(comptime_int){ .dim = 1 };
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

    pub inline fn mul(self: Data, other: Data) Data {
        return Data{
            .a = self.a * other.a,
            .b = self.b * other.b,
        };
    }

    pub inline fn div(self: Data, other: Data) Data {
        return Data{
            .a = self.a / other.a,
            .b = self.b / other.b,
        };
    }
};

test "custom type expects zero" {
    _ = Config(Data){
        .dim = 2,
        .zero = Data{ .a = 0, .b = 0 },
        .add = Data.add,
        .sub = Data.sub,
        .mul = Data.mul,
        .div = Data.div,
    };
}

test "internal from external" {
    const config = Config(f64){ .dim = 3 };
    const internal = ConfigInternal(f64).init(config);

    assert(internal.blas == .manual);
    assert(internal.dtype == f64);
    assert(internal.dim == 3);
    assert(internal.zero == 0.0);
}
