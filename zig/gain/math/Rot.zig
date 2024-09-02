comptime {
    @setFloatMode(.optimized);
}

const mathf = @import("../math/functions.zig");
const sin = mathf.sin;
const cos = mathf.cos;

const std = @import("std");
const Vec2 = @import("Vec2.zig");
const Self = @This();

x: f32,
y: f32,
z: f32,
w: f32,

pub fn identity() Self {
    return .{ .x = 1, .y = 0, .z = 0, .w = 1 };
}

pub fn add(self: Self, v: Self) Self {
    return .{ .x = self.x + v.x, .y = self.y + v.y, .z = self.z + v.z, .w = self.w + v.w };
}

pub fn sub(self: Self, v: Self) Self {
    return .{ .x = self.x - v.x, .y = self.y - v.y, .z = self.z - v.z, .w = self.w - v.w };
}

pub fn mul(self: Self, v: Self) Self {
    return .{ .x = self.x * v.x, .y = self.y * v.y, .z = self.z * v.z, .w = self.w * v.w };
}

pub fn div(self: Self, v: Self) Self {
    return .{ .x = self.x / v.x, .y = self.y / v.y, .z = self.z / v.z, .w = self.w / v.w };
}

pub fn neg(self: Self) Self {
    return .{ .x = -self.x, .y = -self.y, .z = -self.z, .w = -self.w };
}

pub fn scale(self: Self, f: f32) Self {
    return .{
        .x = f * self.x,
        .y = f * self.y,
        .z = f * self.z,
        .w = f * self.w,
    };
}

pub fn scale2(r: Self, v: Vec2) Self {
    return r.mul(.{
        .x = v.x,
        .y = v.x,
        .z = v.y,
        .w = v.y,
    });
}

pub fn rotate(r: Self, radians: f32) Self {
    const sn = sin(radians);
    const cs = cos(radians);
    return .{
        .x = r.x * cs + r.z * sn,
        .y = r.w * sn + r.y * cs,
        .z = -r.x * sn + r.z * cs,
        .w = r.w * cs - r.y * sn,
    };
}

pub fn rotateUnit(r: Self, tau: f32) Self {
    const sn = mathf.sintau(tau);
    const cs = mathf.costau(tau);
    return .{
        .x = r.x * cs + r.z * sn,
        .y = r.w * sn + r.y * cs,
        .z = -r.x * sn + r.z * cs,
        .w = r.w * cs - r.y * sn,
    };
}

test "rot" {
    const v = Self.identity().rotate(0);
    try std.testing.expect(v.w == 1);
}
