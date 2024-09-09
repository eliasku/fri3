const Mat2d = @import("../math/Mat2d.zig");
const Vec2 = @import("../math/Vec2.zig");
pub const Vertex = @import("Vertex.zig");
const Color32 = @import("../math/Color32.zig");
const js = @import("../js.zig");
const std = @import("std");
const mathf = @import("../math/functions.zig");
const sin = mathf.sin;
const cos = mathf.cos;
const atan2 = mathf.atan2;
const vertices_max = 0x10000;
const indices_max = 0x20000;

const State = struct {
    z: i32 = undefined,
    matrix: Mat2d = undefined,
    color: u32 = undefined,
    buffer: u32 = 0,
    index: u32 = 0,
    buffer_handle_frame_counter: u32 = 0,
    vertex: u16 = 0,
    ib: [indices_max]u16 = undefined,
    vb: [vertices_max]Vertex = undefined,
};

pub var state: State = State{};

pub fn pushTransformedVertex2D(pos: Vec2, color: u32) void {
    const xy = pos.transform(state.matrix);
    state.vb[state.vertex] = Vertex.init(
        xy.x,
        xy.y,
        @floatFromInt(state.z),
        Color32.fromARGB(color).abgr(),
    );
    state.vertex +%= 1;
}

pub fn addIndex(index: u16) void {
    writeRawIndex(state.vertex + index);
}

pub fn writeRawIndex(index: u16) void {
    std.debug.assert(state.index < indices_max);
    std.debug.assert(index < vertices_max);
    state.ib[state.index] = index;
    state.index += 1;
}

pub fn addQuadIndices() void {
    for ([6]u8{ 0, 1, 2, 0, 2, 3 }) |index| {
        addIndex(index);
    }
}

pub fn beginFrame() void {
    // reset dynamic buffer handles every 3rd frame
    if (state.buffer_handle_frame_counter > 2) {
        state.buffer_handle_frame_counter = 0;
        state.buffer = 0;
    }
    state.buffer_handle_frame_counter +%= 1;
}

pub inline fn endFrame() void {
    flush();
}

pub noinline fn requireTriangles(vertices: u32, indices: u32) void {
    if (state.vertex + vertices >= vertices_max or state.index + indices >= indices_max) {
        flush();
    }
}

pub fn flush() void {
    if (state.index != 0) {
        if (js.enabled) {
            js.drawTriangles(std.mem.asBytes(&state.vb), @as(u32, state.vertex) * @sizeOf(Vertex), &state.ib, state.index, state.buffer);
        }
        state.buffer += 2;
        state.vertex = 0;
        state.index = 0;
    }
}

pub fn setupOpaquePass() void {
    flush();
    if (js.enabled) {
        js.setupPass(0);
    }
}

pub fn setupBlendPass() void {
    flush();
    if (js.enabled) {
        js.setupPass(1);
    }
}

pub fn quad(pos: Vec2, size: Vec2, color: u32) void {
    requireTriangles(4, 6);
    addQuadIndices();
    pushTransformedVertex2D(pos, color);
    pushTransformedVertex2D(.{ .x = pos.x + size.x, .y = pos.y }, color);
    pushTransformedVertex2D(pos.add(size), color);
    pushTransformedVertex2D(.{ .x = pos.x, .y = pos.y + size.y }, color);
}

pub fn quadColors(pos: Vec2, size: Vec2, colors: [4]u32) void {
    requireTriangles(4, 6);
    addQuadIndices();
    pushTransformedVertex2D(pos, colors[0]);
    pushTransformedVertex2D(.{ .x = pos.x + size.x, .y = pos.y }, colors[1]);
    pushTransformedVertex2D(pos.add(size), colors[2]);
    pushTransformedVertex2D(.{ .x = pos.x, .y = pos.y + size.y }, colors[3]);
}

