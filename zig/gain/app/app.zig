const Vec2 = @import("../math/Vec2.zig");

pub var tic: u32 = undefined;
pub var w: u32 = undefined;
pub var h: u32 = undefined;

pub fn size() Vec2 {
    return Vec2.fromIntegers(w, h);
}
