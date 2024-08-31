pub fn add(comptime Array: type, self: Array, other: Array) !Array {
    _ = self;
    _ = other;
    @compileError("Not implemented");
}
