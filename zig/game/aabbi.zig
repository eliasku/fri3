const std = @import("std");
const Vec2 = @import("../gain/main.zig").math.Vec2;
const Self = @This();

minx: i32,
miny: i32,
maxx: i32,
maxy: i32,

pub fn init(x: i32, y: i32, width: i32, height: i32) Self {
    return .{
        .minx = x,
        .miny = y,
        .maxx = x + width,
        .maxy = y + height,
    };
}

// https://www.gamedev.net/forums/topic/619296-ultra-fast-2d-aabb-overlap-test/4907175/?page=1
pub fn check(a: Self, b: Self) bool {
    return ((a.minx - b.maxx) &
        (a.miny - b.maxy) &
        (b.minx - a.maxx) &
        (b.miny - a.maxy) & -2147483648) != 0;
}

pub fn xf(self: Self) f32 {
    return @floatFromInt(self.minx);
}

pub fn yf(self: Self) f32 {
    return @floatFromInt(self.miny);
}

pub fn widthf(self: Self) f32 {
    return @floatFromInt(self.maxx - self.minx);
}

pub fn heightf(self: Self) f32 {
    return @floatFromInt(self.maxy - self.miny);
}

pub fn posf(self: Self) Vec2 {
    return .{
        .x = self.xf(),
        .y = self.yf(),
    };
}

pub fn sizef(self: Self) Vec2 {
    return .{
        .x = self.widthf(),
        .y = self.heightf(),
    };
}

pub fn w(self: Self) i32 {
    return self.maxx - self.minx;
}

pub fn h(self: Self) i32 {
    return self.maxy - self.miny;
}
