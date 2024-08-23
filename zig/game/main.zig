const std = @import("std");
const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;
const FPRect = @import("FPRect.zig");
const fp32 = @import("fp32.zig");

const Hero = struct {
    x: i32,
    y: i32,
};

const Item = struct {
    x: i32,
    y: i32,
    kind: u8,
};

const fbits = fp32.fbits;
const Cell = u8;
const map_size_bits = 8;
const map_size = 1 << map_size_bits;
const map_size_mask = map_size - 1;
var map: [1 << (map_size_bits << 1)]Cell = undefined;
var level: u32 = 0;
var level_started = false;
const camera_zoom = 1;
const screen_size = 512 << fbits;
const screen_size_half = screen_size >> 1;
const cell_size_bits = 5 + fbits;
const cell_size = 1 << cell_size_bits;
const cell_size_half = cell_size >> 1;

const hero_w = 10 << fbits;
const hero_h = 24 << fbits;
const hero_place_w = 12 << fbits;
const hero_place_h = 4 << fbits;
var hero_move_timer: u32 = undefined;
var hero_look_x: i32 = undefined;
var hero_look_y: i32 = undefined;
var hero: Hero = undefined;
var hero_aabb_local = FPRect.init(-(hero_w >> 1), -hero_h, hero_w, hero_h);
var hero_ground_aabb_local = FPRect.init(-(hero_place_w >> 1), -(hero_place_h >> 1), hero_place_w, hero_place_h);

var exit: FPRect = undefined;

const Mob = struct {
    x: i32,
    y: i32,
    kind: u8,
};

var mobs: [128]Mob = undefined;
var mobs_num: u32 = undefined;
const mob_hitbox_local = FPRect.fromInt(
    -10,
    -4,
    20,
    4,
);

const mob_quad_local = FPRect.fromInt(
    -10,
    -30,
    20,
    30,
);

const item_aabb = FPRect.fromInt(
    -10,
    -10,
    20,
    20,
);

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

fn placeMob(x: i32, y: i32, kind: u8) void {
    mobs[mobs_num] = .{
        .x = cell_size_half + (x << cell_size_bits),
        .y = cell_size_half + (y << cell_size_bits),
        .kind = kind,
    };
    mobs_num += 1;
}

fn initLevel() void {
    var rnd = gain.math.Rnd{ .seed = 1 + (level << 5) };

    items_num = 0;
    mobs_num = 0;
    var x: i32 = map_size >> 1;
    var y: i32 = map_size >> 1;
    var act: u32 = 0;
    var act_timer: u32 = 4;
    hero = Hero{
        .x = (x << cell_size_bits) + cell_size_half,
        .y = (y << cell_size_bits) + cell_size_half,
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
                if ((rnd.next() & 7) == 0) {
                    placeMob(x, y, 1);
                } else {
                    placeItem(x, y, 1);
                }
            }
        }
    }

    {
        const ex: i32 = (cell_size_half + (x << (cell_size_bits))) - (10 << fbits);
        const ey: i32 = (cell_size_half + (y << (cell_size_bits))) - (10 << fbits);
        exit = FPRect.init(ex, ey, 20 << fbits, 20 << fbits);
    }
}

fn playZzfx(comptime params: anytype) void {
    var audio_buffer: [8 * 4096]f32 = undefined;
    const len = gain.zzfx.buildSamples(gain.zzfx.ZzfxParameters.fromSlice(params), &audio_buffer);
    if (gain.js.enabled) {
        gain.js.playUserAudioBuffer(&audio_buffer, len, 1, 0, 0, 0);
    }
}

fn playZzfxEx(comptime params: anytype, vol: f32, pan: f32, detune: f32, when: f32) void {
    var audio_buffer: [8 * 4096]f32 = undefined;
    const len = gain.zzfx.buildSamples(gain.zzfx.ZzfxParameters.fromSlice(params), &audio_buffer);
    if (gain.js.enabled) {
        gain.js.playUserAudioBuffer(&audio_buffer, len, vol, pan, detune, when);
    }
}

fn testMapPoint(x: i32, y: i32) bool {
    const cx = @max(0, x) >> cell_size_bits;
    const cy = @max(0, y) >> cell_size_bits;
    return getMap(cx, cy) == 0;
}

