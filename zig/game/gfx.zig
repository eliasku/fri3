const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");

const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;

pub fn quad(x: i32, y: i32, w: i32, h: i32, color: u32) void {
    gfx.quad(Vec2.fromIntegers(x, y), Vec2.fromIntegers(w, h), color);
}

pub fn rect(rc: FPRect, color: u32) void {
    quad(rc.x, rc.y, rc.w, rc.h, color);
}

pub fn depth(x: i32, y: i32) void {
    _ = x;
    gfx.state.z = @floatFromInt(y >> fp32.fbits);
}

pub fn attention(x: i32, y: i32) void {
    gfx.fillCircle(Vec2.fromIntegers(x, y), Vec2.fromIntegers(2 << fp32.fbits, 2 << fp32.fbits), 8, 0xFF000000);
    gfx.fillCircle(Vec2.fromIntegers(x, y), Vec2.fromIntegers(6 << fp32.fbits, 2 << fp32.fbits), 6, 0xFFFFFFFF);
}

pub fn scream(x: i32, y: i32) void {
    gfx.lineQuad(Vec2.fromIntegers(x + (2 << fp32.fbits), y + (-2 << fp32.fbits)), Vec2.fromIntegers(x + (8 << fp32.fbits), y + (-8 << fp32.fbits)), 0xFF000000, 0xFF000000, 0, 2 << fp32.fbits);
    gfx.lineQuad(Vec2.fromIntegers(x + (2 << fp32.fbits), y + (0 << fp32.fbits)), Vec2.fromIntegers(x + (10 << fp32.fbits), y + (-4 << fp32.fbits)), 0xFF000000, 0xFF000000, 0, 2 << fp32.fbits);
    gfx.lineQuad(Vec2.fromIntegers(x + (0 << fp32.fbits), y + (-2 << fp32.fbits)), Vec2.fromIntegers(x + (4 << fp32.fbits), y + (-10 << fp32.fbits)), 0xFF000000, 0xFF000000, 0, 2 << fp32.fbits);
}
