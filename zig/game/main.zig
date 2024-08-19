const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;

pub fn update() void {}

pub fn render() void {
    gfx.setupOpaquePass();
    gfx.state.matrix = Mat2d.identity();
    gfx.state.z = 1;
    gfx.setTexture(0);
    gfx.quad(Vec2.init(0, 0), Vec2.fromIntegers(app.w, app.h), 0xFF00FFFF);
}
