const FPVec2 = @import("FPVec2.zig");
const fp32 = @import("fp32.zig");
const Self = @This();

x: i32,
y: i32,
r: i32,
b: i32,

pub fn init(x: i32, y: i32, wi: i32, he: i32) Self {
    return .{
        .x = x,
        .y = y,
        .r = x + wi,
        .b = y + he,
    };
}

pub fn fromInt(x: i32, y: i32, wi: i32, he: i32) Self {
    return .{
        .x = x << fp32.fbits,
        .y = y << fp32.fbits,
        .r = (x + wi) << fp32.fbits,
        .b = (y + he) << fp32.fbits,
    };
}

pub fn translate(self: Self, dx: i32, dy: i32) Self {
    return .{
        .x = self.x + dx,
        .y = self.y + dy,
        .r = self.r + dx,
        .b = self.b + dy,
    };
}

pub fn w(self: Self) i32 {
    return self.r - self.x;
}

pub fn h(self: Self) i32 {
    return self.b - self.y;
}

pub fn cx(self: Self) i32 {
    return (self.x >> 1) + (self.r >> 1);
}

pub fn cy(self: Self) i32 {
    return (self.y >> 1) + (self.b >> 1);
}

// https://www.gamedev.net/forums/topic/619296-ultra-fast-2d-aabb-overlap-test/4907175/?page=1
pub fn overlaps(self: Self, other: Self) bool {
    return ((self.x - other.r) &
        (self.y - other.b) &
        (other.x - self.r) &
        (other.y - self.b) & -2147483648) != 0;
}
