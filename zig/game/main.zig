const std = @import("std");
const gain = @import("../gain/main.zig");
const gfx = @import("gfx.zig");
const Vec2 = gain.math.Vec2;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;
const FPRect = @import("FPRect.zig");
const fp32 = @import("fp32.zig");
const FPVec2 = @import("FPVec2.zig");
const sfx = @import("sfx.zig");
const map = @import("map.zig");
const particles = @import("particles.zig");
const colors = @import("colors.zig");

var g_rnd: gain.math.Rnd = .{ .seed = 0 };

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
const cell_size_bits = map.cell_size_bits;
const cell_size = map.cell_size;
const cell_size_half = map.cell_size_half;

var level: u32 = 0;
var level_started = false;
var kills: u32 = 0;
const camera_zoom = 1;
const screen_size = 512 << fbits;
const screen_size_half = screen_size >> 1;

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
const hero_visible_max = 31;
var hero_knife = false;
var hero_mask = false;

const Portal = struct {
    src: FPVec2,
    rc: FPRect,
    dest: FPVec2,
};

const portals_max = 32;
var portals: [portals_max]Portal = undefined;
var portals_num: u32 = undefined;

fn addPortal(x: i32, y: i32, dx: i32, dy: i32, sx: i32, sy: i32) void {
    if (portals_num < portals_max) {
        portals[portals_num] = .{
            .rc = FPRect.init(
                x << map.cell_size_bits,
                y << cell_size_bits,
                cell_size,
                cell_size,
            ),
            .dest = FPVec2.init(
                (dx << cell_size_bits) + cell_size_half,
                (dy << cell_size_bits) + cell_size_half,
            ),
            .src = FPVec2.init(
                (sx << cell_size_bits) + cell_size_half,
                (sy << cell_size_bits) + cell_size_half,
            ),
        };
        portals_num += 1;
    }
}

const mob_max_hp = 8;
const hit_timer_max = 15;
const Mob = struct {
    x: i32,
    y: i32,
    kind: i32,
    move_timer: u32,
    lx: i32,
    ly: i32,
    ai_timer: i32,
    hp: i32,
    hit_timer: u32,
    target_map_x: i32,
    target_map_y: i32,
    danger_t: i32,
    danger: bool,
    attention: u32,
    male: bool,
    text_t: i32,
    text_i: u32,
};