// fill circle, generate geometry from center (uneffective, for radial gradient)
pub fn fillCircleEx(center: Vec2, radius: Vec2, segments: u32, outer_color: u32, inner_color: u32) void {
    if (segments < 3) return;

    requireTriangles(1 + segments, 3 * segments);

    for (0..segments - 1) |i| {
        addIndex(0);
        addIndex(@truncate(i + 1));
        addIndex(@truncate(i + 2));
    }
    addIndex(0);
    addIndex(@truncate(segments));
    addIndex(1);

    pushTransformedVertex2D(center, Vec2.zero(), inner_color);

    for (0..segments) |i| {
        const a = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        pushTransformedVertex2D(Vec2.init(
            center.x + radius.x * mathf.costau(a),
            center.y + radius.y * mathf.sintau(a),
        ), outer_color);
    }
}

pub fn fillCircle(center: Vec2, radius: Vec2, segments: u32, color: u32) void {
    if (segments < 3) return;

    requireTriangles(segments, 3 * (segments - 2));

    for (0..segments - 2) |i| {
        addIndex(0);
        addIndex(@truncate(i + 1));
        addIndex(@truncate(i + 2));
    }

    // const da = 1.0;
    for (0..segments) |i| {
        const a = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segments));
        pushTransformedVertex2D(Vec2.init(
            center.x + radius.x * mathf.costau(a),
            center.y + radius.y * mathf.sintau(a),
        ), color);
    }
}

pub fn fillRing(center: Vec2, r0: f32, r1: f32, color: u32) void {
    const n = @import("../math/main.zig").getCircleSegments(r1);
    if (n < 3) return;

    if (r0 < 0.1) {
        fillCircle(center, Vec2.splat(r1), n, color);
        return;
    }

    for (0..(n - 1)) |i| {
        const j = i << 1;
        addIndex(j);
        addIndex(j + 1);
        addIndex(j + 2);
        addIndex(j + 2);
        addIndex(j + 1);
        addIndex(j + 3);
    }
    {
        const j = (n - 1) << 1;
        addIndex(j);
        addIndex(j + 1);
        addIndex(0);
        addIndex(0);
        addIndex(j + 1);
        addIndex(1);
    }

    const da = std.math.tau / @as(f32, @floatFromInt(n));
    for (0..n) |i| {
        const a = da * @as(f32, @floatFromInt(i));
        const unit = Vec2.initDir(a);
        pushTransformedVertex2D(center.add(unit.scale(r0)), color);
        pushTransformedVertex2D(center.add(unit.scale(r1)), color);
    }
}

pub fn fillTriangle(positions: [3]Vec2, color: u32) void {
    requireTriangles(3, 3);
    addIndex(0);
    addIndex(1);
    addIndex(2);
    pushTransformedVertex2D(positions[0], color);
    pushTransformedVertex2D(positions[1], color);
    pushTransformedVertex2D(positions[2], color);
}

pub fn lineQuad(start: Vec2, end: Vec2, color1: u32, color2: u32, width1: f32, width2: f32) void {
    requireTriangles(4, 6);
    addQuadIndices();

    const angle = atan2(end.y - start.y, end.x - start.x);
    const sn = 0.5 * sin(angle);
    const cs = 0.5 * cos(angle);
    const t2sina1 = sn * width1;
    const t2cosa1 = cs * width1;
    const t2sina2 = sn * width2;
    const t2cosa2 = cs * width2;

    //const color_t m1 = mul_color(canvas.color[0].scale, color1);
    //const color_t m2 = mul_color(canvas.color[0].scale, color2);
    const m1 = color1;
    const m2 = color2;
    //const color_t co = canvas.color[0].offset;

    pushTransformedVertex2D(Vec2.init(start.x + t2sina1, start.y - t2cosa1), m1);
    pushTransformedVertex2D(Vec2.init(end.x + t2sina2, end.y - t2cosa2), m2);
    pushTransformedVertex2D(Vec2.init(end.x - t2sina2, end.y + t2cosa2), m2);
    pushTransformedVertex2D(Vec2.init(start.x - t2sina1, start.y + t2cosa1), m1);
}
