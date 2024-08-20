const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;

const map_size = 128;
var map: [map_size * map_size]u8 = undefined;
var map_inited = false;

const Hero = struct {
    x: i32,
    y: i32,
};

const camera_zoom = 1;
const cell_size_shift = 6;
const hero_w = 10;
const hero_h = 24;
var hero_move_timer: u32 = undefined;
var hero_look_x: i32 = undefined;
var hero_look_y: i32 = undefined;
var hero: Hero = undefined;

fn initLevel() void {
    const Rnd = gain.math.Rnd;
    var rnd = Rnd{ .seed = 0 };

    var x: u32 = rnd.next() % map_size;
    var y: u32 = rnd.next() % map_size;

    hero = Hero{ .x = @intCast(x << cell_size_shift), .y = @intCast(y << cell_size_shift) };

    for (0..5000) |_| {
        map[y * map_size + x] = 1;
        const r = rnd.next() % 4;
        if (r == 0 and x + 1 < map_size) {
            x += 1;
        } else if (r == 1 and x > 0) {
            x -= 1;
        } else if (r == 2 and y + 1 < map_size) {
            y += 1;
        } else if (r == 3 and y > 0) {
            y -= 1;
        }

        //if (x < 0) x = 0;
        //if (y < 0) y = 0;
        // x %= map_size;
        // y %= map_size;
    }

    //const std = @import("std");
    // for (0..map_size) |cy| {
    //     for (0..map_size) |cx| {
    //         map[cy * map_size + cx] = @truncate(rnd.next() % 2);
    //     }
    // }
}

pub fn update() void {
    if (!map_inited) {
        initLevel();
        map_inited = true;
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

    var new_x = hero.x + vx * speed;
    var new_y = hero.y + vy * speed;
    if (new_x < hero.x) {
        const cx = new_x >> cell_size_shift;
        const cy = (hero.y + hero_h) >> cell_size_shift;
        if (map[@intCast(cy * map_size + cx)] == 0) {
            new_x = (cx + 1) << cell_size_shift;
        }
    }
    if (new_x > hero.x) {
        const cx = (new_x + hero_w) >> cell_size_shift;
        const cy = (hero.y + hero_h) >> cell_size_shift;
        if (map[@intCast(cy * map_size + cx)] == 0) {
            new_x = (cx << cell_size_shift) - hero_w;
        }
    }
    if (new_y < hero.y) {
        const cx = hero.x >> cell_size_shift;
        const cy = (new_y + (hero_h - 2)) >> cell_size_shift;
        if (map[@intCast(cy * map_size + cx)] == 0) {
            new_y = ((cy + 1) << cell_size_shift) - (hero_h - 2);
        }
    }
    if (new_y > hero.y) {
        const cx = hero.x >> cell_size_shift;
        const cy = (new_y + hero_h) >> cell_size_shift;
        if (map[@intCast(cy * map_size + cx)] == 0) {
            new_y = (cy << cell_size_shift) - hero_h - 1;
        }
    }
    hero.x = new_x;
    hero.y = new_y;
}

pub fn render() void {
    gfx.setupOpaquePass();
    gfx.state.matrix = Mat2d.identity();
    gfx.setTexture(0);
    gfx.state.z = 4;

    {
        const short_side = @min(app.w, app.h);
        const scale = @as(f32, @floatFromInt(short_side)) / (512 * camera_zoom);
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(app.w, app.h).scale(0.5));
        gfx.state.matrix = gfx.state.matrix.scale(Vec2.splat(scale));
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(hero.x + hero_w / 2, hero.y + hero_h / 2).neg());
    }

    const hero_y_off: i32 = @intCast((hero_move_timer % 32 + 8) / 16);
    gfx.quad(Vec2.fromIntegers(hero_look_x + hero.x + 2, hero_look_y + hero.y + 4 - (hero_y_off >> 1)), Vec2.fromIntegers(2, 4), 0xFF000000);
    gfx.quad(Vec2.fromIntegers(hero_look_x + hero.x + hero_w - 4, hero_look_y + hero.y + 4 - (hero_y_off >> 1)), Vec2.fromIntegers(2, 4), 0xFF000000);
    gfx.quad(Vec2.fromIntegers(hero.x, hero.y - hero_y_off), Vec2.fromIntegers(hero_w, hero_h - hero_y_off - 2), 0xFFFFFFFF);

    gfx.quad(Vec2.fromIntegers(hero.x - 2, hero.y + 10 - hero_y_off), Vec2.fromIntegers(2, 8), 0xFFFFFFFF);
    gfx.quad(Vec2.fromIntegers(hero.x + hero_w, hero.y + 10 - hero_y_off), Vec2.fromIntegers(2, 8), 0xFFFFFFFF);

    gfx.quad(Vec2.fromIntegers(hero.x, hero.y - hero_y_off * 2 + (hero_h - 2)), Vec2.fromIntegers(4, 2), 0xFFFFFFFF);
    gfx.quad(Vec2.fromIntegers(hero.x + 6, hero.y - hero_y_off * 2 + (hero_h - 2)), Vec2.fromIntegers(4, 2), 0xFFFFFFFF);

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

    gfx.setupBlendPass();
    gfx.state.z = 3;
    gfx.quad(Vec2.fromIntegers(hero.x - 1, hero.y + hero_h - 2), Vec2.init(hero_w + 2, 3), @as(u32, @intCast(0x44 - hero_y_off * 20)) << 24);
}
