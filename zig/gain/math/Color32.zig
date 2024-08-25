const std = @import("std");
const Self = @This();

r: u8,
g: u8,
b: u8,
a: u8,

pub fn fromARGB(value: u32) Self {
    return .{
        .a = @truncate(value >> 24),
        .r = @truncate(value >> 16),
        .g = @truncate(value >> 8),
        .b = @truncate(value),
    };
}

pub fn argb(c: Self) u32 {
    const a: u32 = c.a;
    const r: u32 = c.r;
    const g: u16 = c.g;
    return (a << 24) | (r << 16) | (g << 8) | c.b;
}

// argb = xyzw
// xyzw = rgba
// and flip
pub fn abgr(c: Self) u32 {
    const a: u32 = c.a;
    const r: u32 = c.r;
    const g: u32 = c.g;
    const b: u32 = c.b;
    return (a << 24) | (b << 16) | (g << 8) | r;
}

pub fn fromFloats(r: f32, g: f32, b: f32, a: f32) Self {
    @setFloatMode(.optimized);
    return .{
        .r = @as(u8, @intFromFloat(0xFF * r)),
        .g = @as(u8, @intFromFloat(0xFF * g)),
        .b = @as(u8, @intFromFloat(0xFF * b)),
        .a = @as(u8, @intFromFloat(0xFF * a)),
    };
}

fn lerp8(a: u8, b: u8, t: f32) u8 {
    return @intFromFloat(std.math.lerp(@as(f32, @floatFromInt(a)), @as(f32, @floatFromInt(b)), t));
}

pub fn lerp(a: Self, b: Self, t: f32) Self {
    return .{
        .r = lerp8(a.r, b.r, t),
        .g = lerp8(a.g, b.g, t),
        .b = lerp8(a.b, b.b, t),
        .a = lerp8(a.a, b.a, t),
    };
}

pub fn lerp8888(color1: u32, color2: u32, t: f32) u32 {
    @setRuntimeSafety(false);
    const rb_mask = 0xff00ff00;
    const ga_mask = 0x00ff00ff;
    const one_q8: comptime_int = 1 << 8; // a fixed point representation of 1.0 with 8 fractional bits
    std.debug.assert(t >= 0 and t <= 1);
    const t_q8: u32 = @intFromFloat(t * one_q8);
    const rb1: u32 = (color1 & rb_mask) >> 8;
    const rb2 = (color2 & rb_mask) >> 8;
    const ga1 = (color1 & ga_mask);
    const ga2 = (color2 & ga_mask);

    const rb = ((rb1 * (one_q8 - t_q8)) + (rb2 * t_q8)) & rb_mask;
    const ga = (((ga1 * (one_q8 - t_q8)) + (ga2 * t_q8)) >> 8) & ga_mask;
    return rb | ga;
}

// t is 0..255
pub fn lerp8888b(color1: u32, color2: u32, t_q8: u32) u32 {
    @setRuntimeSafety(false);
    const rb_mask = 0xff00ff00;
    const ga_mask = 0x00ff00ff;
    const one_q8: comptime_int = 1 << 8; // a fixed point representation of 1.0 with 8 fractional bits
    std.debug.assert(t_q8 >= 0 and t_q8 <= 255);
    const rb1: u32 = (color1 & rb_mask) >> 8;
    const rb2 = (color2 & rb_mask) >> 8;
    const ga1 = (color1 & ga_mask);
    const ga2 = (color2 & ga_mask);

    const rb = ((rb1 * (one_q8 - t_q8)) + (rb2 * t_q8)) & rb_mask;
    const ga = (((ga1 * (one_q8 - t_q8)) + (ga2 * t_q8)) >> 8) & ga_mask;
    return rb | ga;
}
