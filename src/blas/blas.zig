const array = @import("../array.zig");
const manual = @import("manual.zig");
const openblas = @import("openblas.zig");

pub fn add(comptime Array: type, self: Array, other: Array) !Array {
    return switch (Array.config.blas) {
        .manual => manual.add(Array, self, other),
        .openblas => openblas.add(Array, self, other),
    };
}

pub fn sub(comptime Array: type, self: Array, other: Array) !Array {
    return switch (Array.config.blas) {
        .manual => manual.sub(Array, self, other),
        .openblas => openblas.sub(Array, self, other),
    };
}

pub fn mul(comptime Array: type, self: Array, other: Array) !Array {
    return switch (Array.config.blas) {
        .manual => manual.mul(Array, self, other),
        .openblas => openblas.mul(Array, self, other),
    };
}

pub fn div(comptime Array: type, self: Array, other: Array) !Array {
    return switch (Array.config.blas) {
        .manual => manual.div(Array, self, other),
        .openblas => openblas.div(Array, self, other),
    };
}
