const Vec2 = @import("Vec2.zig");
const Self = @This();

x: f32,
y: f32,
w: f32,
h: f32,

pub fn pos(self: Self) Vec2 {
    return .{ .x = self.x, .y = self.y };
}

pub fn size(self: Self) Vec2 {
    return .{ .x = self.w, .y = self.h };
}

pub fn r(self: Self) f32 {
    return self.x + self.w;
}

pub fn b(self: Self) f32 {
    return self.y + self.h;
}

pub fn centerX(self: Self) f32 {
    return self.x + 0.5 * self.w;
}

pub fn centerY(self: Self) f32 {
    return self.y + 0.5 * self.h;
}

pub fn center(self: Self) Vec2 {
    return Vec2.init(self.x + 0.5 * self.w, self.y + 0.5 * self.h);
}
