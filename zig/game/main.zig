const std = @import("std");
const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;
const FPRect = @import("FPRect.zig");
const fp32 = @import("fp32.zig");
const FPVec2 = @import("FPVec2.zig");

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
var kills: u32 = 0;
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
var hero_visible: u32 = 0;

var exit: FPRect = undefined;

const hit_timer_max = 15;
const Mob = struct {
    x: i32,
    y: i32,
    kind: u8,
    move_timer: u32,
    lx: i32,
    ly: i32,
    ai_timer: i32,
    hp: i32,
    hit_timer: u32,
    target_map_x: i32,
    target_map_y: i32,
};

fn placeMob(x: i32, y: i32, kind: u8) void {
    mobs[mobs_num] = .{
        .x = cell_size_half + (x << cell_size_bits),
        .y = cell_size_half + (y << cell_size_bits),
        .kind = kind,
        .move_timer = 0,
        .lx = 0,
        .ly = 0,
        .ai_timer = 0,
        .hp = 8,
        .hit_timer = 0,
        .target_map_x = 0,
        .target_map_y = 0,
    };
    mobs_num += 1;
}

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
    hero_visible = 0;

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

    for (map[0..]) |*cell| {
        if (cell.* == 1) {
            if (rnd.next() & 7 == 0) {
                cell.* = @truncate(1 + (rnd.next() & 3));
            }
        }
    }

    {
        const ex: i32 = (cell_size_half + (x << (cell_size_bits))) - (10 << fbits);
        const ey: i32 = (cell_size_half + (y << (cell_size_bits))) - (10 << fbits);
        exit = FPRect.init(ex, ey, 20 << fbits, 20 << fbits);
    }
}

fn playZzfxEx(comptime params: anytype, vol: f32, pan: f32, detune: f32, when: f32) void {
    var audio_buffer: [8 * 4096]f32 = undefined;
    const len = gain.zzfx.buildSamples(gain.zzfx.ZzfxParameters.fromSlice(params), &audio_buffer);
    if (gain.js.enabled) {
        gain.js.playUserAudioBuffer(&audio_buffer, len, vol, pan, detune, when);
    }
}

fn playZzfx(comptime params: anytype) void {
    playZzfxEx(params, 1, 0, 0, 0);
}

fn getMapPoint(x: i32, y: i32) Cell {
    const cx = @max(0, x) >> cell_size_bits;
    const cy = @max(0, y) >> cell_size_bits;
    return getMap(cx, cy);
}

fn testMapPoint(x: i32, y: i32) bool {
    return getMapPoint(x, y) == 0;
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
            if (mob.*.ai_timer <= 0) {
                if (g_rnd.next() & 7 == 0) {
                    mob.*.lx = 0;
                    mob.*.ly = 0;
                } else {
                    var dx: i32 = @intCast(g_rnd.next());
                    var dy: i32 = @intCast(g_rnd.next());
                    dx = (@mod(dx, 3) - 1) << fbits;
                    dy = (@mod(dy, 3) - 1) << fbits;
                    mob.*.lx = dx;
                    mob.*.ly = dy;
                }
                mob.*.ai_timer = @intCast(g_rnd.next() & 0x3f);

                _ = findPath(mob.x >> cell_size_bits, mob.y >> cell_size_bits, hero.x >> cell_size_bits, hero.y >> cell_size_bits);
                if (path_num > 1) {
                    mob.*.target_map_x = path_x[1];
                    mob.*.target_map_y = path_y[1];
                    //mob.*.lx = ((path_x[1] << cell_size_bits) + cell_size_half) - mob.x;
                    //mob.*.ly = ((path_y[1] << cell_size_bits) + cell_size_half) - mob.y;
                } else {
                    mob.*.target_map_x = 0;
                    mob.*.target_map_y = 0;
                }
            }
            if (mob.*.target_map_x != 0) {
                const tx: i32 = (mob.*.target_map_x << cell_size_bits) + cell_size_half;
                const ty: i32 = (mob.*.target_map_y << cell_size_bits) + cell_size_half;
                if (tx < mob.x) {
                    mob.*.lx = -1 << fbits;
                } else if (tx > mob.x) {
                    mob.*.lx = 1 << fbits;
                } else {
                    mob.*.lx = 0;
                }
                if (ty < mob.y) {
                    mob.*.ly = -1 << fbits;
                } else if (ty > mob.y) {
                    mob.*.ly = 1 << fbits;
                } else {
                    mob.*.ly = 0;
                }
                if (mob.x == tx and mob.y == ty) {
                    mob.*.ai_timer = 0;
                }
            } else {
                mob.*.ai_timer -= 1;
            }
            if (mob.*.lx != 0 or mob.*.ly != 0) {
                mob.*.move_timer +%= 2;
                const new_x = mob.x + mob.*.lx;
                const new_y = mob.y + mob.*.ly;
                if (!testMapRect(mob_hitbox_local.translate(new_x, mob.y))) {
                    mob.*.x = new_x;
                } else {
                    mob.*.lx = -mob.*.lx;
                }
                if (!testMapRect(mob_hitbox_local.translate(mob.x, new_y))) {
                    mob.*.y = new_y;
                } else {
                    mob.*.ly = -mob.*.ly;
                }
            } else {
                mob.*.move_timer = 0;
            }

            if (mob.hit_timer > 0) {
                mob.*.hit_timer -= 1;
            }
        }
    }
}

