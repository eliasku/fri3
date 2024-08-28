const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");

const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const fbits = fp32.fbits;
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

pub fn head(x: i32, y: i32, lx: i32, ly: i32, color: u32, hair: u32, eye_color: u32, angle: i32) void {
    const eye = FPRect.fromInt(-1, -2, 2, 4);
    if (ly >= 0) {
        rect(eye.translate(x + lx - (2 << fbits), y + ly), eye_color);
        rect(eye.translate(x + lx + (2 << fbits), y + ly), eye_color);
    }
    rect(FPRect.init(x, y, 0, 4 << fbits).expandInt(5), color);
    // rect(FPRect.init(x, y - (1 << fbits), 0, 4 << fbits).expandInt(5), 0xFF666600);
    _ = hair;
    _ = angle;
}

pub fn knife(x: i32, y: i32, angle: i32) void {
    const m = gain.gfx.state.matrix;
    gain.gfx.state.matrix = gain.gfx.state.matrix.translate(Vec2.fromIntegers(x, y)).rotate(fp32.toFloat(angle));
    gain.gfx.lineQuad(Vec2.fromIntegers(0, 0), Vec2.fromIntegers((2 << fbits), 0), 0xFF888888, 0xFF666666, 2 << fbits, 2 << fbits);
    gain.gfx.lineQuad(Vec2.fromIntegers((2 << fbits), 0), Vec2.fromIntegers((10 << fbits), -2 << fbits), 0xFFFFFFFF, 0xFF999999, 2 << fbits, 3 << fbits);
    gain.gfx.lineQuad(Vec2.fromIntegers((10 << fbits), -2 << fbits), Vec2.fromIntegers((14 << fbits), -5 << fbits), 0xFF999999, 0xFF999999, 3 << fbits, 2 << fbits);
    gain.gfx.state.matrix = m;
}

var prev_matrix: gain.math.Mat2d = undefined;

pub fn push(x: i32, y: i32, angle: i32) void {
    prev_matrix = gain.gfx.state.matrix;
    gain.gfx.state.matrix = gain.gfx.state.matrix.translate(Vec2.fromIntegers(x, y)).rotate(fp32.toFloat(angle));
}

pub fn restore() void {
    gain.gfx.state.matrix = prev_matrix;
}

pub fn trouses(color: u32) void {
    gain.gfx.lineQuad(
        Vec2.fromIntegers(0, -2 << fbits),
        Vec2.fromIntegers(0, 2 << fbits),
        color,
        color,
        11 << fbits,
        0,
    );
}

pub fn shadow(x: i32, y: i32, sz: i32, color: u32) void {
    gain.gfx.fillCircle(Vec2.fromIntegers(x, y), Vec2.fromIntegers(sz, sz >> 1), 8, color);
}