fn placeMob(x: i32, y: i32, kind: i32, male: bool) void {
    mobs[mobs_num] = .{
        .x = cell_size_half + (x << cell_size_bits),
        .y = cell_size_half + (y << cell_size_bits),
        .kind = kind,
        .move_timer = 0,
        .lx = 0,
        .ly = 0,
        .ai_timer = 0,
        .hp = mob_max_hp,
        .hit_timer = 0,
        .target_map_x = 0,
        .target_map_y = 0,
        .danger_t = 0,
        .danger = false,
        .attention = 0,
        .male = male,
        .text_t = 0,
        .text_i = 0,
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

const items_max = 128;
var items: [items_max]Item = undefined;
var items_num: u32 = undefined;

fn placeItem(x: i32, y: i32, kind: u8) void {
    if (items_num < items_max) {
        items[items_num] = .{
            .x = cell_size_half + (x << cell_size_bits),
            .y = cell_size_half + (y << cell_size_bits),
            .kind = kind,
        };
        items_num += 1;
    }
}

fn initLevel() void {
    var rnd = gain.math.Rnd{ .seed = 1 + (level << 5) };

    items_num = 0;
    mobs_num = 0;
    particles.reset();
    var x: i32 = map.size >> 1;
    var y: i32 = map.size >> 1;
    var room_x = x;
    var room_y = y;
    var act: u32 = 0;
    var act_timer: u32 = 4;
    hero.x = (x << cell_size_bits) + cell_size_half;
    hero.y = (y << cell_size_bits) + cell_size_half;
    hero_visible = 0;

    const rooms_count: u8 = 6;
    for (0..rooms_count) |room_index| {
        map.current_color = @truncate(room_index);
        const iters = 100;
        var portals_gen: u32 = 1;
        var items_gen: u32 = 10;
        var mobs_gen: u32 = 3;
        var gender_i: u32 = 0;
        for (0..iters) |_| {
            switch (act) {
                0 => if (x + 2 < map.size) {
                    x += 1;
                } else {
                    //act = 1;
                },
                1 => if (x > 1) {
                    x -= 1;
                } else {
                    //act = 0;
                },
                2 => if (y + 2 < map.size) {
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

            map.set(x, y, 1);
            map.set(x - 1, y, 1);
            map.set(x + 1, y, 1);
            map.set(x, y - 1, 1);
            map.set(x, y + 1, 1);

            act_timer -= 1;
            if (act_timer == 0) {
                act_timer = 1 + (rnd.next() & 3);
                const new_act = rnd.next() & 3;
                if (new_act != act) {
                    act = new_act;
                    const pp = rnd.next() & 7;
                    switch (pp) {
                        0 => if (mobs_gen > 0) {
                            placeMob(x, y, rnd.int(1, 3), gender_i & 1 == 1);
                            gender_i += 1;
                            mobs_gen -= 1;
                        },
                        1 => if (portals_num > 2 and portals_gen > 0) {
                            const p = portals[rnd.next() % portals_num];
                            addPortal(x, y, p.src.x >> cell_size_bits, p.src.y >> cell_size_bits, room_x, room_y);
                            portals_gen -= 1;
                        },
                        else => if (items_gen > 0) {
                            placeItem(x, y, 1);
                            items_gen -= 1;
                        },
                    }
                }
            }
        }

        if (room_index < rooms_count - 1) {
            const nx = rnd.int(4, map.size - 4);
            const ny = rnd.int(4, map.size - 4);
            addPortal(x, y, nx, ny, room_x, room_y);
            x = nx;
            y = ny;
            room_x = x;
            room_y = y;
        }
    }

    addPortal(x, y, hero.x, hero.y, room_x, room_y);

    for (&map.map) |*cell| {
        if (cell.* == 1) {
            if (rnd.next() & 7 == 0) {
                cell.* = @truncate(1 + (rnd.next() & 3));
            }
        }
    }
}

fn setMobRandomMovement(mob: *Mob) void {
    const speed: i32 = if (g_rnd.next() & 7 == 0) 0 else 1 << fbits;
    const v = calcMoveVector(
        g_rnd.int(-10, 10),
        g_rnd.int(-10, 10),
        speed,
    );
    mob.*.lx = v.x;
    mob.*.ly = v.y;
}

fn mobRunAwayBeh(mob: *Mob, x: i32, y: i32, speed: i32) void {
    const v = calcMoveVector(mob.x - x, mob.y - y, speed);
    mob.*.lx = v.x;
    mob.*.ly = v.y;
}

fn calcMoveVector(dx: i32, dy: i32, speed: i32) FPVec2 {
    const v = Vec2.fromIntegers(dx, dy).normalize().scale(@floatFromInt(speed));
    return FPVec2.init(
        @intFromFloat(v.x),
        @intFromFloat(v.y),
    );
}

fn updateMobs() void {
    const hero_aabb = hero_ground_aabb_local.translate(hero.x, hero.y).expandInt(16);

    for (0..mobs_num) |i| {
        const mob: *Mob = &mobs[i];
        if (mob.kind != 0) {
            const hero_is_danger = hero_visible > 8 and hero_knife and hero_mask;
            const dist_to_hero = fp32.dist(hero.x, hero.y, mob.x, mob.y);
            const danger = hero_is_danger and dist_to_hero < (100 << fbits);
            if (danger) {
                mob.*.attention += 1;
                if (mob.attention > 32 and !mob.danger) {
                    mob.*.danger_t = 32;
                    sfx.fear();
                    mob.*.danger = true;
                }
            } else {
                if (mob.*.danger_t > 0) {
                    mob.*.danger = false;
                }
                if (mob.attention > 0) {
                    mob.*.attention -= 1;
                }
            }

            if (mob.*.ai_timer <= 0) {
                mob.*.ai_timer = @intCast(g_rnd.next() & 0x3f);
                if (mob.danger) {
                    mob.*.target_map_x = 0;
                    mob.*.target_map_y = 0;
                    if (findClosestPortal(mob.x, mob.y)) |portal| {
                        map.findPath(mob.x >> cell_size_bits, mob.y >> cell_size_bits, portal.rc.cx() >> cell_size_bits, portal.rc.cy() >> cell_size_bits);
                        if (map.path_num > 1) {
                            mob.*.target_map_x = map.path_x[1];
                            mob.*.target_map_y = map.path_y[1];
                        }
                    }
                } else {
                    // just flex
                    mob.*.target_map_x = 0;
                    mob.*.target_map_y = 0;
                    setMobRandomMovement(mob);
                }
            }
            const speed: i32 = @as(i32, if (mob.danger) 2 else 1) << fbits;
            if (mob.danger_t > 0) {
                mob.*.danger_t -= 1;
            }
            if (danger and (!mob.danger or mob.danger_t > 0)) {
                mob.*.lx = 0;
                mob.*.ly = 0;
            } else if (mob.*.target_map_x != 0) {
                const tx: i32 = (mob.*.target_map_x << cell_size_bits) + cell_size_half;
                const ty: i32 = (mob.*.target_map_y << cell_size_bits) + cell_size_half;
                mob.*.lx = @max(-speed, @min(speed, tx - mob.x));
                mob.*.ly = @max(-speed, @min(speed, ty - mob.y));
                if (mob.x + mob.*.lx == tx and mob.y + mob.*.ly == ty) {
                    mob.*.ai_timer = 0;

                    if (testPortals(mob_hitbox_local.translate(mob.x, mob.y))) |portal| {
                        mob.x = portal.dest.x;
                        mob.y = portal.dest.y;
                        mob.*.danger = false;
                        sfx.portal();
                    }
                }
            } else {
                if (danger) {
                    mobRunAwayBeh(mob, hero.x, hero.y, speed);
                }
                mob.*.ai_timer -= 1;
            }
            // block move to hidden hero
            if (!danger and dist_to_hero < (64 << fbits)) {
                mobRunAwayBeh(mob, hero.x, hero.y, speed);
            }
            if (mob.*.lx != 0 or mob.*.ly != 0) {
                mob.*.move_timer +%= 2;
                const new_x = mob.x + mob.*.lx;
                const new_y = mob.y + mob.*.ly;
                if (!map.testRect(mob_hitbox_local.translate(new_x, mob.y))) {
                    mob.*.x = new_x;
                } else {
                    mob.*.lx = -mob.*.lx;
                }
                if (!map.testRect(mob_hitbox_local.translate(mob.x, new_y))) {
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

            if (mob.hp < mob_max_hp and g_rnd.next() & 0x7 == 0) {
                const mob_aabb = mob_hitbox_local.translate(mob.x, mob.y);
                particles.add(1, mob_aabb.cx(), mob_aabb.cy(), 20 << fbits);
            }
            {
                const phrases: [5][]const u8 = .{
                    "aaaaa",
                    "hey!",
                    "run!",
                    "oh my god",
                    "run away!",
                };

                if (mob.text_t > 0) {
                    mob.*.text_t -= 1;
                    if (mob.*.text_t == 0) {
                        clearMobText(i);
                    } else {
                        setText(@bitCast(i + 3), phrases[mob.text_i], FPVec2.init(mob.x, mob.y - (48 << fbits)), 0xFFFFFF, 2);
                    }
                } else {
                    if (mob.danger and g_rnd.next() & 31 == 31) {
                        selectMobText(i, g_rnd.next() % phrases.len);
                        // pick text index
                    }
                }
            }

            if (mob.hit_timer < (hit_timer_max >> 1) and hero_knife) {
                const mob_aabb = mob_hitbox_local.translate(mob.x, mob.y);
                if (mob_aabb.overlaps(hero_aabb)) {
                    if (!mob.danger) {
                        mob.*.hp -= mob_max_hp;
                    } else {
                        mob.*.hp -= g_rnd.int(2, 3);
                    }
                    mob.*.hit_timer = hit_timer_max;
                    //mob.*.lx = mob.x - aabb.cx();
                    //mob.*.ly = mob.y - aabb.cy();
                    sfx.hit();
                    const kx = mob_aabb.cx();
                    const ky = mob_aabb.cy();
                    particles.add(32, kx, ky, 20 << fbits);
                    if (mob.hp <= 0) {
                        //particles.add(64, kx, ky);
                        particles.addPart(kx, ky, getMobColor(mob.kind), 1, FPRect.init(0, 0, 0, 4 << fbits).expandInt(5));
                        const limb_rc = FPRect.init(0, 0, 0, 0).expand(2 << fbits, 5 << fbits);
                        particles.addPart(kx - (4 >> fbits), ky, getMobColor(mob.kind), 0, limb_rc);
                        particles.addPart(kx + (4 >> fbits), ky, getMobColor(mob.kind), 0, limb_rc);
                        particles.addPart(kx - (4 >> fbits), ky + (10 >> fbits), getMobColor(mob.kind), 0, limb_rc);
                        particles.addPart(kx + (4 >> fbits), ky + (10 >> fbits), getMobColor(mob.kind), 0, limb_rc);

                        mob.*.kind = 0;
                        clearMobText(i);
                        kills += 1;
                    }
                }
            }
        }
    }
}

fn selectMobText(i: u32, phrase: u32) void {
    mobs[i].text_i = phrase;
    mobs[i].text_t = 32;
}

fn clearMobText(i: u32) void {
    unsetText(@bitCast(i + 3));
}

fn updateGame() void {
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
            const d = p.pos.sub(p.start);
            const dist = getScreenScale() * (32 << fbits);
            if (d.length() >= dist) {
                move_dir = d;
            }
        }
    }

    if (move_dir.length() > 0) {
        //1 + (hero_move_timer >> 4);
        const max_speed: u32 = if (hero_visible > 8) 2 else 1;
        const speed: f32 = @floatFromInt(@min(max_speed, 1 + (hero_move_timer >> 4)));
        //const speed: f32 = @floatFromInt(1 + ((hero_move_timer >> 4) & 0x3));
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
            sfx.step(hero_visible);
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
    if (!map.testRect(hero_ground_aabb_local.translate(new_x, hero.y))) {
        hero.x = new_x;
    }
    if (!map.testRect(hero_ground_aabb_local.translate(hero.x, new_y))) {
        hero.y = new_y;
    }

    const aabb = hero_ground_aabb_local.translate(hero.x, hero.y);
    for (0..items_num) |i| {
        const item = items[i];
        if (item.kind != 0 and item_aabb.translate(item.x, item.y).overlaps(aabb)) {
            if (i == 0 and !hero_mask) {
                hero_mask = true;
            } else if (i == 1 and !hero_knife) {
                hero_knife = true;
            }
            items[i].kind = 0;
            sfx.collect();
        }
    }

    if (map.getPoint(aabb.cx(), aabb.cy()) > 1) {
        if (hero_visible > 0) {
            hero_visible -= 1;
        }
    } else if (hero_visible < hero_visible_max) {
        hero_visible += 1;
    }

    if (testPortals(aabb)) |portal| {
        //level += 1;
        //level_started = false;
        hero.x = portal.dest.x;
        hero.y = portal.dest.y;
        no_black_screen_target = 15;
        sfx.portal();
    }

    updateMobs();
}

fn testPortals(rc: FPRect) ?*Portal {
    for (0..portals_num) |i| {
        if (portals[i].rc.overlaps(rc)) {
            return &portals[i];
        }
    }
    return null;
}

fn findClosestPortal(x: i32, y: i32) ?*Portal {
    var min_dist: i32 = 1000000;
    var min_portal: ?*Portal = null;
    for (0..portals_num) |i| {
        const dist = fp32.dist(x, y, portals[i].rc.x, portals[i].rc.y);
        if (dist < min_dist) {
            min_dist = dist;
            min_portal = &portals[i];
        }
    }
    return min_portal;
}

pub fn update() void {
    if (!level_started) {
        initLevel();
        level_started = true;
        if (game_state == 1) {
            no_black_screen_target = 15;
            no_black_screen_t = 0;
        }
        return;
    }

    updateMenu();
    updateGame();
    sfx.update();
    particles.update();

    if (hero_visible > 8) {
        const messages: [10][]const u8 = .{
            "my name is jason",
            "today is friday 13th",
            "happy birthday to me",
            "oh poor students",
            "they are scared for 13",
            "i have to harvest 13",
            "follow js(13)k",
            "machette",
            "blood",
            "fear",
        };
        const msg = messages[(gain.app.tic >> 6) % 10];
        setText(0, msg, FPVec2.init(hero.x, hero.y - (48 << fbits)), 0xFF0000, 2);
    } else {
        unsetText(0);
    }
}

fn setText(handle: i32, text: []const u8, pos: FPVec2, color: u32, size: i32) void {
    const scale = getScreenScale();
    const camera_x = hero.x;
    const camera_y = hero.y;
    const m = Mat2d
        .identity()
        .translate(Vec2.fromIntegers(app.w >> 1, app.h >> 1))
        .scale(Vec2.splat(scale))
        .translate(Vec2.fromIntegers(-camera_x, -camera_y));
    const xy = Vec2.fromIntegers(pos.x, pos.y).transform(m);
    gain.js.text(handle, @intFromFloat(xy.x), @intFromFloat(xy.y), color, size, text.ptr, text.len);
}

fn unsetText(handle: i32) void {
    gain.js.text(handle, 0, 0, 0, 0, "", 0);
}

fn invDist(x: i32, y: i32, x1: i32, y1: i32) i32 {
    const distance = 256 << fp32.fbits;
    const dx: f32 = @floatFromInt(x - x1);
    const dy: f32 = @floatFromInt(y - y1);
    const d = @max(distance - @sqrt(dx * dx + dy * dy), 0) / distance;
    //return @intFromFloat(@sqrt(@sqrt(d)) * (16 << fbits)); //(cell_size));
    return @intFromFloat(@sqrt(@sqrt(d)) * (cell_size_half));
}

fn getHeroOffY(move_timer: u32) i32 {
    return @intCast((((move_timer & 31) + 7) >> 4) << fbits);
}

fn drawTempMan(px: i32, py: i32, dx: i32, dy: i32, move_timer: u32, body_color: u32, cloth_color: u32, is_hero: bool, is_male: bool) void {
    const x = px + hero_aabb_local.x;
    const y = py + hero_aabb_local.y;
    const hero_y_off = getHeroOffY(move_timer);
    const is_mask = is_hero and hero_mask;
    const is_knife = is_hero and hero_knife;
    const ss = gain.math.sintau(fp32.toFloat(@bitCast(move_timer >> 1))) / 40.0;
    if (is_knife) {
        gfx.push(x + hero_w, y + (18 << fbits) - hero_y_off, ss);
        gfx.knife();
        gfx.restore();
    }
    if (is_mask) {
        gfx.push(x + (hero_w >> 1), y + (6 << fbits) + (hero_y_off >> 1), -ss / 2);
        gfx.hockeyMask(body_color);
        gfx.restore();
    }

    if (!is_hero) {
        if (!is_male) {
            // swimming top
            gfx.color(cloth_color);
            gfx.push(x + (hero_w >> 1), y + (14 << fbits) - hero_y_off, 0);
            if (dy >= 0) {
                gfx.circle(-3 << fbits, 0, 3 << fbits, 2 << fbits, 4);
                gfx.circle(3 << fbits, 0, 3 << fbits, 2 << fbits, 4);
            } else {
                gfx.line(-5 << fbits, 0, 5 << fbits, 0, 1 << fbits, 1 << fbits);
            }
            gfx.restore();
        } else {
            if (dy >= 0) {
                // draw NIPPLES
                gfx.push(x + (hero_w >> 1), y + (14 << fbits) - hero_y_off, 0);
                gfx.color(0xFF999999);
                gfx.circle(-3 << fbits, 0, 1 << fbits, 1 << fbits, 4);
                gfx.circle(3 << fbits, 0, 1 << fbits, 1 << fbits, 4);
                gfx.restore();
            }
        }
    }

    if (!is_mask) {
        gfx.push(x + (hero_w >> 1), y + (4 << fbits) - (hero_y_off >> 1), -ss);
        gfx.head(dx, dy, body_color, 0x0, 0xFF000000);
        gfx.restore();
    }

    if (!is_hero) {
        gfx.color(cloth_color);
        gfx.push(x + (hero_w >> 1), y + (20 << fbits) - hero_y_off, ss);
        gfx.trouses();
        gfx.restore();
    }

    gfx.quad(x, y - hero_y_off + (8 << fbits), hero_w, hero_h - hero_y_off - (2 << fbits) - (8 << fbits), body_color);

    gfx.quad(x - (2 << fbits), y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits, body_color);
    gfx.quad(x + hero_w, y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits, body_color);

    gfx.quad(x, y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits, body_color);
    gfx.quad(x + (6 << fbits), y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits, body_color);
}

fn drawHero() void {
    const body_color = Color32.lerp8888b(0xFF888888, 0xFFFFFFFF, hero_visible << 3);
    gfx.depth(hero.x, hero.y);
    drawTempMan(hero.x, hero.y, hero_look_x, hero_look_y, hero_move_timer, body_color, 0, true, true);
}

fn drawManShadow(x: i32, y: i32, move_timer: u32) void {
    const y_off = getHeroOffY(move_timer) >> fbits;
    gfx.shadow(x, y, 7 << fbits, @as(u32, @intCast(0x44 - 0x20 * y_off)) << 24);
}

fn drawPortals() void {
    for (0..portals_num) |i| {
        const p = portals[i];
        gfx.depth(0, p.rc.b());
        gfx.rect(p.rc.expandInt(-2), 0xFF000000);
        gfx.rect(p.rc, 0xFFFFFFFF);
    }
}

fn drawItem(i: usize) void {
    const item = items[i];
    const x = item.x;
    const y = item.y;
    gfx.depth(x, y);
    gfx.push(x, y - (8 << fbits), fp32.toFloat(@bitCast(gain.app.tic + (i << 4))) / 10);
    if (i == 0) {
        // draw mask
        gfx.hockeyMask(0xFFFFFFFF);
    } else if (i == 1) {
        gfx.knife();
        // draw knife
    } else {
        const rc = FPRect.fromInt(0, 0, 0, 0).expandInt(4);
        gfx.rect(rc, 0xFF00FF00);
        gfx.rect(rc.expandInt(1), 0xFF444444);
    }
    gfx.restore();
}

fn getMobColor(kind: i32) u32 {
    return switch (kind) {
        1 => 0xFFFFBB99,
        2 => 0xFFFFCCCC,
        3 => 0xFFCCAA66,
        else => 0xFFCCFF99,
    };
}

fn getMobTrousesColor(kind: i32) u32 {
    return switch (kind) {
        1 => 0xFFFF00FF,
        2 => 0xFFFFFF00,
        3 => 0xFFFF0000,
        else => 0xFF000000,
    };
}

fn drawMob(i: usize) void {
    const mob = mobs[i];
    var x = mob.x;
    var y = mob.y;

    gfx.depth(x, y);

    if (mob.danger_t > 0) {
        x += g_rnd.int(-1, 1) << fbits;
        y += g_rnd.int(-2, 0) << fbits;
        gfx.push(x + (8 << fbits), y - (32 << fbits), 0);
        gfx.scream();
        gfx.restore();
    }

    if (mob.attention > 0 and !mob.danger) {
        gfx.push(x, y - (32 << fbits), 0);
        gfx.attention();
        gfx.restore();
    }

    var body_color = getMobColor(mob.kind);
    body_color = Color32.lerp8888b(body_color, 0xFFFFFFFF, mob.hit_timer << 4);
    drawTempMan(x, y, mob.lx, mob.ly, mob.move_timer, body_color, getMobTrousesColor(mob.kind), false, mob.male);
}

fn getScreenScale() f32 {
    const short_side = @min(app.w, app.h);
    return @as(f32, @floatFromInt(short_side)) / (screen_size * camera_zoom);
}

pub fn render() void {
    gain.gfx.setupOpaquePass();
    gain.gfx.state.matrix = Mat2d.identity();

    const scale = getScreenScale();

    if (gain.pointers.primary()) |p| {
        if (p.is_down) {
            gain.gfx.state.z = 10 << fbits;
            const q = FPVec2.init(@intFromFloat(p.pos.x), @intFromFloat(p.pos.y));
            const s = FPVec2.init(@intFromFloat(p.start.x), @intFromFloat(p.start.y));
            const r = fp32.scale(fp32.fromInt(24), scale);
            const r2 = fp32.scale(fp32.fromInt(60), scale);
            const r3 = fp32.scale(fp32.fromInt(64), scale);
            gfx.color(0xFF999999);
            gfx.circle(q.x, q.y, r, r, 64);
            gfx.color(0xFF444444);
            gfx.circle(s.x, s.y, r2, r2, 64);
            gfx.color(0xFF111111);
            gfx.circle(s.x, s.y, r3, r3, 64);
        }
    }

    gain.gfx.state.z = 4 << fbits;

    const camera_x = hero.x;
    const camera_y = hero.y;
    gain.gfx.state.matrix = gain.gfx.state.matrix
        .translate(Vec2.fromIntegers(app.w >> 1, app.h >> 1))
        .scale(Vec2.splat(scale))
        .translate(Vec2.fromIntegers(-camera_x, -camera_y));

    const occ_scale = 1 / scale;
    const sc_w = fp32.scale(@bitCast(app.w), occ_scale);
    const sc_h = fp32.scale(@bitCast(app.h), occ_scale);
    const camera_aabb = FPRect.init(
        camera_x - (sc_w >> 1),
        camera_y - (sc_h >> 1),
        sc_w,
        sc_h,
    ).expandInt(-32);

    drawHero();

    drawPortals();

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

    particles.draw(camera_aabb);
    drawMap(camera_aabb);
    drawBack(camera_aabb);

    gain.gfx.setupBlendPass();
    gain.gfx.state.z = 4 << fbits;

    drawManShadow(hero.x, hero.y, hero_move_timer);
    particles.drawShadows(camera_aabb);

    for (0..mobs_num) |i| {
        const mob = mobs[i];
        if (mob.kind != 0) {
            drawManShadow(mob.x, mob.y, mob.move_timer);
        }
    }

    for (0..items_num) |i| {
        const item = items[i];
        if (item.kind != 0) {
            gfx.shadow(item.x, item.y, 8 << fbits, colors.shadow);
        }
    }

    {
        gain.gfx.state.z = (1 << 15) << fbits;
        //gfx.state.matrix = Mat2d.identity();
        const space_x: i32 = @divTrunc(512 << fbits, 14);
        gain.gfx.state.matrix = gain.gfx.state.matrix
            .translate(Vec2.fromIntegers(camera_aabb.cx(), camera_aabb.y))
            .translate(Vec2.fromIntegers((-(512 << fbits) >> 1), 20 << fbits));
        for (0..13) |i| {
            var rc = FPRect.init(0, 0, 0, 0);

            gain.gfx.state.matrix = gain.gfx.state.matrix.translate(Vec2.fromIntegers(space_x, 0));
            const mat = gain.gfx.state.matrix;
            gain.gfx.state.matrix = gain.gfx.state.matrix.rotate(0.1); // * @as(f32, @floatFromInt(i / 3)));
            //gfx.state.matrix = gfx.state.matrix.rotate(0.1);
            gfx.rect(rc.expandInt(12).translate(1 << fbits, 1 << fbits), 0xFF111111);
            gfx.rect(rc.expandInt(10), 0xFFCCCCCC);
            if (i < kills) {
                gfx.color(0xFF880000);
                rc = rc.expandInt(8);
                gfx.line(rc.x, rc.y, rc.r(), rc.b(), 4 << fbits, 2 << fbits);
                gfx.line(rc.x, rc.b(), rc.r(), rc.y, 3 << fbits, 4 << fbits);
            }
            gain.gfx.state.matrix = mat;
        }
    }

    drawMenu();
}

fn drawMap(camera_rc: FPRect) void {
    const _cx = camera_rc.x >> cell_size_bits;
    const _cy = camera_rc.y >> cell_size_bits;
    const _cw = camera_rc.w >> cell_size_bits;
    const _ch = camera_rc.h >> cell_size_bits;
    const ccx0: usize = @intCast(@max(0, _cx));
    const ccx1: usize = @intCast(@max(0, _cx + _cw + 2));
    const ccy0: usize = @intCast(@max(0, _cy));
    const ccy1: usize = @intCast(@max(0, _cy + _ch + 2));

    //drawPath();

    const matrix = gain.gfx.state.matrix;
    for (ccy0..ccy1) |cy| {
        const index = cy << map.size_bits;
        for (ccx0..ccx1) |cx| {
            const cell = map.map[index + cx];
            if (cell != 0) {
                gain.gfx.state.z = 2 << fbits;
                const x: i32 = @intCast((cx << cell_size_bits) + cell_size_half);
                const y: i32 = @intCast((cy << cell_size_bits) + cell_size_half);
                // const sz0: i32 = invDist(hero.x, hero.y, x, y);
                // const sz = sz0 + ((@as(i32, @intCast((app.tic >> 3) + (cx *% cy))) & 7) << (fbits - 4));
                // const cell_size_v = Vec2.fromIntegers(sz << 1, sz << 1);
                // gfx.state.matrix = matrix
                //     .translate(Vec2.fromIntegers(x, y))
                //     .rotate(std.math.pi * (1 - @as(f32, @floatFromInt(sz0)) / (cell_size_half)));
                // gfx.quad(Vec2.fromIntegers(-sz, -sz), cell_size_v, 0xFF338866);

                var color = map.colormap[map.colors[map.addr(cx, cy)]];
                if (cell > 1) {
                    color = Color32.lerp8888b(color, 0xFF000000, 16);
                }
                gfx.rect(FPRect.init(x, y, 0, 0).expand(cell_size_half, cell_size_half), color);

                if (map.map[index + cx - map.size] == 0) {
                    gfx.rect(FPRect.init(x, y - cell_size, 0, 0).expand(cell_size_half, cell_size_half), 0xFF223322);
                }

                if (cell > 1) {
                    gfx.depth(x, y + cell_size_half);
                    if (cell == 2) {
                        for (0..2) |iy| {
                            const iiy: i32 = @intCast(iy);
                            gfx.quad(x - cell_size_half, y + (iiy * cell_size_half >> 1), cell_size, 4 << fbits, 0xFF664433);
                        }
                        for (0..5) |ix| {
                            const iix: i32 = @intCast(ix);
                            gfx.quad(x - cell_size_half + (iix * cell_size >> 2), y, 2 << fbits, cell_size_half, 0xFF664433);
                        }
                    } else if (cell == 3) {
                        const ss = gain.math.sintau(fp32.toFloat(@bitCast(app.tic +% (cx * cy))) / 8) / 100.0;
                        gfx.depth(x, y + (cell_size_half >> 1));
                        gfx.color(0xFF336633);
                        gfx.push(x, y + (8 << fbits), ss);
                        gfx.circle(0, -(24 << fbits), 16 << fbits, 16 << fbits, 8);
                        gfx.quad(-(2 << fbits), -cell_size_half, 4 << fbits, cell_size_half, 0xFF664400);
                        gfx.restore();
                    } else if (cell == 4) {
                        // const ss: f32 = 0.1 * gain.math.sintau(fp32.toFloat(@bitCast(app.tic +% (cx * cy))) / 8);
                        gfx.push(x, y + (8 << fbits), 0);
                        gfx.color(0xFF336633);
                        gfx.circle(0, -4 << fbits, 10 << fbits, 12 << fbits, 8);
                        gfx.circle(-8 << fbits, 0, 8 << fbits, 8 << fbits, 8);
                        gfx.circle(8 << fbits, 0, 8 << fbits, 8 << fbits, 8);
                        //gfx.quad(x - cell_size_half, y, cell_size, cell_size_half, 0xFF003300);
                        gfx.restore();
                    }
                }
            } else {
                // const x: i32 = @intCast((cx << cell_size_bits) + cell_size_half);
                // const y: i32 = @intCast((cy << cell_size_bits) + cell_size_half);
                //drawRect(FPRect.init(x, y, 0, 0).expand(cell_size_half, cell_size_half), 0xFF001100);
            }
        }
    }
    gain.gfx.state.matrix = matrix;
}

fn drawPath() void {
    const rc = FPRect.init(cell_size_half, cell_size_half, 0, 0).expandInt(4);
    for (0..map.path_num) |i| {
        gfx.rect(rc.translate(map.path_x[i] << cell_size_bits, map.path_y[i] << cell_size_bits), if (map.path_num > 0) 0xFFFFFFFF else 0xFFFFFF00);
    }
    gfx.rect(rc.translate(map.path_dest_x << cell_size_bits, map.path_dest_y << cell_size_bits), 0xFFFF0000);
}

fn drawBack(camera_rc: FPRect) void {
    gain.gfx.state.z = 1 << fbits;
    gfx.rect(camera_rc, 0xFF222222);
    gain.gfx.state.z = 0;
    gfx.rect(camera_rc.expandInt(128 << fbits), 0xFF000000);
}

// MENU
var game_state: u8 = 0;
var no_black_screen_t: u8 = 0;
var no_black_screen_target: u8 = 0;

fn updateMenu() void {
    if (game_state == 0) {
        if (gain.pointers.primary()) |p| {
            if (p.down) {
                game_state = 1;
                no_black_screen_target = 15;
            }
        }
    }
    if (no_black_screen_t < no_black_screen_target) {
        no_black_screen_t += 1;
    } else if (no_black_screen_t > no_black_screen_target) {
        no_black_screen_t -= 1;
    }
}

fn drawMenu() void {
    // draw text
    if (no_black_screen_t < 15) {
        gain.gfx.state.matrix = Mat2d.identity(); //.scale(Vec2.splat(scale * (1 << fbits)));
        gfx.rect(FPRect.init(0, 0, @intCast(app.w), @intCast(app.h)), Color32.lerp8888b(
            0xFF000000,
            0x00000000,
            no_black_screen_t << 4,
        ));
    }
}
