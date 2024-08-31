pub fn add(Array: type, self: Array, other: Array) !Array {
    // TODO: can be optimized with single for loop if arrays are compatible
    const shape = try self.get_broadcast_shape(other);
    const result = try Array.init(self.allocator, shape);

    const a1 = self.broadcast_to_shape(shape) catch @panic("Unreachable");
    const a2 = other.broadcast_to_shape(shape) catch @panic("Unreachable");

    var linear_index: usize = 0;
    var iter = Array.Iter.init(shape);
    while (iter.next()) |index| {
        const v1 = a1.get(index) catch @panic("Unreachable");
        const v2 = a2.get(index) catch @panic("Unreachable");

        result.data[linear_index] = v1 + v2;

        linear_index += 1;
    }

    return result;
}
