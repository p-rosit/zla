const std = @import("std");
const math = std.math;
const Struct = std.builtin.Type.Struct;

pub const Error = error{
    Overflow,
    OutOfBounds,
    MissingIndex,
    NotCompatibleOrBroadcastable,
};

pub fn IndexIter(size: usize) type {
    return struct {
        const Self = @This();

        complete: bool,
        shape: [size]usize,
        index: [size]usize,

        pub fn init(shape: [size]usize) Self {
            var iter = Self{
                .shape = shape,
                .index = undefined,
                .complete = false,
            };
            @memset(&iter.index, 0);

            return iter;
        }

        pub fn next(self: *Self) ?[size]usize {
            if (self.complete) return null;

            const current = self.index;

            for (0..self.index.len) |i| {
                const reversed = self.index.len - i - 1;
                self.index[reversed] += 1;

                if (self.index[reversed] < self.shape[reversed]) {
                    return current;
                }

                self.index[reversed] = 0;
            }

            self.complete = true;
            return current;
        }
    };
}

pub const Slice = struct {
    lo: usize = 0,
    hi: usize,
    st: usize = 1,

    pub fn size(self: Slice) usize {
        if (self.st == 0) {
            @panic("Cannot get size of slice if stride is zero");
        }

        if (self.hi < self.lo) {
            return 0;
        } else {
            return 1 + (self.hi - self.lo - 1) / self.st;
        }
    }
};

pub fn get_broadcast_shape(comptime size: usize, self: [size]usize, other: [size]usize) ![size]usize {
    var shape: [size]usize = undefined;

    for (0.., self, other) |i, shape1, shape2| {
        if (shape1 != shape2 and shape1 != 1 and shape2 != 1) {
            return Error.NotCompatibleOrBroadcastable;
        }
        shape[i] = @max(shape1, shape2);
    }

    return shape;
}

pub fn get_total_size(shape: []const usize) !usize {
    var total: usize = 1;

    for (shape) |dim| {
        if (math.maxInt(usize) / dim < total) {
            return Error.Overflow;
        }
        total *= dim;
    }

    return total;
}

pub fn get_reshape_info(reshape_struct: anytype) Struct {
    const T = @TypeOf(reshape_struct);
    const type_info = @typeInfo(T);

    if (type_info != .Struct) {
        @compileError("New shape must be struct");
    }

    const struct_info = type_info.Struct;
    inline for (struct_info.fields) |field| {
        // TODO: verify index is usize or similar
        _ = field;
    }

    return struct_info;
}
