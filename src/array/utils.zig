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
