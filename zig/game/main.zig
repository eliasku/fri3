const std = @import("std");
const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;
const AABB = @import("aabbi.zig");

const percision_bits = 8;
const Cell = u8;
const map_size_bits = 8;
const map_size = 1 << map_size_bits;
const map_size_mask = map_size - 1;
var map: [1 << (map_size_bits << 1)]Cell = undefined;
var level: u32 = 0;
var level_started = false;

const Hero = struct {
    x: i32,
    y: i32,
};

const Item = struct {
    x: i32,
    y: i32,
    kind: u8,
};

const camera_zoom = 1;
const screen_size = 512 << percision_bits;
const screen_size_half = screen_size >> 1;
const cell_size_bits = 5 + percision_bits;
const cell_size = 1 << cell_size_bits;
const cell_size_half = cell_size >> 1;
const hero_w = 10 << percision_bits;
const hero_h = 24 << percision_bits;
var hero_move_timer: u32 = undefined;
var hero_look_x: i32 = undefined;
var hero_look_y: i32 = undefined;
var hero: Hero = undefined;

var exit: AABB = undefined;

var items: [128]Item = undefined;
var items_num: u32 = undefined;

fn mapPtr(x: anytype, y: anytype) usize {
    const _x: usize = @intCast(x);
    const _y: usize = @intCast(y);
    return (_y << map_size_bits) + _x;
}

fn getMap(x: anytype, y: anytype) Cell {
    return map[mapPtr(x, y)];
}

fn setMap(x: anytype, y: anytype, v: Cell) void {
    map[mapPtr(x, y)] = v;
}

fn placeItem(x: i32, y: i32, kind: u8) void {
    items[items_num] = .{
        .x = cell_size_half + (x << cell_size_bits),
        .y = cell_size_half + (y << cell_size_bits),
        .kind = kind,
    };
    items_num += 1;
}

fn initLevel() void {
    var rnd = gain.math.Rnd{ .seed = 1 + (level << 5) };

    items_num = 0;
    var x: i32 = map_size >> 1;
    var y: i32 = map_size >> 1;
    var act: u32 = 0;
    var act_timer: u32 = 4;
    hero = Hero{
        .x = x << cell_size_bits,
        .y = y << cell_size_bits,
    };

    const iters = 100;
    for (0..iters) |_| {
        switch (act) {
            0 => if (x + 2 < map_size) {
                x += 1;
            } else {
                //act = 1;
            },
            1 => if (x > 1) {
                x -= 1;
            } else {
                //act = 0;
            },
            2 => if (y + 2 < map_size) {
                y += 1;
            } else {
                //act = 3;
            },
            3 => if (y > 1) {
                y -= 1;
            } else {
                //act = 2;
            },
            else => unreachable,
        }

        setMap(x, y, 1);
        setMap(x - 1, y, 1);
        setMap(x + 1, y, 1);
        setMap(x, y - 1, 1);
        setMap(x, y + 1, 1);

        act_timer -= 1;
        if (act_timer == 0) {
            act_timer = 4 + (rnd.next() & 7);
            const new_act = rnd.next() & 3;
            if (new_act != act) {
                act = new_act;
                placeItem(x, y, 1);
            }
        }
    }

    {
        const ex: i32 = (cell_size_half + (x << (cell_size_bits))) - (10 << percision_bits);
        const ey: i32 = (cell_size_half + (y << (cell_size_bits))) - (10 << percision_bits);
        exit = AABB.init(ex, ey, 20 << percision_bits, 20 << percision_bits);
    }
}

