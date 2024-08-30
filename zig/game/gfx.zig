const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");

const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const fbits = fp32.fbits;

pub fn quad(x: i32, y: i32, w: i32, h: i32, c: u32) void {
    gfx.requireTriangles(4, 6);
    gfx.addQuadIndices();
    //gfx.quad(Vec2.fromIntegers(x, y), Vec2.fromIntegers(w, h), c);
    color(c);
    vertex(x, y);
    vertex(x + w, y);
    vertex(x + w, y + h);
    vertex(x, y + h);
}

pub fn rect(rc: FPRect, c: u32) void {
    quad(rc.x, rc.y, rc.w, rc.h, c);
}

pub fn depth(x: i32, y: i32) void {
    _ = x;
    gfx.state.z = @floatFromInt(y >> fp32.fbits);
}

pub fn attention(x: i32, y: i32) void {
    color(0xFF000000);
    circle(x, y, 2 << fbits, 2 << fbits, 8);
    color(0xFFFFFFFF);
    circle(x, y, 6 << fbits, 2 << fbits, 6);
}

pub fn scream(x: i32, y: i32) void {
    line(x + (2 << fp32.fbits), y + (-2 << fp32.fbits), x + (8 << fp32.fbits), y + (-8 << fp32.fbits), 0xFF000000, 0xFF000000, 0, 2 << fp32.fbits);
    line(x + (2 << fp32.fbits), y + (0 << fp32.fbits), x + (10 << fp32.fbits), y + (-4 << fp32.fbits), 0xFF000000, 0xFF000000, 0, 2 << fp32.fbits);
    line(x + (0 << fp32.fbits), y + (-2 << fp32.fbits), x + (4 << fp32.fbits), y + (-10 << fp32.fbits), 0xFF000000, 0xFF000000, 0, 2 << fp32.fbits);
}

pub fn head(x: i32, y: i32, lx: i32, ly: i32, skin_color: u32, hair: u32, eye_color: u32, angle: i32) void {
    const eye = FPRect.fromInt(-1, -2, 2, 4);
    if (ly >= 0) {
        rect(eye.translate(x + lx - (2 << fbits), y + ly), eye_color);
        rect(eye.translate(x + lx + (2 << fbits), y + ly), eye_color);
    }
    rect(FPRect.init(x, y, 0, 4 << fbits).expandInt(5), skin_color);
    // rect(FPRect.init(x, y - (1 << fbits), 0, 4 << fbits).expandInt(5), 0xFF666600);
    _ = hair;
    _ = angle;
}

pub fn knife(x: i32, y: i32, angle: i32) void {
    const m = gain.gfx.state.matrix;
    gfx.state.matrix = gain.gfx.state.matrix.translate(Vec2.fromIntegers(x, y)).rotate(fp32.toFloat(angle));
    line(0, 0, (2 << fbits), 0, 0xFF888888, 0xFF666666, 2 << fbits, 2 << fbits);
    line((2 << fbits), 0, (10 << fbits), -2 << fbits, 0xFFFFFFFF, 0xFF999999, 2 << fbits, 3 << fbits);
    line((10 << fbits), -2 << fbits, (14 << fbits), -5 << fbits, 0xFF999999, 0xFF999999, 3 << fbits, 2 << fbits);
    gfx.state.matrix = m;
}

var prev_matrix: gain.math.Mat2d = undefined;

pub fn push(x: i32, y: i32, angle: i32) void {
    prev_matrix = gfx.state.matrix;
    gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(x, y)).rotate(fp32.toFloat(angle));
}

pub fn restore() void {
    gfx.state.matrix = prev_matrix;
}

pub fn trouses(c: u32) void {
    line(
        0,
        -2 << fbits,
        0,
        2 << fbits,
        c,
        c,
        11 << fbits,
        0,
    );
}

pub fn shadow(x: i32, y: i32, sz: i32, c: u32) void {
    color(c);
    circle(x, y, sz, sz >> 1, 8);
}

pub fn color(c: u32) void {
    gfx.state.color = gain.math.Color32.fromARGB(c).abgr();
}

pub fn vertex(x: i32, y: i32) void {
    const xy = Vec2.fromIntegers(x, y).transform(gfx.state.matrix);
    gfx.state.vb[gain.gfx.state.vertex] = gfx.Vertex.init(
        xy.x,
        xy.y,
        gfx.state.z,
        gfx.state.color,
    );
    gfx.state.vertex += 1;
}

pub fn circle(x: i32, y: i32, rx: i32, ry: i32, segments: u32) void {
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

pub fn line(x0: i32, y0: i32, x1: i32, y1: i32, color1: u32, color2: u32, w1: i32, w2: i32) void {
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

    color(color1);
    vertex(x0 + t2sina1, y0 - t2cosa1);
    color(color2);
    vertex(x1 + t2sina2, y1 - t2cosa2);
    vertex(x1 - t2sina2, y1 + t2cosa2);
    color(color1);
    vertex(x0 - t2sina1, y0 + t2cosa1);
}
