const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");
const gain = @import("../gain/main.zig");
const FPVec2 = @import("FPVec2.zig");
const Vec2 = gain.math.Vec2;
const Mat2d = gain.math.Mat2d;
pub var scale: f32 = undefined;
pub var ui_scale: f32 = undefined;
pub var rc: FPRect = undefined;
pub var position: FPVec2 = undefined;
pub var zoom: f32 = 1.0;
pub const screen_size = 512 << fp32.fbits;
pub var matrix: Mat2d = undefined;
pub var shake_c: i32 = 0;
const g = @import("g.zig");

const zoom_tweak = 2;
pub fn shakeM() void {
    shake_c = 16;
}

pub fn shakeS() void {
    shake_c = 8;
}

pub fn update(tx: i32, ty: i32) void {
    if (shake_c > 0) {
        shake_c -= 1;
    }
    const app = gain.app;
    const app_w: f32 = @floatFromInt(app.w);
    const app_h: f32 = @floatFromInt(app.h);
    const short_side = @min(app_w, app_h);
    ui_scale = short_side / screen_size;
    scale = ui_scale / (zoom / zoom_tweak);

    position.x = tx;
    position.y = ty;
    const shx = g.rnd.int(-shake_c, shake_c) << fp32.fbits;
    const shy = g.rnd.int(-shake_c, shake_c) << fp32.fbits;
    matrix = Mat2d
        .identity()
        .translate(Vec2.fromIntegers(app.w >> 1, app.h >> 1))
        .scale(Vec2.splat(scale))
        .translate(Vec2.fromIntegers(shx - tx, shy - ty));

    const occ_scale = 1 / scale;
    const sc_w = fp32.scale(@bitCast(app.w), occ_scale);
    const sc_h = fp32.scale(@bitCast(app.h), occ_scale);
    rc = FPRect.init(
        tx - (sc_w >> 1),
        ty - (sc_h >> 1),
        sc_w,
        sc_h,
    ).expandInt(32);
}
