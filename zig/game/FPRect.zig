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

pub fn translate(self: Self, dx: i32, dy: i32) Self {
    return .{
        .x = self.x + dx,
        .y = self.y + dy,
        .w = self.w,
        .h = self.h,
    };
}

pub fn expandInt(self: Self, v: i32) Self {
    const s = v << fp32.fbits;
    return .{
        .x = self.x - s,
        .y = self.y - s,
        .w = self.w + (s << 1),
        .h = self.h + (s << 1),
    };
}

pub fn r(self: Self) i32 {
    return self.x + self.w;
}

pub fn b(self: Self) i32 {
    return self.y + self.h;
}

pub fn cx(self: Self) i32 {
    return self.x + (self.w >> 1);
}

pub fn cy(self: Self) i32 {
    return self.y + (self.h >> 1);
}

// https://www.gamedev.net/forums/topic/619296-ultra-fast-2d-aabb-overlap-test/4907175/?page=1
pub fn overlaps(self: Self, other: Self) bool {
    return ((self.x - other.r()) &
        (self.y - other.b()) &
        (other.x - self.r()) &
        (other.y - self.b()) & -2147483648) != 0;
}
