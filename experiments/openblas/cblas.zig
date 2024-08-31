const cb = @cImport({
    @cInclude("cblas.h");
});
const std = @import("std");

pub fn main() void {
    var A = [_]f64{
        1.0,  2.0, 1.0,
        -3.0, 4.0, -1.0,
    };

    var B = [_]f64{
        1.0,  2.0, 1.0,
        -3.0, 4.0, -1.0,
    };

    var C = [_]f64{
        0.5, 0.5, 0.5,
        0.5, 0.5, 0.5,
        0.5, 0.5, 0.5,
    };

    cb.cblas_dgemm(
        cb.CblasColMajor,
        cb.CblasNoTrans,
        cb.CblasTrans,
        3,
        3,
        2,
        1.0,
        @as([*c]f64, @ptrCast(@alignCast(&A))),
        3,
        @as([*c]f64, @ptrCast(@alignCast(&B))),
        3,
        2.0,
        @as([*c]f64, @ptrCast(@alignCast(&C))),
        3,
    );

    for (0..3) |i| {
        for (0..3) |j| {
            std.debug.print("{} ", .{C[i + j * 3]});
        }
        std.debug.print("\n", .{});
    }
}
