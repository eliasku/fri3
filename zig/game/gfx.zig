const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");

const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const fbits = fp32.fbits;
const Color32 = gain.math.Color32;
const colors = @import("colors.zig");

pub fn quad_(x: i32, y: i32, w: i32, h: i32) void {
    gfx.requireTriangles(4, 6);
    gfx.addQuadIndices();
    vertex(x, y);
    vertex(x + w, y);
    vertex(x + w, y + h);
    vertex(x, y + h);
}

pub fn romb(x: i32, y: i32, r: i32) void {
    gfx.requireTriangles(4, 6);
    gfx.addQuadIndices();
    vertex(x, y - r);
    vertex(x + r, y);
    vertex(x, y + r);
    vertex(x - r, y);
}

pub inline fn rect_(rc: FPRect) void {
    quad_(rc.x, rc.y, rc.w, rc.h);
}

pub inline fn depth(x: i32, y: i32) void {
    _ = x;
    gfx.state.z = y;
}

pub fn attention() void {
    colorRGB(colors.black);
    circle(0, 0, 2 << fbits, 2 << fbits, 8);
    colorRGB(colors.star);
    circle(0, 0, 6 << fbits, 2 << fbits, 6);
}

pub fn scream() void {
    colorRGB(colors.black);
    line((2 << fp32.fbits), (-2 << fp32.fbits), (8 << fp32.fbits), (-8 << fp32.fbits), 0, 2 << fp32.fbits);
    line((2 << fp32.fbits), (0 << fp32.fbits), (10 << fp32.fbits), (-4 << fp32.fbits), 0, 2 << fp32.fbits);
    line((0 << fp32.fbits), (-2 << fp32.fbits), (4 << fp32.fbits), (-10 << fp32.fbits), 0, 2 << fp32.fbits);
}

pub fn head(lx: i32, ly: i32, skin_color: u32) void {
    const eye = FPRect.fromInt(-1, -2, 2, 4);
    if (ly >= 0) {
        colorRGB(0);
        rect_(eye.translate(lx - (2 << fbits), ly));
        rect_(eye.translate(lx + (2 << fbits), ly));
    }
    colorRGB(skin_color);
    rect_(FPRect.init(0, 0, 0, 4 << fbits).expandInt(5));
}

pub fn cross(rc: FPRect) void {
    line(rc.x, rc.y, rc.r(), rc.b(), 1 << fbits, 1 << fbits);
    line(rc.x, rc.b(), rc.r(), rc.y, 1 << fbits, 1 << fbits);
}

pub fn crossWide(rc: FPRect) void {
    line(rc.x, rc.y, rc.r(), rc.b(), 4 << fbits, 2 << fbits);
    line(rc.x, rc.b(), rc.r(), rc.y, 3 << fbits, 4 << fbits);
}

pub fn deadHead(skin_color: u32) void {
    const eye = FPRect.fromInt(-1, -2, 2, 4);
    colorRGB(colors.black);
    cross(eye.translate(-(2 << fbits), 0));
    cross(eye.translate((2 << fbits), 0));
    colorRGB(skin_color);
    rect_(FPRect.init(0, 0, 0, 4 << fbits).expandInt(5));
}

pub fn knife(dist: i32, level: i32) void {
    if (level > 0) {
        colorRGB(0x333333);
        line(dist, 0, dist + (2 << fbits), 0, 2 << fbits, 2 << fbits);
        colorRGB(0x999999);
        line(dist + (2 << fbits), 0, dist + (10 << fbits), -2 << fbits, 2 << fbits, 3 << fbits);
    }
    if (level > 1) {
        colorRGB(0xDDDDDD);
        line(dist + (10 << fbits), -2 << fbits, dist + (14 << fbits), -5 << fbits, 3 << fbits, 2 << fbits);
    }
    if (level > 2) {
        colorRGB(colors.blood_dark);
        line(dist + (10 << fbits), 0 << fbits, dist + (14 << fbits), -1 << fbits, 8 << fbits, 8 << fbits);
    }
}

pub fn guardWeapon(dist: i32) void {
    colorRGB(0x220044);
    line(dist, 0, dist + (8 << fbits), 0, 2 << fbits, 4 << fbits);
}

pub fn hockeyMask(co: u32) void {
    colorRGB(colors.black);
    romb(-3 << fbits, -3 << fbits, 1 << fbits);
    romb(3 << fbits, 3 << fbits, 1 << fbits);
    romb(-3 << fbits, 3 << fbits, 1 << fbits);
    romb(3 << fbits, -3 << fbits, 1 << fbits);
    romb((-2 << fbits), 0, 1 << fbits);
    romb((2 << fbits), 0, 1 << fbits);
    romb(0, (-2 << fbits), 1 << fbits);
    romb(0, (2 << fbits), 1 << fbits);
    colorRGB(co);
    circle(0, 0, 6 << fbits, 7 << fbits, 10);
}

