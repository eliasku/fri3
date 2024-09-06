const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");
const gain = @import("../gain/main.zig");
const FPVec2 = @import("FPVec2.zig");
const Vec2 = gain.math.Vec2;
const Mat2d = gain.math.Mat2d;

pub var scale: f32 = undefined;
pub var rc: FPRect = undefined;
pub var position: FPVec2 = undefined;
const zoom = 1.0;
pub const screen_size = 512 << fp32.fbits;
pub var matrix: Mat2d = undefined;
pub fn update(tx: i32, ty: i32) void {
    const app = gain.app;
    const app_w: f32 = @floatFromInt(app.w);
    const app_h: f32 = @floatFromInt(app.h);
    const short_side = @min(app_w, app_h);
    scale = short_side / (screen_size * zoom);

    position.x = tx;
    position.y = ty;
    matrix = Mat2d
        .identity()
        .translate(Vec2.fromIntegers(app.w >> 1, app.h >> 1))
        .scale(Vec2.splat(scale))
        .translate(Vec2.fromIntegers(-position.x, -position.y));

    const occ_scale = 1 / scale;
    const sc_w = fp32.scale(@bitCast(app.w), occ_scale);
    const sc_h = fp32.scale(@bitCast(app.h), occ_scale);
    rc = FPRect.init(
        position.x - (sc_w >> 1),
        position.y - (sc_h >> 1),
        sc_w,
        sc_h,
    ).expandInt(-32);
}
