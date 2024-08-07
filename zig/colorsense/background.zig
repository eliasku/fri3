const std = @import("std");
const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Color32 = gain.math.Color32;
const Vec2 = gain.math.Vec2;
const Mat2d = gain.math.Mat2d;
const Rnd = gain.math.Rnd;
const getCircleSegments = gain.math.getCircleSegments;
const mathf = @import("../gain/math/functions.zig");

var rnd = Rnd{ .seed = 0 };

const RayParticle = struct {
    p: Vec2 = Vec2.zero(),
    v: Vec2 = Vec2.zero(),
    time: f32 = 0,
    timeTotal: f32 = 0,
    alpha: f32 = 0,
    scale: f32 = 0,
};

const DustParticle = struct {
    p: Vec2 = Vec2.zero(),
    v: Vec2 = Vec2.zero(),
    a: Vec2 = Vec2.zero(),
    time: f32 = 0,
    timeTotal: f32 = 0,
    alpha: f32 = 0,
    scale0: f32 = 0,
    scale1: f32 = 0,
    acc_x_phase: f32 = 0,
};

var rays: [8]RayParticle = .{RayParticle{}} ** 8;
var dust: [16]DustParticle = .{DustParticle{}} ** 16;
var cursor = struct {
    pos: Vec2 = Vec2.zero(),
    time: f32 = 1,
}{};

pub fn update() void {
    const size = gain.app.size();
    const screenScale = size.y / 480.0;
    const dt = 0.08;
    for (rays[0..]) |*p| {
        p.p = p.p.add(p.v.scale(dt * screenScale));
        p.time += dt;
        if (p.time >= p.timeTotal) {
            p.time = 0;
            p.timeTotal = rnd.frange(2, 5);
            const l = rnd.frange(0, size.x + size.y);
            if (l > size.x) {
                p.p.x = -20;
                p.p.y = l - size.x;
                p.v.x = 0;
                p.v.y = rnd.frange(-10, 10);
            } else {
                p.p.x = l;
                p.p.y = -20;
                p.v.x = rnd.frange(-10, 10);
                p.v.y = 0;
            }
            p.alpha = rnd.frange(0.05, 0.1);
            p.scale = rnd.frange(2, 5);
        }
    }

    // dust
    for (dust[0..]) |*p| {
        var a = p.a;
        a.x *= mathf.sin(p.acc_x_phase + p.time * std.math.tau);
        p.v = p.v.add(a.scale(dt)); // screenScale
        p.p = p.p.add(p.v.scale(dt * screenScale));
        p.time += dt;
        if (p.time >= p.timeTotal) {
            p.time = 0;
            p.timeTotal = rnd.frange(1, 5);
            p.p = Vec2.init(
                rnd.frange(0, size.x),
                rnd.frange(0, size.y),
            );
            p.alpha = rnd.frange(0.2, 0.5);
            p.scale0 = rnd.frange(0.2, 0.7);
            p.scale1 = rnd.frange(0.2, 0.7);
            p.acc_x_phase = rnd.frange(0, 6);

            const speed = rnd.frange(0, 10);
            const acc = rnd.frange(0, 20);
            const dir_angle = rnd.frange(0, std.math.tau);
            const dir = Vec2.initDir(dir_angle);
            p.v = dir.scale(speed);
            p.a = dir.scale(acc);

            // acc_x_speed = tau
            // angle_velocity_factor = 0.3
        }
    }

    if (cursor.time < 1.0) {
        // cursor.time += dt * 2.0;
        cursor.time += dt;
    }
}

pub fn click(pos: Vec2) void {
    cursor.pos = pos;
    cursor.time = 0;
}

pub fn render() void {
    const size = gain.app.size();
    const screenScale = size.y / 480.0;

    gfx.state.color_add = 0xFF000000;
    for (rays) |p| {
        if (p.time < p.timeTotal) {
            const r = p.time / p.timeTotal;
            gfx.state.matrix = Mat2d.identity();
            gfx.state.matrix = gfx.state.matrix.rotate(-std.math.pi / 4.0);
            gfx.state.matrix.pos = p.p;
            const color = Color32.fromFloats(1, 1, 1, p.alpha * mathf.sin(r * std.math.pi)).argb();
            gfx.quadColors(
                Vec2.init(-0.75, 0).scale(p.scale * screenScale),
                Vec2.init(1.5, 80).scale(p.scale * screenScale),
                .{
                    color, color, 0xFFFFFF, 0xFFFFFF,
                },
            );
        }
    }

    gfx.state.color_add = 0xFF000000;
    for (dust) |p| {
        if (p.time < p.timeTotal) {
            const r = p.time / p.timeTotal;
            const vis_angle = 0.3 * mathf.atan2(p.v.y, p.v.x);
            gfx.state.matrix = Mat2d.identity();
            gfx.state.matrix = gfx.state.matrix.rotate(vis_angle);
            gfx.state.matrix.pos = p.p;
            const scale = std.math.lerp(p.scale0, p.scale1, r);
            const color = Color32.fromFloats(1, 1, 1, p.alpha * mathf.sin(r * std.math.pi)).argb();
            gfx.quad(
                Vec2.init(-2, -2).scale(scale * screenScale),
                Vec2.init(4, 4).scale(scale * screenScale),
                color,
            );
        }
    }

    if (cursor.time < 1.0) {
        const r = cursor.time;
        gfx.state.matrix = Mat2d.identity();
        const scale = 16 * (1 - (1 - r) * (1 - r));
        const alpha = 1 - r * r;
        const color = Color32.lerp8888(0x00000000, 0xFFFFFFFF, alpha);
        const color2 = Color32.lerp8888(0x00000000, 0xFFFFFF, alpha);
        const radius = scale * screenScale;
        gfx.fillCircleEx(
            cursor.pos,
            Vec2.splat(radius),
            getCircleSegments(radius),
            color,
            color2,
        );
    }
}
