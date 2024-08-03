const builtin = @import("builtin");
const std = @import("std");
const is_wasm = builtin.target.isWasm();

inline fn call1(x: anytype, comptime op: []const u8) @TypeOf(x) {
    const T = @TypeOf(x);
    const code = std.fmt.comptimePrint(
        \\local.get %[x]
        \\{s}.{s}
        \\local.set %[result]
    , .{ @typeName(T), op });
    return asm (code
        : [result] "=r" (-> T),
        : [x] "r" (x),
    );
}

inline fn call2(x: anytype, y: @TypeOf(x), comptime op: []const u8) @TypeOf(x) {
    const T = @TypeOf(x);
    const code = std.fmt.comptimePrint(
        \\local.get %[x]
        \\local.get %[y]
        \\{s}.{s}
        \\local.set %[result]
    , .{ @typeName(T), op });
    return asm (code
        : [result] "=r" (-> T),
        : [x] "r" (x),
          [y] "r" (y),
    );
}

pub inline fn copysign(x: anytype, y: @TypeOf(x)) @TypeOf(x) {
    const has_wasm_instruction = switch (@TypeOf(x)) {
        f32, f64 => is_wasm,
        else => false,
    };

    return if (has_wasm_instruction)
        call2(x, y, "copysign")
    else
        std.math.copysign(x, y);
}

test "wasm copysign" {
    const expect = std.testing.expect;
    const math = std.math;
    inline for ([_]type{ f32, f64 }) |T| {
        try expect(copysign(@as(T, 1.0), @as(T, 1.0)) == 1);
        try expect(copysign(@as(T, 2.0), @as(T, -2.0)) == -2);
        try expect(copysign(@as(T, -3.0), @as(T, 3.0)) == 3);
        try expect(copysign(@as(T, -4.0), @as(T, -4.0)) == -4);
        try expect(copysign(@as(T, 5.0), @as(T, -500.0)) == -5);
        try expect(copysign(math.inf(T), @as(T, -0.0)) == -math.inf(T));
        try expect(copysign(@as(T, 6.0), -math.nan(T)) == -6.0);
    }
}
