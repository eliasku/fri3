comptime {
    @setFloatMode(.optimized);
}

const Vec2 = @import("Vec2.zig");
const Rot = @import("Rot.zig");
const Self = @This();

rot: Rot,
pos: Vec2,

pub fn identity() Self {
    return .{
        .rot = Rot.identity(),
        .pos = Vec2.zero(),
    };
}

pub fn translate(self: Self, xy: Vec2) Self {
    return .{
        .rot = self.rot,
        .pos = self.pos.add(.{
            .x = self.rot.x * xy.x + self.rot.z * xy.y,
            .y = self.rot.w * xy.y + self.rot.y * xy.x,
        }),
    };
}

pub fn scale(self: Self, xy: Vec2) Self {
    return .{
        .rot = self.rot.scale2(xy),
        .pos = self.pos,
    };
}

pub fn rotate(self: Self, radians: f32) Self {
    return .{
        .rot = self.rot.rotate(radians),
        .pos = self.pos,
    };
}

pub fn rotateUnit(self: Self, tau: f32) Self {
    return .{
        .rot = self.rot.rotateUnit(tau),
        .pos = self.pos,
    };
}
