const FPVec2 = @import("FPVec2.zig");
const fp32 = @import("fp32.zig");
const Self = @This();

x: i32,
y: i32,
w: i32,
h: i32,

pub fn init(x: i32, y: i32, w: i32, h: i32) Self {
    return .{
        .x = x,
        .y = y,
        .w = w,
        .h = h,
    };
}

pub inline fn fromInt(x: i32, y: i32, w: i32, h: i32) Self {
    return .{
        .x = x << fp32.fbits,
        .y = y << fp32.fbits,
        .w = w << fp32.fbits,
        .h = h << fp32.fbits,
    };
}

pub inline fn translate(self: Self, dx: i32, dy: i32) Self {
    return .{
        .x = self.x + dx,
        .y = self.y + dy,
        .w = self.w,
        .h = self.h,
    };
}

pub inline fn expand(self: Self, ex: i32, ey: i32) Self {
    return .{
        .x = self.x - ex,
        .y = self.y - ey,
        .w = self.w + (ex << 1),
        .h = self.h + (ey << 1),
    };
}

pub inline fn expandInt(self: Self, v: i32) Self {
    const s = v << fp32.fbits;
    return self.expand(s, s);
}

pub inline fn r(self: Self) i32 {
    return self.x + self.w;
}

pub inline fn b(self: Self) i32 {
    return self.y + self.h;
}

pub inline fn cx(self: Self) i32 {
    return self.x + (self.w >> 1);
}

pub inline fn cy(self: Self) i32 {
    return self.y + (self.h >> 1);
}

// https://www.gamedev.net/forums/topic/619296-ultra-fast-2d-aabb-overlap-test/4907175/?page=1
pub inline fn overlaps(self: Self, other: Self) bool {
    return ((self.x - other.r()) &
        (self.y - other.b()) &
        (other.x - self.r()) &
        (other.y - self.b()) & -2147483648) != 0;
}

pub inline fn test2(self: Self, x: i32, y: i32) bool {
    return ((self.x - x) &
        (self.y - y) &
        (x - self.r()) &
        (y - self.b()) & -2147483648) != 0;
}

pub inline fn contains(self: Self, v: FPVec2) bool {
    return self.test2(v.x, v.y);
}