pub fn update() void {
    if (!level_started) {
        initLevel();
        level_started = true;
        return;
    }

    const keys = gain.keyboard;

    // 5190
    var vx: i32 = 0;
    if ((keys.down[keys.Code.a] | keys.down[keys.Code.arrow_left]) != 0) {
        vx -= 1;
    }
    if ((keys.down[keys.Code.d] | keys.down[keys.Code.arrow_right]) != 0) {
        vx += 1;
    }
    var vy: i32 = 0;
    if ((keys.down[keys.Code.w] | keys.down[keys.Code.arrow_up]) != 0) {
        vy -= 1;
    }
    if ((keys.down[keys.Code.s] | keys.down[keys.Code.arrow_down]) != 0) {
        vy += 1;
    }

    // 5208
    // var vx: i32 = 0;
    // var vy: i32 = 0;
    // vy -= keys.down[keys.Code.w] | keys.down[keys.Code.arrow_up];
    // vy += keys.down[keys.Code.s] | keys.down[keys.Code.arrow_down];
    // vx -= keys.down[keys.Code.a] | keys.down[keys.Code.arrow_left];
    // vx += keys.down[keys.Code.d] | keys.down[keys.Code.arrow_right];

    // 5209
    // const vx: i32 = @as(i32, (keys.down[keys.Code.d] | keys.down[keys.Code.arrow_right])) - @as(i32, (keys.down[keys.Code.a] | keys.down[keys.Code.arrow_left]));
    // const vy: i32 = @as(i32, (keys.down[keys.Code.s] | keys.down[keys.Code.arrow_down])) - @as(i32, (keys.down[keys.Code.w] | keys.down[keys.Code.arrow_up]));

    if (vx != 0 or vy != 0) {
        hero_move_timer +%= 1;
        hero_look_x = vx << percision_bits;
        hero_look_y = vy << percision_bits;
    } else {
        hero_move_timer = 0;
    }

    var speed: i32 = 1 << percision_bits;
    if (vx != 0 and vy != 0) {
        speed = 0xB4;
    }
    //if (hero_move_timer > 16) speed <<= 1;

    const sh = cell_size_bits;
    var new_x = @max(hero.x + vx * speed, 0);
    var new_y = @max(hero.y + vy * speed, 0);
    if (new_x < hero.x) {
        const cx = new_x >> sh;
        const cy = (hero.y + hero_h) >> sh;
        if (getMap(cx, cy) == 0) {
            new_x = (cx + 1) << sh;
        }
    }
    if (new_x > hero.x) {
        const cx = (new_x + hero_w) >> sh;
        const cy = (hero.y + hero_h) >> sh;
        if (getMap(cx, cy) == 0) {
            new_x = (cx << sh) - (hero_w);
        }
    }
    if (new_y < hero.y) {
        const cx = hero.x >> sh;
        const cy = (new_y + (hero_h - 2)) >> sh;
        if (getMap(cx, cy) == 0) {
            new_y = ((cy + 1) << sh) - (hero_h - 2);
        }
    }
    if (new_y > hero.y) {
        const cx = hero.x >> sh;
        const cy = (new_y + (hero_h)) >> sh;
        if (getMap(cx, cy) == 0) {
            new_y = (cy << sh) - hero_h - 1;
        }
    }
    hero.x = new_x;
    hero.y = new_y;

    {
        const hero_aabb = AABB.init(hero.x, hero.y, hero_w, hero_h);
        for (0..items_num) |i| {
            const item = items[i];
            if (item.kind != 0) {
                const v = AABB.init(item.x - 8, item.y - 8, 16, 16);
                if (hero_aabb.check(v)) {
                    items[i].kind = 0;
                }
            }
        }

        if (exit.check(hero_aabb)) {
            level += 1;
            level_started = false;
        }
    }
}

fn invDist(x: i32, y: i32, x1: i32, y1: i32) i32 {
    const distance = 256 << percision_bits;
    const dx: f32 = @floatFromInt(x - x1);
    const dy: f32 = @floatFromInt(y - y1);
    const d = @max(distance - @sqrt(dx * dx + dy * dy), 0) / distance;
    return @intFromFloat(@sqrt(@sqrt(d)) * cell_size_half);
}

fn drawQuad(x: i32, y: i32, w: i32, h: i32, color: u32) void {
    gfx.quad(Vec2.fromIntegers(x, y), Vec2.fromIntegers(w, h), color);
}

fn getHeroOffY() i32 {
    return @intCast((((hero_move_timer & 31) + 7) >> 4) << percision_bits);
}

fn drawHero() void {
    const x = hero.x;
    const y = hero.y;
    const hero_y_off = getHeroOffY();

    // eyes
    if (hero_look_y >= 0) {
        drawQuad(hero_look_x + x + (2 << percision_bits), hero_look_y + y + (4 << percision_bits) - (hero_y_off >> 1), 2 << percision_bits, 4 << percision_bits, 0xFF000000);
        drawQuad(hero_look_x + x + hero_w - (4 << percision_bits), hero_look_y + y + (4 << percision_bits) - (hero_y_off >> 1), 2 << percision_bits, 4 << percision_bits, 0xFF000000);
    }

    drawQuad(x, y - hero_y_off, hero_w, hero_h - hero_y_off - (2 << percision_bits), 0xFFFFFFFF);

    drawQuad(x - (2 << percision_bits), y + (10 << percision_bits) - hero_y_off, 2 << percision_bits, 8 << percision_bits, 0xFFFFFFFF);
    drawQuad(x + hero_w, y + (10 << percision_bits) - hero_y_off, 2 << percision_bits, 8 << percision_bits, 0xFFFFFFFF);

    drawQuad(x, y - (hero_y_off << 1) + (hero_h - (2 << percision_bits)), 4 << percision_bits, 2 << percision_bits, 0xFFFFFFFF);
    drawQuad(x + (6 << percision_bits), y - (hero_y_off << 1) + (hero_h - (2 << percision_bits)), 4 << percision_bits, 2 << percision_bits, 0xFFFFFFFF);
}

