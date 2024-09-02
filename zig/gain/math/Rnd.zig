// simple PRNG from libc with u32 state
comptime {
    @setFloatMode(.optimized);
}

const std = @import("std");
const Self = @This();

seed: u32,

pub fn next(self: *Self) u32 {
    var x = self.*.seed;
    x = x *% 1103515245 +% 12345;
    self.seed = x;
    return temper(x) >> 1;
}

pub fn int(self: *Self, min: i32, max: i32) i32 {
    return min + @mod(@as(i32, @bitCast(self.next())), max - min + 1);
}

pub fn float(self: *Self) f32 {
    return unorm_f32_from_u32(self.next());
}

pub fn frange(self: *Self, min: f32, max: f32) f32 {
    return std.math.lerp(min, max, self.float());
}

fn temper(state: u32) u32 {
    var x = state;
    x ^= x >> 11;
    x ^= (x << 7) & 0x9D2C5680;
    x ^= (x << 15) & 0xEFC60000;
    x ^= x >> 18;
    return x;
}

fn unorm_f32_from_u32(value: u32) f32 {
    const exponent = 127;
    const mantissa = value & ((1 << 23) - 1);
    const f: f32 = @bitCast((exponent << 23) | mantissa);
    return f - 1.0;
}

// pub fn next(self: *Self) u32 {
//     var x = self.*.seed;
//     x = (x *% 1664525) +% 1013904223;
//     self.seed = x;
//     return x;
// }

// pub fn float(self: *Self) f32 {
//     return @as(f32, @floatFromInt(self.next())) / 0x100000000;
// }

test "rand" {
    const expect = @import("std").testing.expect;
    var rnd = Self{ .seed = 0 };
    const f0 = rnd.float();
    const f1 = rnd.float();
    try expect(f0 != f1);
    try expect(rnd.seed != 0);
}
