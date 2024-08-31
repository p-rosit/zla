const array = @import("../array.zig");
const manual = @import("manual.zig");
const openblas = @import("openblas.zig");

pub fn add(comptime Array: type, self: Array, other: Array) !Array {
    return switch (Array.config.blas) {
        .manual => manual.add(Array, self, other),
        .openblas => openblas.add(Array, self, other),
    };
}
