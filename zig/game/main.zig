const std = @import("std");
const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;
const AABB = @import("aabbi.zig");

const map_size_bits = 8;
const map_size = 1 << map_size_bits;
const map_size_mask = map_size - 1;
var map: [1 << (map_size_bits << 1)]u8 = undefined;
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
const cell_size_shift = 5;
const cell_size_half = 1 << (cell_size_shift - 1);
const hero_w = 10;
const hero_h = 24;
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

fn getMap(x: anytype, y: anytype) u8 {
    return map[mapPtr(x, y)];
}

fn setMap(x: anytype, y: anytype, v: u8) void {
    map[mapPtr(x, y)] = v;
}

fn placeItem(x: u32, y: u32, kind: u8) void {
    items[items_num] = .{
        .x = @intCast(cell_size_half + (x << (cell_size_shift))),
        .y = @intCast(cell_size_half + (y << (cell_size_shift))),
        .kind = kind,
    };
    items_num += 1;
}

fn initLevel() void {
    var rnd = gain.math.Rnd{ .seed = 10 + (level << 5) };

    items_num = 0;
    var x: u32 = map_size >> 1;
    var y: u32 = map_size >> 1;
    var act: u32 = 0;
    var act_timer: u32 = 4;
    hero = Hero{ .x = @intCast(x << (cell_size_shift)), .y = @intCast(y << (cell_size_shift)) };

    //map = std.mem.zeroes(@TypeOf(map));
    const iters = 1000;
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
        const ex: i32 = @intCast((cell_size_half + (x << (cell_size_shift))) - 10);
        const ey: i32 = @intCast((cell_size_half + (y << (cell_size_shift))) - 10);
        exit = AABB.init(ex, ey, 20, 20);
    }
}

pub fn update() void {
    if (!level_started) {
        initLevel();
        level_started = true;
        return;
    }

    const keys = gain.keyboard;

    var vx: i32 = 0;
    var vy: i32 = 0;
    if (keys.down[keys.Code.w] != 0) {
        vy -= 1;
    }
    if (keys.down[keys.Code.s] != 0) {
        vy += 1;
    }
    if (keys.down[keys.Code.a] != 0) {
        vx -= 1;
    }
    if (keys.down[keys.Code.d] != 0) {
        vx += 1;
    }
    if (vx != 0 or vy != 0) {
        hero_move_timer +%= 1;
        hero_look_x = vx;
        hero_look_y = vy;
    } else {
        hero_move_timer = 0;
    }

    var speed: i32 = 4;
    if (vx != 0 and vy != 0) {
        speed = 3;
    }
    //if (hero_move_timer > 16) speed <<= 1;

    const sh = cell_size_shift;
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

fn drawHero() void {
    const x = hero.x;
    const y = hero.y;
    const hero_y_off: i32 = @intCast((hero_move_timer % 32 + 8) / 16);
    gfx.quad(Vec2.fromIntegers(hero_look_x + x + 2, hero_look_y + y + 4 - (hero_y_off >> 1)), Vec2.fromIntegers(2, 4), 0xFF000000);
    gfx.quad(Vec2.fromIntegers(hero_look_x + x + hero_w - 4, hero_look_y + y + 4 - (hero_y_off >> 1)), Vec2.fromIntegers(2, 4), 0xFF000000);
    gfx.quad(Vec2.fromIntegers(x, y - hero_y_off), Vec2.fromIntegers(hero_w, hero_h - hero_y_off - 2), 0xFFFFFFFF);

    gfx.quad(Vec2.fromIntegers(x - 2, y + 10 - hero_y_off), Vec2.fromIntegers(2, 8), 0xFFFFFFFF);
    gfx.quad(Vec2.fromIntegers(x + hero_w, y + 10 - hero_y_off), Vec2.fromIntegers(2, 8), 0xFFFFFFFF);

    gfx.quad(Vec2.fromIntegers(x, y - hero_y_off * 2 + (hero_h - 2)), Vec2.fromIntegers(4, 2), 0xFFFFFFFF);
    gfx.quad(Vec2.fromIntegers(x + 6, y - hero_y_off * 2 + (hero_h - 2)), Vec2.fromIntegers(4, 2), 0xFFFFFFFF);
}

fn drawHeroShadow() void {
    const x = hero.x;
    const y = hero.y;
    const hero_y_off: i32 = @intCast((hero_move_timer % 32 + 8) / 16);
    gfx.quad(Vec2.fromIntegers(x - 1, y + hero_h - 2), Vec2.init(hero_w + 2, 3), @as(u32, @intCast(0x44 - hero_y_off * 20)) << 24);
}

fn drawExit() void {
    const x = exit.minx;
    const y = exit.miny;
    const w = exit.widthf();
    const h = exit.heightf();
    gfx.quad(Vec2.fromIntegers(x, y), Vec2.init(w, h), 0xFFFFFFFF);
    gfx.quad(Vec2.fromIntegers(x - 2, y - 2), Vec2.init(w + 4, h + 4), 0xFFFFBB66);
}

fn drawItem(i: usize) void {
    const item = items[i];
    const x = item.x;
    const y = item.y;
    if (item.kind != 0) {
        gfx.quad(Vec2.fromIntegers(x - 4, y - 4), Vec2.init(8, 8), 0xFF00FF00);
        gfx.quad(Vec2.fromIntegers(x - 6, y - 6), Vec2.init(12, 12), 0xFF444444);
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
        const scale = @as(f32, @floatFromInt(short_side)) / (512 * camera_zoom);
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(app.w, app.h).scale(0.5));
        gfx.state.matrix = gfx.state.matrix.scale(Vec2.splat(scale));
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(cx + hero_w / 2, cy + hero_h / 2).neg());
    }

    drawHero();

    drawExit();

    for (0..items_num) |i| {
        drawItem(i);
    }

    gfx.state.z = 2;
    for (0..map_size) |cy| {
        for (0..map_size) |cx| {
            const cell = map[cy * map_size + cx];
            if (cell == 1) {
                const x = cx << cell_size_shift;
                const y = cy << cell_size_shift;
                const cell_size = Vec2.fromIntegers(1 << cell_size_shift, 1 << cell_size_shift);
                gfx.quad(Vec2.fromIntegers(x, y), cell_size, 0xFF338866);
            }
        }
    }

    gfx.state.z = 1;
    gfx.quad(Vec2.init(0, 0), Vec2.fromIntegers(map_size << cell_size_shift, map_size << cell_size_shift), 0xFF222222);
    gfx.state.z = 0;
    gfx.quad(Vec2.init(-1024, -1024), Vec2.fromIntegers(2048 + (map_size << cell_size_shift), 2048 + (map_size << cell_size_shift)), 0xFF000000);

    gfx.setupBlendPass();
    gfx.state.z = 3;
    drawHeroShadow();
}