pub fn update() void {
    updateMenu();

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

    if (move_dir.length() > 0) {
        const speed: f32 = if (hero_move_timer > 16) 2 else 1;
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
        hero_move_timer +%= 2;
        hero_look_x = dx;
        hero_look_y = dy;

        if ((hero_move_timer & 0x1F) == 0) {
            const vol: f32 = @as(f32, @floatFromInt(hero_visible)) / 31.0;
            playZzfxEx(.{ 1, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 }, vol, 0, 0, 0);
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

    for (0..mobs_num) |i| {
        const mob = &mobs[i];
        if (mob.kind != 0 and mob.*.hit_timer < (hit_timer_max >> 1)) {
            const mob_aabb = mob_hitbox_local.translate(mob.x, mob.y);
            if (mob_aabb.overlaps(aabb)) {
                mob.*.hp -= g_rnd.int(2, 10);
                mob.*.hit_timer = hit_timer_max;
                //mob.*.lx = mob.x - aabb.cx();
                //mob.*.ly = mob.y - aabb.cy();
                playZzfx(.{ 1, 0.05, 337, 0.01, 0.02, 0.1, 0, 2.17, -6.3, 3.5, 0, 0, 0, 1.2, 0, 10, 0.01, 0.69, 0.07, 0.03 });
                addParticles(32, mob_aabb.cx(), mob_aabb.cy());
                if (mob.*.hp <= 0) {
                    mob.*.kind = 0;

                    kills += 1;

                    addParticles(64, mob_aabb.cx(), mob_aabb.cy());
                }
            }
        }
    }

    if (getMapPoint(aabb.cx(), aabb.cy()) > 1) {
        if (hero_visible > 0) {
            hero_visible -= 1;
        }
    } else if (hero_visible < 31) {
        hero_visible += 1;
    }

    if (exit.overlaps(aabb)) {
        level += 1;
        level_started = false;
        playZzfx(.{ 1, 0.05, 177, 0, 0.09, 0.07, 2, 1.4, 0, 0, 0, 0, 0.09, 0, 38, 50, 0.28, 0.58, 0.1, 0 });
    }

    updateMobs();

    updateMusic();

    updateParticles();
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

fn getHeroOffY(move_timer: u32) i32 {
    return @intCast((((move_timer & 31) + 7) >> 4) << fbits);
}

fn setDepth(x: i32, y: i32) void {
    _ = x;
    gfx.state.z = @floatFromInt(y >> fbits);
}

fn drawTempMan(px: i32, py: i32, dx: i32, dy: i32, move_timer: u32, body_color: u32) void {
    const x = px + hero_aabb_local.x;
    const y = py + hero_aabb_local.y;
    const hero_y_off = getHeroOffY(move_timer);

    setDepth(px, py);

    // eyes
    if (dy >= 0) {
        drawQuad(dx + x + (2 << fbits), dy + y + (4 << fbits) - (hero_y_off >> 1), 2 << fbits, 4 << fbits, 0xFF000000);
        drawQuad(dx + x + hero_w - (4 << fbits), dy + y + (4 << fbits) - (hero_y_off >> 1), 2 << fbits, 4 << fbits, 0xFF000000);
    }

    drawQuad(x, y - hero_y_off, hero_w, hero_h - hero_y_off - (2 << fbits), body_color);

    drawQuad(x - (2 << fbits), y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits, body_color);
    drawQuad(x + hero_w, y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits, body_color);

    drawQuad(x, y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits, body_color);
    drawQuad(x + (6 << fbits), y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits, body_color);
}

fn drawHero() void {
    const body_color = Color32.lerp8888b(0xFF888888, 0xFFFFFFFF, hero_visible << 3);
    drawTempMan(hero.x, hero.y, hero_look_x, hero_look_y, hero_move_timer, body_color);
}

fn drawManShadow(x: i32, y: i32, move_timer: u32) void {
    const y_off = getHeroOffY(move_timer) >> fbits;
    drawRect(hero_ground_aabb_local.translate(x, y), @as(u32, @intCast(0x44 - 0x20 * y_off)) << 24);
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
    var body_color: u32 = switch (mob.kind) {
        1 => 0xFFFFBB99,
        2 => 0xFFFFCCCC,
        3 => 0xFFCCCCFF,
        else => 0xFFCCFF99,
    };
    body_color = Color32.lerp8888b(body_color, 0xFFFFFFFF, mob.hit_timer << 4);
    drawTempMan(x, y, mob.lx, mob.ly, mob.move_timer, body_color);
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

    drawParticles();

    {
        const _cx = camera_aabb.x >> cell_size_bits;
        const _cy = camera_aabb.y >> cell_size_bits;
        const _cw = camera_aabb.w >> cell_size_bits;
        const _ch = camera_aabb.h >> cell_size_bits;
        const ccx0: usize = @intCast(@max(0, _cx));
        const ccx1: usize = @intCast(@max(0, _cx + _cw + 2));
        const ccy0: usize = @intCast(@max(0, _cy));
        const ccy1: usize = @intCast(@max(0, _cy + _ch + 2));

        for (ccy0..ccy1) |cy| {
            for (ccx0..ccx1) |cx| {
                const cell = map[cy * map_size + cx];
                if (cell > 1) {
                    const x: i32 = @intCast((cx << cell_size_bits));
                    const y: i32 = @intCast((cy << cell_size_bits) + cell_size_half);
                    setDepth(x, y + cell_size_half);
                    if (cell == 2) {
                        drawQuad(x, y, cell_size, cell_size_half, 0xFF888888);
                    } else if (cell == 3) {
                        drawQuad(x, y, cell_size, cell_size_half, 0xFF338833);
                    } else if (cell == 4) {
                        drawQuad(x, y, cell_size, cell_size_half, 0xFF888833);
                    }
                }
            }
        }

        gfx.state.z = 2;

        {
            for (0..path_num) |i| {
                const cx = path_x[i];
                const cy = path_y[i];
                drawQuad(cx << cell_size_bits, cy << cell_size_bits, cell_size, cell_size, if (path_found) 0xFFFFFFFF else 0xFFFFFF00);
            }

            const cx = path_dest_x;
            const cy = path_dest_y;
            drawQuad(cx << cell_size_bits, cy << cell_size_bits, cell_size, cell_size, 0xFFFF0000);
        }

        const matrix = gfx.state.matrix;
        for (ccy0..ccy1) |cy| {
            for (ccx0..ccx1) |cx| {
                const cell = map[cy * map_size + cx];
                if (cell != 0) {
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

    drawManShadow(hero.x, hero.y, hero_move_timer);
    drawParticlesShadows();

    for (0..mobs_num) |i| {
        const mob = mobs[i];
        if (mob.kind != 0) {
            drawManShadow(mob.x, mob.y, mob.move_timer);
        }
    }

    {
        gfx.state.z = 50000;
        //gfx.state.matrix = Mat2d.identity();
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(camera_aabb.cx(), camera_aabb.y));
        const space_x: i32 = @divTrunc(512 << fbits, 14);
        gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers((-(512 << fbits) >> 1), 20 << fbits));
        for (0..13) |i| {
            var rc = FPRect.init(0, 0, 0, 0);

            gfx.state.matrix = gfx.state.matrix.translate(Vec2.fromIntegers(space_x, 0));
            const mat = gfx.state.matrix;
            gfx.state.matrix = gfx.state.matrix.rotate(0.1); // * @as(f32, @floatFromInt(i / 3)));
            //gfx.state.matrix = gfx.state.matrix.rotate(0.1);
            drawRect(rc.expandInt(12).translate(1 << fbits, 1 << fbits), 0xFF111111);
            drawRect(rc.expandInt(10), 0xFFCCCCCC);
            if (i < kills) {
                rc = rc.expandInt(8);
                gfx.lineQuad(Vec2.fromIntegers(rc.x, rc.y), Vec2.fromIntegers(rc.r(), rc.b()), 0xFF992211, 0xFF880000, 4 << fbits, 2 << fbits);
                gfx.lineQuad(Vec2.fromIntegers(rc.x, rc.b()), Vec2.fromIntegers(rc.r(), rc.y), 0xFF992211, 0xFF880000, 3 << fbits, 4 << fbits);
            }
            gfx.state.matrix = mat;
        }
    }

    drawMenu();
}

// MUSIC

var music_end_time: f32 = 0;
var music_bar: u32 = 0;

fn updateMusic() void {
    var time: f32 = @floatFromInt(app.tic << 4);
    time = time / 1000;
    const k: f32 = (60.0 / 80.0) / 4.0;
    if (time >= music_end_time - k) {
        generateNextMusicBar(music_end_time, k);
        music_end_time += 16 * k;
        music_bar += 1;
    }
}

fn generateNextMusicBar(time: f32, k: f32) void {
    var t = time;
    for (0..16) |j| {
        const i = j & 0x3;
        if (i == 0 or i == 3) {
            playZzfxEx(.{ 1, 0, 100, 2e-3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5e-3, 0 }, 1, 0, 0, t);
        }

        const v: f32 = if (i > 1) 0.2 else 0.1;
        playZzfxEx(.{ 1, 0, 1e3, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0.1, 0 }, v, 0, 0, t);

        t += k;
    }
}

// PARTICLES

const Particle = struct {
    x: i32,
    y: i32,
    z: i32,
    vx: i32,
    vy: i32,
    vz: i32,
    t: i32,
    max_time: i32,
    color: u32,
    size: i32,
};

var particles: [1024]Particle = undefined;
var particles_num: u32 = 0;

fn updateParticles() void {
    for (0..particles_num) |i| {
        const p = &particles[i];
        if (p.t > 0) {
            p.*.t -= 1;
            //p.*.p = p.p.add(p.v);
            const f = fp32.div(p.t, p.max_time);
            const x2 = p.x + fp32.mul(p.vx, f);
            const y2 = p.y + fp32.mul(p.vy, f);
            if (getMapPoint(x2, p.y) == 0) {
                p.vx = -p.vx;
            } else {
                p.x = x2;
            }
            if (getMapPoint(p.x, y2) == 0) {
                p.vy = -p.vy;
            } else {
                p.y = y2;
            }
        }

        if (p.z > 0) {
            p.z = @max(0, p.z + p.vz);
            p.vz -= 2;
            //p.vz = -fp32.mul(p.vz, fp32.fromFloat(0.5));
        }
    }
}

fn drawParticles() void {
    for (0..particles_num) |i| {
        const p = &particles[i];
        setDepth(p.x, p.y);
        drawRect(FPRect.init(p.x, p.y - p.z, 0, 0).expand(p.size, p.size >> 1), p.color);
    }
}

fn drawParticlesShadows() void {
    for (0..particles_num) |i| {
        const p = &particles[i];
        drawRect(FPRect.init(p.x, p.y, 0, 0).expand(p.size, p.size >> 1), 0x77000000);
    }
}

fn addParticles(n: i32, x: i32, y: i32) void {
    const N: usize = @intCast(n);
    for (0..N) |_| {
        const d = g_rnd.frange(0, 5);
        const a = g_rnd.frange(0, std.math.tau);
        const t = g_rnd.int(10, 20);
        particles[particles_num] = .{
            .x = x,
            .y = y,
            .z = g_rnd.int(0, 20 << fbits),
            .vx = fp32.fromFloat(d * gain.math.costau(a)),
            .vy = fp32.fromFloat(d * gain.math.sintau(a) / 2),
            .vz = 0,
            .color = 0xFFCC0000,
            .max_time = t,
            .t = t,
            .size = g_rnd.int(1, 4) << fbits,
        };
        particles_num += 1;
    }
}

// path find

const path_max = 16;
var path_x: [path_max]i32 = undefined;
var path_y: [path_max]i32 = undefined;
var path_num: usize = undefined;
var path_dest_x: i32 = undefined;
var path_dest_y: i32 = undefined;
var path_found = false;
var pf_visited: [1 << (map_size_bits << 1)]u8 = undefined;
var pf_parent_x: [path_max]i32 = undefined;
var pf_parent_y: [path_max]i32 = undefined;

fn visitNeighbor(x: i32, y: i32, depth: usize) void {
    if (x > 0 and y > 0 and x < map_size - 1 and y < map_size - 1) {
        const addr = mapPtr(x, y);
        if (pf_visited[addr] == 0 and map[addr] != 0) {
            pf_visited[addr] = 1;
            searchPath(x, y, depth + 1);
            pf_visited[addr] = 0;
        }
    }
}

fn searchPath(x: i32, y: i32, depth: usize) void {
    const path_len = depth + 1;
    if (path_num == 0 or path_len < path_num) {
        pf_parent_x[depth] = x;
        pf_parent_y[depth] = y;
        if (path_dest_x == x and path_dest_y == y) {
            path_num = path_len;
            var i = path_len;
            while (i != 0) {
                i -= 1;
                path_x[i] = pf_parent_x[i];
                path_y[i] = pf_parent_y[i];
            }
        } else if (path_len < path_max) {
            visitNeighbor(x - 1, y, depth);
            visitNeighbor(x + 1, y, depth);
            visitNeighbor(x, y - 1, depth);
            visitNeighbor(x, y + 1, depth);
        }
    }
}

fn findPath(bx: i32, by: i32, ex: i32, ey: i32) bool {
    path_num = 0;
    path_dest_x = ex;
    path_dest_y = ey;
    const addr = mapPtr(bx, by);
    pf_visited[addr] = 1;
    searchPath(bx, by, 0);
    pf_visited[addr] = 0;
    path_found = path_num > 0;
    return path_found;
}

// MENU
var game_state: u8 = 0;
var t_transition: u8 = 0;

fn updateMenu() void {
    if (game_state == 0) {
        if (gain.pointers.primary()) |p| {
            if (p.down) {
                game_state = 1;
            }
        }
    } else if (game_state == 1) {
        if (t_transition < 15) {
            t_transition += 1;
        }
    } else if (game_state == 2) {
        if (t_transition > 0) {
            t_transition -= 1;
        }
    }
}

fn drawMenu() void {
    // draw text
    if (t_transition < 15) {
        gfx.state.matrix = Mat2d.identity(); //.scale(Vec2.splat(scale * (1 << fbits)));
        gfx.setTexture(0);
        drawRect(FPRect.init(0, 0, @intCast(app.w), @intCast(app.h)), Color32.lerp8888b(
            0xFF000000,
            0x00000000,
            t_transition << 4,
        ));
        gfx.setTexture(1);
        var buffer: [128 * 128 * 4]u8 = undefined;
        const image = gfx.drawText("START GAME", &buffer);
        gfx.setTextureData(.{
            .id = 1,
            .w = image.w,
            .h = image.h,
            .filter = 0,
            .wrap_s = 0,
            .wrap_t = 0,
            .data = gfx.CRange.fromSlice(image.pixels),
        });
        const w = image.w * 4;
        const h = image.h * 4;
        gfx.quad(Vec2.fromIntegers(app.w / 2 - w / 2, app.h / 2 - h / 2), Vec2.fromIntegers(w, h), 0xFFFF0000);
    }
}
