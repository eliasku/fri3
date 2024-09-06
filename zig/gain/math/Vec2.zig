comptime {
    @setFloatMode(.optimized);
}

const std = @import("std");
const Mat2d = @import("Mat2d.zig");
const mathf = @import("functions.zig");
const sin = mathf.sin;
const cos = mathf.cos;

const Self = @This();

x: f32,
y: f32,

pub fn init(x: f32, y: f32) Self {
    return .{
        .x = x,
        .y = y,
    };
}

// x-axis CW angle
pub fn initDir(a: f32) Self {
    return .{
        .x = cos(a),
        .y = sin(a),
    };
}

pub fn fromIntegers(x: anytype, y: anytype) Self {
    return .{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
    };
}

pub fn splat(v: f32) Self {
    return .{ .x = v, .y = v };
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

pub fn add(self: Self, v: Self) Self {
    return .{
        .x = self.x + v.x,
        .y = self.y + v.y,
    };
}

pub fn sub(self: Self, v: Self) Self {
    return .{
        .x = self.x - v.x,
        .y = self.y - v.y,
    };
}

pub fn mul(self: Self, v: Self) Self {
    return .{
        .x = self.x * v.x,
        .y = self.y * v.y,
    };
}

pub fn div(self: Self, v: Self) Self {
    return .{
        .x = self.x / v.x,
        .y = self.y / v.y,
    };
}

pub fn neg(self: Self) Self {
    return .{
        .x = -self.x,
        .y = -self.y,
    };
}

pub fn scale(self: Self, f: f32) Self {
    return .{
        .x = f * self.x,
        .y = f * self.y,
    };
}

pub fn min(self: Self, v: Self) Self {
    return .{
        .x = @min(self.x, v.x),
        .y = @min(self.y, v.y),
    };
}

pub fn max(self: Self, v: Self) Self {
    return .{
        .x = @max(self.x, v.x),
        .y = @max(self.y, v.y),
    };
}

pub fn clamp(self: Self, min_comps: Self, max_comps: Self) Self {
    return .{
        .x = std.math.clamp(self.x, min_comps.x, max_comps.x),
        .y = std.math.clamp(self.y, min_comps.y, max_comps.y),
    };
}

pub fn transform(self: Self, m: Mat2d) Self {
    return .{
        .x = self.x * m.rot.x + self.y * m.rot.z + m.pos.x,
        .y = self.x * m.rot.y + self.y * m.rot.w + m.pos.y,
    };
}

pub fn dot(self: Self, target: Self) f32 {
    return self.x * target.x + self.y * target.y;
}

pub fn cross(self: Self, target: Self) f32 {
    return self.x * target.y - self.y * target.x;
}

pub fn lengthSq(self: Self) f32 {
    return self.dot(self);
}

pub fn length(self: Self) f32 {
    return @sqrt(self.lengthSq());
}

pub fn manhattanLength(self: Self) f32 {
    return @abs(self.x) + @abs(self.y);
}

pub fn distanceToSquared(self: Self, target: Self) f32 {
    return self.sub(target).lengthSq();
}

pub fn distanceTo(self: Self, target: Self) f32 {
    return self.sub(target).length();
}

pub fn manhattanDistanceTo(self: Self, target: Self) f32 {
    return self.sub(target).manhattanLength();
}

pub fn normalize(self: Self) Self {
    return self.scale(1.0 / self.length());
}

pub fn ofLength(self: Self, vector_length: f32) Self {
    return self.normalize().scale(vector_length);
}

pub fn angle(self: Self) f32 {
    // computes the angle in radians with respect to the positive x-axis
    return mathf.atan2(-self.y, -self.x) + std.math.pi;
}

pub fn angleTo(self: Self, to_vector: Self) f32 {
    const denominator: f32 = @sqrt(self.lengthSq() * to_vector.lengthSq());
    if (denominator == 0) return @floatCast(std.math.pi / 2.0);
    const theta = self.dot(to_vector) / denominator;
    // clamp, to handle numerical problems
    return std.math.acos(std.math.clamp(theta, -1, 1));
}

pub fn rotateAround(self: Self, center: Self, rotation: f32) Self {
    const c = cos(rotation);
    const s = sin(rotation);
    const x = self.x - center.x;
    const y = self.y - center.y;
    return .{
        .x = x * c - y * s + center.x,
        .y = x * s + y * c + center.y,
    };
}

pub fn lerp(a: Self, b: Self, t: f32) Self {
    return a.scale(1 - t).add(b.scale(t));
}