fn testMapRect(rc: FPRect) bool {
    return testMapPoint(rc.x, rc.y) or
        testMapPoint(rc.x, rc.b()) or
        testMapPoint(rc.r(), rc.y) or
        testMapPoint(rc.r(), rc.b());
}

var g_rnd: gain.math.Rnd = .{ .seed = 0 };

fn updateMobs() void {
    for (0..mobs_num) |i| {
        const mob: *Mob = &mobs[i];
        if (mob.kind != 0) {
            var dx: i32 = @intCast(g_rnd.next());
            var dy: i32 = @intCast(g_rnd.next());
            dx = (@mod(dx, 3) - 1) << fbits;
            dy = (@mod(dy, 3) - 1) << fbits;
            const new_x = mob.x + dx;
            const new_y = mob.y + dy;
            if (!testMapRect(mob_hitbox_local.translate(new_x, mob.y))) {
                mob.*.x = new_x;
            }
            if (!testMapRect(mob_hitbox_local.translate(mob.x, new_y))) {
                mob.*.y = new_y;
            }
        }
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
    var move_dir = Vec2.init(0, 0);
    if ((keys.down[keys.Code.a] | keys.down[keys.Code.arrow_left]) != 0) {
        move_dir.x -= 1;
    }
    if ((keys.down[keys.Code.d] | keys.down[keys.Code.arrow_right]) != 0) {
        move_dir.x += 1;
    }
    if ((keys.down[keys.Code.w] | keys.down[keys.Code.arrow_up]) != 0) {
        move_dir.y -= 1;
    }
    if ((keys.down[keys.Code.s] | keys.down[keys.Code.arrow_down]) != 0) {
        move_dir.y += 1;
    }

    if (gain.pointers.primary()) |p| {
        if (p.is_down) {
            const d = p.rc.center().sub(p.start.center());
            const dist = getScreenScale() * (32 << fbits);
            if (d.length() >= dist) {
                move_dir = d;
            }
        }
    }

    if (move_dir.lengthSq() > 0) {
        const speed: f32 = if (hero_move_timer > 16) 1 else 0.5;
        move_dir = move_dir.normalize().scale(speed * (1 << fbits));
    }
    const dx: i32 = @intFromFloat(move_dir.x);
    const dy: i32 = @intFromFloat(move_dir.y);
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

    if (dx != 0 or dy != 0) {
        hero_move_timer +%= 1;
        hero_look_x = dx;
        hero_look_y = dy;

        if ((hero_move_timer & 0x1F) == 0) {
            playZzfx(.{ 1, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 });
        }
    } else {
        hero_move_timer = 0;
    }

    // var speed: i32 = 1 << fbits;
    // if (vx != 0 and vy != 0) {
    //     speed = 0xB4;
    // }
    //if (hero_move_timer > 16) speed <<= 1;

    const new_x = hero.x + dx;
    const new_y = hero.y + dy;
    if (!testMapRect(hero_ground_aabb_local.translate(new_x, hero.y))) {
        hero.x = new_x;
    }
    if (!testMapRect(hero_ground_aabb_local.translate(hero.x, new_y))) {
        hero.y = new_y;
    }

    const aabb = hero_ground_aabb_local.translate(hero.x, hero.y);
    for (0..items_num) |i| {
        const item = items[i];
        if (item.kind != 0 and item_aabb.translate(item.x, item.y).overlaps(aabb)) {
            items[i].kind = 0;
            playZzfx(.{ 1, 0.05, 1578, 0, 0.03, 0.15, 1, 0.87, 0, 0, 141, 0.01, 0, 0.1, 0, 0, 0, 0.52, 0.01, 0.04 });
        }
    }

    if (exit.overlaps(aabb)) {
        level += 1;
        level_started = false;
        playZzfx(.{ 1, 0.05, 177, 0, 0.09, 0.07, 2, 1.4, 0, 0, 0, 0, 0.09, 0, 38, 50, 0.28, 0.58, 0.1, 0 });
    }

    updateMobs();

    updateMusic();
}

fn invDist(x: i32, y: i32, x1: i32, y1: i32) i32 {
    const distance = 256 << fbits;
    const dx: f32 = @floatFromInt(x - x1);
    const dy: f32 = @floatFromInt(y - y1);
    const d = @max(distance - @sqrt(dx * dx + dy * dy), 0) / distance;
    //return @intFromFloat(@sqrt(@sqrt(d)) * (16 << fbits)); //(cell_size));
    return @intFromFloat(@sqrt(@sqrt(d)) * (cell_size_half));
}

fn drawQuad(x: i32, y: i32, w: i32, h: i32, color: u32) void {
    gfx.quad(Vec2.fromIntegers(x, y), Vec2.fromIntegers(w, h), color);
}

fn drawRect(rc: FPRect, color: u32) void {
    drawQuad(rc.x, rc.y, rc.w, rc.h, color);
}

fn getHeroOffY() i32 {
    return @intCast((((hero_move_timer & 31) + 7) >> 4) << fbits);
}

fn setDepth(x: i32, y: i32) void {
    _ = x;
    gfx.state.z = @floatFromInt(y >> fbits);
}

fn drawHero() void {
    const x = hero.x + hero_aabb_local.x;
    const y = hero.y + hero_aabb_local.y;
    const hero_y_off = getHeroOffY();

    setDepth(hero.x, hero.y);

    // eyes
    if (hero_look_y >= 0) {
        drawQuad(hero_look_x + x + (2 << fbits), hero_look_y + y + (4 << fbits) - (hero_y_off >> 1), 2 << fbits, 4 << fbits, 0xFF000000);
        drawQuad(hero_look_x + x + hero_w - (4 << fbits), hero_look_y + y + (4 << fbits) - (hero_y_off >> 1), 2 << fbits, 4 << fbits, 0xFF000000);
    }

    drawQuad(x, y - hero_y_off, hero_w, hero_h - hero_y_off - (2 << fbits), 0xFFFFFFFF);

    drawQuad(x - (2 << fbits), y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits, 0xFFFFFFFF);
    drawQuad(x + hero_w, y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits, 0xFFFFFFFF);

    drawQuad(x, y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits, 0xFFFFFFFF);
    drawQuad(x + (6 << fbits), y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits, 0xFFFFFFFF);
}

fn drawHeroShadow() void {
    const hero_y_off = getHeroOffY() >> fbits;
    drawRect(hero_ground_aabb_local.translate(hero.x, hero.y), @as(u32, @intCast(0x44 - 0x20 * hero_y_off)) << 24);
}

fn drawExit() void {
    const x = exit.x;
    const y = exit.y;
    const w = exit.w;
    const h = exit.h;
    setDepth(x, y);
    drawRect(exit, 0xFFFFFFFF);
    drawQuad(x - (2 << fbits), y - (2 << fbits), w + (4 << fbits), h + (4 << fbits), 0xFFFFBB66);
}

fn drawItem(i: usize) void {
    const item = items[i];
    const x = item.x;
    const y = item.y;
    setDepth(x, y);
    drawQuad(x - (4 << fbits), y - (4 << fbits), 8 << fbits, 8 << fbits, 0xFF00FF00);
    drawQuad(x - (6 << fbits), y - (6 << fbits), 12 << fbits, 12 << fbits, 0xFF444444);
}

fn drawMob(i: usize) void {
    const mob = mobs[i];
    const x = mob.x;
    const y = mob.y;
    const rc = mob_quad_local.translate(x, y);
    setDepth(x, y);
    drawRect(rc, 0xFF000000);
}

fn getScreenScale() f32 {
    const short_side = @min(app.w, app.h);
    return @as(f32, @floatFromInt(short_side)) / (screen_size * camera_zoom);
}

pub fn render() void {
    gfx.setupOpaquePass();
    gfx.state.matrix = Mat2d.identity();
    gfx.setTexture(0);

    const scale = getScreenScale();

    if (gain.pointers.primary()) |p| {
        if (p.is_down) {
            gfx.state.z = 10;
            gfx.fillCircle(p.rc.center(), Vec2.splat(scale * (24 << fbits)), 64, 0xFF999999);
            gfx.fillCircle(p.start.center(), Vec2.splat(scale * (60 << fbits)), 64, 0xFF444444);
            gfx.fillCircle(p.start.center(), Vec2.splat(scale * (64 << fbits)), 64, 0xFF111111);
        }
    }

    gfx.state.z = 4;

    {
        const cx = hero.x;
        const cy = hero.y;
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(app.w >> 1, app.h >> 1));
        gfx.state.matrix = gfx.state.matrix.scale(Vec2.splat(scale));
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(-cx, -cy));
    }

    // const occ_scale = 1 / scale;
    const occ_scale = 1 / scale;
    const sc_w = fp32.scale(@intCast(app.w), occ_scale);
    const sc_h = fp32.scale(@intCast(app.h), occ_scale);
    const camera_aabb = FPRect.init(
        hero.x - (sc_w >> 1),
        hero.y - (sc_h >> 1),
        sc_w,
        sc_h,
    ).expandInt(-32);

    drawHero();

    drawExit();

    for (0..items_num) |i| {
        const item = items[i];
        if (item.kind != 0 and item_aabb.translate(item.x, item.y).overlaps(camera_aabb)) {
            drawItem(i);
        }
    }

    for (0..mobs_num) |i| {
        const mob = mobs[i];
        if (mob.kind != 0 and mob_quad_local.translate(mob.x, mob.y).overlaps(camera_aabb)) {
            drawMob(i);
        }
    }

    gfx.state.z = 2;

    {
        const _cx = camera_aabb.x >> cell_size_bits;
        const _cy = camera_aabb.y >> cell_size_bits;
        const _cw = camera_aabb.w >> cell_size_bits;
        const _ch = camera_aabb.h >> cell_size_bits;
        const ccx0: usize = @intCast(@max(0, _cx));
        const ccx1: usize = @intCast(@max(0, _cx + _cw + 2));
        const ccy0: usize = @intCast(@max(0, _cy));
        const ccy1: usize = @intCast(@max(0, _cy + _ch + 2));

        const matrix = gfx.state.matrix;
        for (ccy0..ccy1) |cy| {
            for (ccx0..ccx1) |cx| {
                const cell = map[cy * map_size + cx];
                if (cell == 1) {
                    const x: i32 = @intCast((cx << cell_size_bits) + cell_size_half);
                    const y: i32 = @intCast((cy << cell_size_bits) + cell_size_half);
                    const sz0: i32 = invDist(hero.x, hero.y, x, y);
                    const sz = sz0 + ((@as(i32, @intCast((app.tic >> 3) + (cx *% cy))) & 7) << (fbits - 4));
                    const cell_size_v = Vec2.fromIntegers(sz << 1, sz << 1);
                    gfx.state.matrix = matrix
                        .translate(Vec2.fromIntegers(x, y))
                        .rotate(std.math.pi * (1 - @as(f32, @floatFromInt(sz0)) / (cell_size_half)));
                    gfx.quad(Vec2.fromIntegers(-sz, -sz), cell_size_v, 0xFF338866);
                }
            }
        }
        gfx.state.matrix = matrix;
    }
    gfx.state.z = 1;
    drawRect(camera_aabb, 0xFF222222);
    gfx.state.z = 0;
    drawRect(camera_aabb.expandInt(128 << fbits), 0xFF000000);

    gfx.setupBlendPass();
    gfx.state.z = 3;
    drawHeroShadow();
}

var music_end_time: f32 = 0;
var music_bar: u32 = 0;

fn updateMusic() void {
    var time: f32 = @floatFromInt(app.tic << 4);
    time = time / 1000;
    const k: f32 = (60.0 / 120.0) / 4.0;
    if (time >= music_end_time - k) {
        generateNextMusicBar(music_end_time, k);
        music_end_time += 16 * k;
        music_bar += 1;
    }
}

fn generateNextMusicBar(time: f32, k: f32) void {
    var t = time;
    for (0..16) |j| {
        if (j & 3 == 0) {
            playZzfxEx(.{ 1, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 }, 1, 0, 0, t);
        } else {
            playZzfxEx(.{ 1, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 }, 0.2, 0, 0, t);
        }
        t += k;
    }
}
