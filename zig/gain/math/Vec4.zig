comptime {
    @setFloatMode(.optimized);
}

const std = @import("std");
const Self = @This();

x: f32,
y: f32,
z: f32,
w: f32,

pub fn init(x: f32, y: f32, z: f32, w: f32) Self {
    return .{
        .x = x,
        .y = y,
        .z = z,
        .w = w,
    };
}

pub fn splat(v: f32) Self {
    return .{
        .x = v,
        .y = v,
        .z = v,
        .w = v,
    };
}

pub fn zero() Self {
    return Self.splat(0);
}

pub fn one() Self {
    return Self.splat(1);
}

pub fn half() Self {
    return Self.splat(0.5);
}

pub fn add(self: Self, v: Self) Self {
    return .{
        .x = self.x + v.x,
        .y = self.y + v.y,
        .z = self.z + v.z,
        .w = self.w + v.w,
    };
}

pub fn sub(self: Self, v: Self) Self {
    return .{
        .x = self.x - v.x,
        .y = self.y - v.y,
        .z = self.z - v.z,
        .w = self.w - v.w,
    };
}

pub fn mul(self: Self, v: Self) Self {
    return .{
        .x = self.x * v.x,
        .y = self.y * v.y,
        .z = self.z * v.z,
        .w = self.w * v.w,
    };
}

pub fn div(self: Self, v: Self) Self {
    return .{
        .x = self.x / v.x,
        .y = self.y / v.y,
        .z = self.z / v.z,
        .w = self.w / v.w,
    };
}

pub fn neg(self: Self) Self {
    return .{
        .x = -self.x,
        .y = -self.y,
        .z = -self.z,
        .w = -self.w,
    };
}

pub fn scale(self: Self, f: f32) Self {
    return .{
        .x = f * self.x,
        .y = f * self.y,
        .z = f * self.z,
        .w = f * self.w,
    };
}

pub fn lerp(a: Self, b: Self, t: f32) Self {
    return a.scale(1 - t).add(b.scale(t));
}

pub fn min(self: Self, v: Self) Self {
    return .{
        .x = @min(self.x, v.x),
        .y = @min(self.y, v.y),
        .z = @min(self.z, v.z),
        .w = @min(self.w, v.w),
    };
}

pub fn max(self: Self, v: Self) Self {
    return .{
        .x = @max(self.x, v.x),
        .y = @max(self.y, v.y),
        .z = @max(self.z, v.z),
        .w = @max(self.w, v.w),
    };
}

pub fn clamp(self: Self, min_comps: Self, max_comps: Self) Self {
    return .{
        .x = std.math.clamp(self.x, min_comps.x, max_comps.x),
        .y = std.math.clamp(self.y, min_comps.y, max_comps.y),
        .z = std.math.clamp(self.z, min_comps.z, max_comps.z),
        .w = std.math.clamp(self.w, min_comps.w, max_comps.w),
    };
}
