const array = @import("array/array.zig");
const aligned = @import("blas/aligned.zig");
const manual = @import("blas/manual.zig");
const openblas = @import("blas/openblas.zig");

pub fn add(comptime Array: type, self: Array, other: Array) !Array {
    if (self.elementWiseCompatible(other)) {
        return aligned.add(Array, self, other);
    } else {
        return manual.add(Array, self, other);
    }
}

pub fn sub(comptime Array: type, self: Array, other: Array) !Array {
    if (self.elementWiseCompatible(other)) {
        return aligned.sub(Array, self, other);
    } else {
        return manual.sub(Array, self, other);
    }
}

pub fn mul(comptime Array: type, self: Array, other: Array) !Array {
    if (self.elementWiseCompatible(other)) {
        return aligned.mul(Array, self, other);
    } else {
        return manual.mul(Array, self, other);
    }
}

pub fn div(comptime Array: type, self: Array, other: Array) !Array {
    if (self.elementWiseCompatible(other)) {
        return aligned.div(Array, self, other);
    } else {
        return manual.div(Array, self, other);
    }
}

pub fn matMul(comptime Array: type, self: Array, other: Array) !Array {
    if (self.isBlasable() and other.isBlasable()) {
        return switch (Array.config.blas) {
            .manual => manual.matMul(Array, self, other),
            .openblas => openblas.matMul(Array, self, other),
        };
    } else {
        return manual.matMul(Array, self, other);
    }
}

test "blas-internal" {
    _ = @import("blas/manual.zig");
    _ = @import("blas/openblas.zig");
}
