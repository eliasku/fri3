const Vec2 = @import("../math/Vec2.zig");

const Self = @This();

x: f32,
y: f32,
z: f32,
u: f32,
v: f32,
color_mul: u32,
color_add: u32,

pub fn init(pos: Vec2, z: f32, uv: Vec2, color_mul: u32, color_add: u32) Self {
    return .{
        .x = pos.x,
        .y = pos.y,
        .z = z,
        .u = uv.x,
        .v = uv.y,
        .color_mul = color_mul,
        .color_add = color_add,
    };
}