fn drawHeroShadow() void {
    const x = hero.x;
    const y = hero.y;
    const hero_y_off = getHeroOffY() >> percision_bits;
    drawQuad(x - (1 << percision_bits), y + hero_h - (2 << percision_bits), hero_w + (2 << percision_bits), (3 << percision_bits), @as(u32, @intCast(0x44 - 0x20 * hero_y_off)) << 24);
}

fn drawExit() void {
    const x = exit.minx;
    const y = exit.miny;
    const w = exit.w();
    const h = exit.h();
    drawQuad(x, y, w, h, 0xFFFFFFFF);
    drawQuad(x - (2 << percision_bits), y - (2 << percision_bits), w + (4 << percision_bits), h + (4 << percision_bits), 0xFFFFBB66);
}

fn drawItem(i: usize) void {
    const item = items[i];
    const x = item.x;
    const y = item.y;
    if (item.kind != 0) {
        drawQuad(x - (4 << percision_bits), y - (4 << percision_bits), 8 << percision_bits, 8 << percision_bits, 0xFF00FF00);
        drawQuad(x - (6 << percision_bits), y - (6 << percision_bits), 12 << percision_bits, 12 << percision_bits, 0xFF444444);
    }
}

pub fn render() void {
    gfx.setupOpaquePass();
    gfx.state.matrix = Mat2d.identity();
    gfx.setTexture(0);
    gfx.state.z = 4;

    {
        const cx = hero.x;
        const cy = hero.y;
        const short_side = @min(app.w, app.h);
        const scale = @as(f32, @floatFromInt(short_side)) / (screen_size * camera_zoom);
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(app.w, app.h).scale(0.5));
        gfx.state.matrix = gfx.state.matrix.scale(Vec2.splat(scale));
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(cx + hero_w / 2, cy + hero_h / 2).neg());
    }

    const camera_aabb = AABB.init(
        hero.x - screen_size_half,
        hero.y - screen_size_half,
        screen_size,
        screen_size,
    );

    drawHero();

    drawExit();

    for (0..items_num) |i| {
        const item = items[i];
        if (item.kind != 0 and
            AABB.init(item.x - (4 << percision_bits), item.y - (4 << percision_bits), (8 << percision_bits), (8 << percision_bits)).check(camera_aabb))
        {
            drawItem(i);
        }
    }

    gfx.state.z = 2;

    {
        const cx0 = camera_aabb.minx >> cell_size_bits;
        const cy0 = camera_aabb.miny >> cell_size_bits;
        const cx1 = (camera_aabb.maxx >> cell_size_bits) + 2;
        const cy1 = (camera_aabb.maxy >> cell_size_bits) + 2;
        const ccx0: usize = @intCast(@max(0, cx0));
        const ccx1: usize = @intCast(@max(0, cx1));
        const ccy0: usize = @intCast(@max(0, cy0));
        const ccy1: usize = @intCast(@max(0, cy1));

        const matrix = gfx.state.matrix;
        for (ccy0..ccy1) |cy| {
            for (ccx0..ccx1) |cx| {
                const cell = map[cy * map_size + cx];
                if (cell == 1) {
                    const x: i32 = @intCast((cx << cell_size_bits) + cell_size_half);
                    const y: i32 = @intCast((cy << cell_size_bits) + cell_size_half);
                    var sz: i32 = @min(invDist(hero.x, hero.y, x, y), 1 << cell_size_bits);
                    sz += (@as(i32, @intCast((app.tic >> 3) + (cx *% cy))) & 7) >> 2;
                    const cell_size_v = Vec2.fromIntegers(sz << 1, sz << 1);
                    gfx.state.matrix = matrix
                        .translate(Vec2.fromIntegers(x, y))
                        .rotate(std.math.pi * (1 - @as(f32, @floatFromInt(sz)) / (cell_size_half)));
                    gfx.quad(Vec2.fromIntegers(-sz, -sz), cell_size_v, 0xFF338866);
                }
            }
        }
        gfx.state.matrix = matrix;
    }
    gfx.state.z = 1;
    drawQuad(0, 0, map_size << cell_size_bits, map_size << cell_size_bits, 0xFF222222);
    gfx.state.z = 0;
    drawQuad(-1024, -1024, 2048 + (map_size << cell_size_bits), 2048 + (map_size << cell_size_bits), 0xFF000000);

    gfx.setupBlendPass();
    gfx.state.z = 3;
    drawHeroShadow();
}
