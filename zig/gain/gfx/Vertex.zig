const Vec2 = @import("../math/Vec2.zig");

const Self = @This();

x: f32,
y: f32,
z: f32,
color: u32,

pub fn init(x: f32, y: f32, z: f32, color: u32) Self {
    return .{
        .x = x,
        .y = y,
        .z = z,
        .color = color,
    };
}
