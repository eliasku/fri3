const fp32 = @import("fp32.zig");
const Self = @This();

x: i32,
y: i32,

pub fn fromInt(x: i32, y: i32) Self {
    return .{
        .x = x << fp32.fbits,
        .y = y << fp32.fbits,
    };
}

pub fn init(x: i32, y: i32) Self {
    return .{
        .x = x,
        .y = y,
    };
}

pub fn add(self: Self, other: Self) Self {
    return .{
        .x = self.x + other.x,
        .y = self.y + other.y,
    };
}

pub fn scaleF(self: Self, f: f32) Self {
    return .{
        .x = fp32.scale(self.x, f),
        .y = fp32.scale(self.y, f),
    };
}

pub fn scale(self: Self, f: i32) Self {
    return .{
        .x = fp32.mul(self.x, f),
        .y = fp32.mul(self.y, f),
    };
}