var prev_matrix: gain.math.Mat2d = undefined;

pub fn push(x: i32, y: i32, angle_tau: f32) void {
    prev_matrix = gfx.state.matrix;
    gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(x, y)).rotateUnit(angle_tau);
}

pub fn pushEx(x: i32, y: i32, angle_tau: f32, scale: f32) void {
    prev_matrix = gfx.state.matrix;
    gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(x, y)).scale(Vec2.splat(scale)).rotateUnit(angle_tau);
}

pub fn restore() void {
    gfx.state.matrix = prev_matrix;
}

pub fn trouses() void {
    line(
        0,
        -2 << fbits,
        0,
        2 << fbits,
        11 << fbits,
        0,
    );
}

pub fn shadow(x: i32, y: i32, sz: i32) void {
    color(colors.shadow);
    circle(x, y, sz, sz >> 1, 8);
}

pub fn color(c: u32) void {
    gfx.state.color = gain.math.Color32.fromARGB(c).abgr();
}

pub noinline fn colorRGB(c: u32) void {
    color(c | 0xFF000000);
}

pub noinline fn vertex(x: i32, y: i32) void {
    const xy = Vec2.fromIntegers(x, y).transform(gfx.state.matrix);
    gfx.state.vb[gain.gfx.state.vertex] = gfx.Vertex.init(
        xy.x,
        xy.y,
        @floatFromInt(gfx.state.z >> fbits),
        gfx.state.color,
    );
    gfx.state.vertex += 1;
}

pub noinline fn circle(x: i32, y: i32, rx: i32, ry: i32, segments: u32) void {
    if (segments < 3) return;
    gfx.requireTriangles(segments, 3 * (segments - 2));

    for (0..segments - 2) |i| {
        gfx.addIndex(0);
        gfx.addIndex(@truncate(i + 1));
        gfx.addIndex(@truncate(i + 2));
    }

    // const da = 1.0;
    for (0..segments) |i| {
        const a = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        vertex(
            fp32.sat_iif(x, rx, gain.math.costau(a)),
            fp32.sat_iif(y, ry, gain.math.sintau(a)),
        );
    }
}

pub noinline fn line(x0: i32, y0: i32, x1: i32, y1: i32, w1: i32, w2: i32) void {
    gfx.requireTriangles(4, 6);
    gfx.addQuadIndices();

    const a = gain.math.atan2(
        @floatFromInt(y1 - y0),
        @floatFromInt(x1 - x0),
    );
    const sn = gain.math.sin(a) / 2;
    const cs = gain.math.cos(a) / 2;
    const t2sina1 = fp32.scale(w1, sn);
    const t2cosa1 = fp32.scale(w1, cs);
    const t2sina2 = fp32.scale(w2, sn);
    const t2cosa2 = fp32.scale(w2, cs);

    vertex(x0 + t2sina1, y0 - t2cosa1);
    vertex(x1 + t2sina2, y1 - t2cosa2);
    vertex(x1 - t2sina2, y1 + t2cosa2);
    vertex(x0 - t2sina1, y0 + t2cosa1);
}

pub fn banner13() void {
    line(-2 << fbits, -4 << fbits, -2 << fbits, 4 << fbits, 1 << fbits, 0 << fbits);
    line(0 << fbits, -4 << fbits, 2 << fbits, -4 << fbits, 1 << fbits, 1 << fbits);
    line(2 << fbits, -4 << fbits, 0 << fbits, 0 << fbits, 1 << fbits, 1 << fbits);
    line(0 << fbits, 0 << fbits, 2 << fbits, 0 << fbits, 1 << fbits, 1 << fbits);
    line(2 << fbits, 0 << fbits, 0 << fbits, 4 << fbits, 1 << fbits, 0 << fbits);
}

pub fn bar(val: i32, max: i32, c: u32) void {
    const hw = max << 1;
    colorRGB(c);
    rect_(FPRect.fromInt(-hw + 1, -1, val << 2, 2));
    colorRGB(Color32.lerp8888b(0x0, c, 0x40));
    rect_(FPRect.fromInt(-hw + 1, -1, max << 2, 2));
    colorRGB(colors.black);
    rect_(FPRect.fromInt(-hw, -2, 2 + (max << 2), 4));
}

pub fn barUI(val: i32, max: i32, c: u32) void {
    colorRGB(c);
    rect_(FPRect.fromInt(2, -2, val << 2, 4));
    colorRGB(Color32.lerp8888b(0x0, c, 0x40));
    rect_(FPRect.fromInt(2, -2, max << 2, 4));
    colorRGB(colors.black);
    rect_(FPRect.fromInt(0, -4, 4 + (max << 2), 8));
}

pub fn attackCircle(x: i32, y: i32, t: i32) void {
    color(Color32.lerp8888b(0x00000000, 0xFFFFFFFF, @bitCast(t << 2)));
    circle(x, y, 24 << fbits, 16 << fbits, 32);
}
