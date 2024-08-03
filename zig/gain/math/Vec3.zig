comptime {
    @setFloatMode(.optimized);
}

const copysign = @import("../wasm.zig").copysign;
const std = @import("std");
const Self = @This();

x: f32,
y: f32,
z: f32,

pub fn init(x: f32, y: f32, z: f32) Self {
    return .{
        .x = x,
        .y = y,
        .z = z,
    };
}

pub fn splat(s: f32) Self {
    return .{
        .x = s,
        .y = s,
        .z = s,
    };
}

pub fn zero() Self {
    return splat(0);
}

pub fn half() Self {
    return splat(0.5);
}

pub fn one() Self {
    return splat(1);
}

pub fn scale(v: Self, f: f32) Self {
    return .{
        .x = f * v.x,
        .y = f * v.y,
        .z = f * v.z,
    };
}

pub fn perp(v: Self) Self {
    return .{
        .x = copysign(v.z, v.x),
        .y = copysign(v.z, v.y),
        .z = -copysign(@abs(v.x) + @abs(v.y), v.z),
    };
}

pub fn dot(a: Self, b: Self) f32 {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

pub fn lengthSquared(a: Self) f32 {
    return a.dot(a);
}

pub fn almostZero(v: Self) bool {
    const eps = 1e-5;
    return @abs(v.x) < eps and @abs(v.y) < eps and @abs(v.z) < eps;
}

pub fn length(a: Self) f32 {
    return @sqrt(a.lengthSquared());
}

pub fn cross(a: Self, b: Self) Self {
    return .{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

pub fn normalize(a: Self) Self {
    return a.scale(1 / a.length());
}

pub fn reflect(v: Self, n: Self) Self {
    return v.add(n.scale(-2 * v.dot(n)));
}

pub fn add(self: Self, v: Self) Self {
    return .{
        .x = self.x + v.x,
        .y = self.y + v.y,
        .z = self.z + v.z,
    };
}

pub fn sub(self: Self, v: Self) Self {
    return .{
        .x = self.x - v.x,
        .y = self.y - v.y,
        .z = self.z - v.z,
    };
}

pub fn mul(self: Self, v: Self) Self {
    return .{
        .x = self.x * v.x,
        .y = self.y * v.y,
        .z = self.z * v.z,
    };
}

pub fn div(self: Self, v: Self) Self {
    return .{
        .x = self.x / v.x,
        .y = self.y / v.y,
        .z = self.z / v.z,
    };
}

pub fn neg(v: Self) Self {
    return .{
        .x = -v.x,
        .y = -v.y,
        .z = -v.z,
    };
}

pub fn refract(uv: Self, n: Self, etai_over_etat: f32) Self {
    const cos_theta = @min(uv.neg().dot(n), 1);
    const r_out_perp = n.scale(cos_theta).add(uv).scale(etai_over_etat);
    const r_out_parallel = n.scale(-@sqrt(@abs(1 - r_out_perp.lengthSquared())));
    return r_out_perp.add(r_out_parallel);
}

pub fn lerp(a: Self, b: Self, t: f32) Self {
    return a.scale(1 - t).add(b.scale(t));
}

test "Self perp_fast" {
    try std.testing.expect((Self{ .x = 1, .y = 1, .z = 0 }).perp().z == -2);
}
