const fp32 = @import("fp32.zig");
const Self = @This();
const map = @import("map.zig");

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

pub fn hasLength(self: Self) bool {
    return (self.x | self.y) != 0;
}

pub fn rescale(self: Self, to_length: i32) Self {
    if (self.hasLength()) {
        const fx: f32 = fp32.toFloat(self.x);
        const fy: f32 = fp32.toFloat(self.y);
        const s: f32 = fp32.toFloat(to_length);
        const m: f32 = s / @sqrt(fx * fx + fy * fy);
        return Self.init(
            fp32.fromFloat(fx * m),
            fp32.fromFloat(fy * m),
        );
    }
    return self;
}
