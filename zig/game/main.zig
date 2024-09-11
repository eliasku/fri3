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
const texts = @import("texts.zig");
const camera = @import("camera.zig");
const g = @import("g.zig");

const Hero = struct {
    x: i32,
    y: i32,
};

const Item = struct {
    pos: FPVec2,
    vel: FPVec2,
    kind: u8,
    inactive: u8,
    alive: bool,
    magnit: bool,

    fn onMap(x: i32, y: i32, kind: u8) Item {
        return .{
            .pos = map.coordToPos(x, y),
            .vel = .{
                .x = 0,
                .y = 0,
            },
            .kind = kind,
            .inactive = 0,
            .alive = true,
            .magnit = false,
        };
    }
};

const fbits = fp32.fbits;
const cell_size_bits = map.cell_size_bits;
const cell_size = map.cell_size;
const cell_size_half = map.cell_size_half;

var level: u32 = 0;
var kills: u32 = 0;
const camera_zoom = 1;
const screen_size = 512 << fbits;
const screen_size_half = screen_size >> 1;

const hero_w = 10 << fbits;
const hero_h = 24 << fbits;
const hero_place_w = 12 << fbits;
const hero_place_h = 4 << fbits;

var hero_move_timer: i32 = undefined;
var hero_look_x: i32 = undefined;
var hero_look_y: i32 = undefined;
var hero: Hero = undefined;
const hero_aabb_local = FPRect.init(-(hero_w >> 1), -hero_h, hero_w, hero_h);
const hero_ground_aabb_local = FPRect.init(-(hero_place_w >> 1), -(hero_place_h >> 1), hero_place_w, hero_place_h);
var hero_visible: u32 = 0;
const hero_visible_thr = 8;
const hero_visible_max = 31;
var hero_knife = false;
var hero_mask = false;
var hero_13 = false;
var hero_ready = false;
const hero_hp_max = 16;
var hero_hp: i32 = undefined;
var hero_xp: i32 = undefined;
const hero_xp_max = 16;
var hero_attack_t: i32 = undefined;
var hero_forced: ForcedMove = undefined;
var hero_level_up: u32 = undefined;

const Portal = struct {
    src: FPVec2,
    pos: FPVec2,
    dest: FPVec2,
};

const portals_max = 32;
var portals: [portals_max]Portal = undefined;
var portals_num: u32 = undefined;

fn addPortal(x: i32, y: i32, dx: i32, dy: i32, sx: i32, sy: i32) void {
    if (portals_num < portals_max) {
        portals[portals_num] = .{
            .pos = map.coordToPos(x, y),
            .dest = map.coordToPos(dx, dy),
            .src = map.coordToPos(sx, sy),
        };
        portals_num += 1;
        map.setGen(x, y);
        map.setGen(dx, dy);
    }
}

const ForcedMove = struct {
    v: FPVec2,
    t: i32,

    fn zero() ForcedMove {
        return .{
            .v = FPVec2.init(0, 0),
            .t = 0,
        };
    }

    fn init(x: i32, y: i32, t: i32) ForcedMove {
        return .{
            .v = FPVec2.init(x, y),
            .t = t,
        };
    }
};

const student_hp_max = 4;
const guard_hp_max = 8;
const hit_timer_max = 31;
const Mob = struct {
    x: i32,
    y: i32,
    kind: u8,
    move_timer: i32,
    lx: i32,
    ly: i32,
    forced: ForcedMove,
    ai_timer: i32,
    hp: i32,
    hp_max: i32,
    hit_timer: u32,
    target_map_x: i32,
    target_map_y: i32,
    danger_t: i32,
    attention: u32,
    text_t: u32,
    text_i: u32,
    attack_t: i32,
    bleed: u8,
    danger: bool,
    male: bool,
    is_student: bool,
};

fn placeMob(x: i32, y: i32, kind: u32, male: bool, student: bool) void {
    if (mobs_num < mobs_max) {
        const max_hp: i32 = if (student) student_hp_max else guard_hp_max;
        mobs[mobs_num] = .{
            .x = cell_size_half + (x << cell_size_bits),
            .y = cell_size_half + (y << cell_size_bits),
            .kind = @truncate(kind),
            .move_timer = 0,
            .lx = 0,
            .ly = 0,
            .forced = ForcedMove.zero(),
            .ai_timer = 0,
            .hp_max = max_hp,
            .hp = max_hp,
            .hit_timer = 0,
            .target_map_x = 0,
            .target_map_y = 0,
            .danger_t = 0,
            .danger = false,
            .attention = 0,
            .male = male,
            .text_t = 0,
            .text_i = 0,
            .is_student = student,
            .attack_t = 0,
            .bleed = 0,
        };
        mobs_num += 1;
    }
}

const mobs_max = 128;
var mobs: [mobs_max]Mob = undefined;
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
    -8,
    -8,
    16,
    16,
);

const items_max = 128;
var items: [items_max]Item = undefined;
var items_num: u32 = undefined;

fn placeItem(x: i32, y: i32, kind: u8) void {
    if (items_num < items_max) {
        items[items_num] = Item.onMap(x, y, kind);
        items_num += 1;
    }
}

fn spawnItem(x: i32, y: i32, n: u32) void {
    for (0..n) |_| {
        const d = g.rnd.frange(8, 12);
        const a = g.rnd.float();

        items[items_num] = .{
            .pos = .{
                .x = x,
                .y = y,
            },
            .vel = .{
                .x = fp32.fromFloat(d * gain.math.costau(a)),
                .y = fp32.fromFloat(d * gain.math.sintau(a) / 2),
            },
            .kind = 1,
            .inactive = 8,
            .alive = true,
            .magnit = true,
        };
        items_num += 1;
    }
}

fn setMapPlus(x: i32, y: i32, kind: map.Cell) void {
    map.set(x, y, kind);
    map.set(x - 1, y, kind);
    map.set(x + 1, y, kind);
    map.set(x, y - 1, kind);
    map.set(x, y + 1, kind);
}

fn resetAll() void {
    @memset(&map.map, 0);
    @memset(&map.colors, 0);
    @memset(&map.gen, 0);
    items_num = 0;
    mobs_num = 0;
    portals_num = 0;
    kills = 0;
    hero_level_up = 0;
    particles.reset();
    unsetAllTexts();
    hero_visible = 0;
    hero_hp = hero_hp_max;
    hero_xp = 0;
    hero_knife = false;
    hero_mask = false;
    hero_13 = false;
    hero_ready = false;
    hero_attack_t = 0;
    hero_forced = ForcedMove.zero();
}

var zones: [32]FPRect = undefined;
var zones_num: u32 = undefined;
fn generateZone(rnd: *gain.math.Rnd, parent: FPRect, depth: u32) void {
    if (zones_num == 16) return;
    if (depth != 6 and parent.w > 32 and parent.h > 32) {
        if (depth & 1 == 1) {
            // split A|B
            const mx = parent.cx() + rnd.int(-parent.w >> 3, parent.w >> 3);
            generateZone(rnd, FPRect.init(parent.x, parent.y, mx - parent.x, parent.h), depth + 1);
            generateZone(rnd, FPRect.init(mx, parent.y, parent.r() - mx, parent.h), depth + 1);
        } else {
            // split
            // A
            // -
            // B
            const my = parent.cy() + rnd.int(-parent.h >> 3, parent.h >> 3);
            generateZone(rnd, FPRect.init(parent.x, parent.y, parent.w, my - parent.y), depth + 1);
            generateZone(rnd, FPRect.init(parent.x, my, parent.w, parent.b() - my), depth + 1);
        }
    } else {
        zones[zones_num] = parent.expand(-4, -4);
        zones_num += 1;
    }
}

fn initLevel() void {
    resetAll();

    var rnd = gain.math.Rnd{ .seed = (31 + level << 1) };

    zones_num = 0;
    generateZone(&rnd, FPRect.init(2, 2, map.size - 4, map.size - 4), 0);

    var x: i32 = zones[0].cx();
    var y: i32 = zones[0].cy();
    var room_x = x;
    var room_y = y;
    var act: u32 = 0;
    var act_timer: u32 = 4;

    hero.x = (x << cell_size_bits) + cell_size_half;
    hero.y = (y << cell_size_bits) + cell_size_half;

    var gender_i: u32 = 0;
    var mob_kind_i: u8 = 0;
    var room_index: u32 = 0;
    var students_total: i32 = 0;
    //const zone_rc = FPRect.init(2, 2, map.size - 4, map.size - 4);

    var zone_i: u32 = 0;
    while (true) {
        map.current_color = @truncate(room_index % colors.tile.len);
        const zone_rc = zones[zone_i];
        room_x = x;
        room_y = y;
        map.setGen(x, y);
        const iters = 32 + (room_index << 3);
        var portals_gen: u32 = if (room_index > 2) 1 else 0;
        var items_gen: u32 = 10;
        var mobs_gen: u32 = room_index << 1;
        var guards_gen: u32 = if (room_index > 1) (room_index - 1) else 0;
        for (0..iters) |_| {
            switch (act) {
                0 => x = @min(x + 1, zone_rc.r()),
                1 => x = @max(x - 1, zone_rc.x),
                2 => y = @min(y + 1, zone_rc.b()),
                3 => y = @max(y - 1, zone_rc.y),
                else => unreachable,
            }

            setMapPlus(x, y, 1);
            act_timer -= 1;
            if (act_timer == 0) {
                act_timer = 1 + (rnd.next() & 3);
                const new_act = rnd.next() & 3;
                if (new_act != act) {
                    act = new_act;
                }
            }
            if (map.isGenFree(x, y)) {
                const pp = rnd.next() & 7;
                switch (pp) {
                    0 => if (mobs_gen > 0) {
                        placeMob(x, y, mob_kind_i % 3, gender_i & 1 == 0, true);
                        map.setGen(x, y);
                        gender_i += 1;
                        mobs_gen -= 1;
                        mob_kind_i +%= 1;
                        students_total += 1;
                    },
                    1 => if (guards_gen > 0) {
                        placeMob(x, y, mob_kind_i % 3, false, false);
                        map.setGen(x, y);
                        guards_gen -= 1;
                        mob_kind_i +%= 1;
                    },
                    2 => if (portals_num > 2 and portals_gen > 0) {
                        const p = portals[portals_num - 1];
                        addPortal(x, y, p.src.x >> cell_size_bits, p.src.y >> cell_size_bits, room_x, room_y);
                        portals_gen -= 1;
                    },
                    // else => {},
                    // else => if (items_gen > 0) {
                    //     placeItem(x, y, @intCast(rnd.int(1, 2)));
                    //     map.setGen(x, y);
                    //     items_gen -= 1;
                    // },
                    else => if (items_num < 3 or pp == 3) {
                        placeItem(x, y, @truncate(rnd.next() & 1));
                        map.setGen(x, y);
                        items_gen -= 1;
                    },
                }
            }
        }

        if (students_total < 13) {
            // not finish
            zone_i += 1;
            const nx = zones[zone_i].cx();
            const ny = zones[zone_i].cy();
            addPortal(x, y, nx, ny, room_x, room_y);
            x = nx;
            y = ny;
        } else {
            break;
        }
        room_index += 1;
    }

    addPortal(x, y, hero.x >> cell_size_bits, hero.y >> cell_size_bits, room_x, room_y);

    for (0..map.map.len) |i| {
        if (map.map[i] == 1 and map.gen[i] == 0 and rnd.next() & 7 == 0) {
            map.map[i] = @intCast(rnd.int(2, 4));
        }
    }
}

fn mobSetMove(mob: *Mob, dx: i32, dy: i32, speed: i32) void {
    const v = FPVec2.init(dx, dy).rescale(speed);
    mob.*.lx = v.x;
    mob.*.ly = v.y;
}

fn setMobRandomMovement(mob: *Mob) void {
    mobSetMove(
        mob,
        g.rnd.int(-16, 16),
        g.rnd.int(-16, 16),
        if (g.rnd.next() & 7 == 0) 0 else 1 << fbits,
    );
}

fn mobRunAwayBeh(mob: *Mob, x: i32, y: i32, speed: i32) void {
    mobSetMove(mob, mob.x - x, mob.y - y, speed);
}

fn isHeroReady() bool {
    return hero_knife and hero_mask and hero_hp != 0;
}

fn addKill() void {
    kills += 1;
    if (kills >= 13) {
        camera.zoom = 1;
        setGameState(2);
    }
}

fn updateMobs() void {
    const hero_aabb = hero_ground_aabb_local.translate(hero.x, hero.y).expandInt(16);
    for (0..mobs_num) |i| {
        const mob: *Mob = &mobs[i];
        if (mob.hp != 0) {
            const hero_is_danger = hero_visible > hero_visible_thr and hero_ready;
            const dist_to_hero = fp32.dist(hero.x, hero.y, mob.x, mob.y);
            const danger = hero_is_danger and dist_to_hero < (100 << fbits);
            if (danger) {
                mob.*.attention += 1;
                if (mob.attention > 32 and !mob.danger) {
                    mob.*.danger_t = if (mob.is_student) 32 else 4;
                    sfx.fear();
                    mob.*.danger = true;
                }
            } else {
                if (mob.*.danger_t > 0 or hero_hp <= 0 or (!mob.is_student and !hero_is_danger)) {
                    mob.*.danger = false;
                }
                if (mob.attention > 0) {
                    mob.*.attention -= 1;
                }
            }

            if (mob.*.ai_timer <= 0) {
                mob.*.ai_timer = @intCast(g.rnd.next() & 0x3f);
                if (mob.danger) {
                    mob.*.target_map_x = 0;
                    mob.*.target_map_y = 0;
                    if (mob.is_student) {
                        if (findClosestPortal(mob.x, mob.y)) |portal| {
                            map.findPath(mob.x, mob.y, portal.pos.x, portal.pos.y);
                            if (map.path_num > 1) {
                                mob.*.target_map_x = map.path_x[1];
                                mob.*.target_map_y = map.path_y[1];
                            }
                        }
                    } else {
                        map.findPath(mob.x, mob.y, hero.x, hero.y);
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
                const target = map.coordToPos(mob.*.target_map_x, mob.*.target_map_y);
                mob.*.lx = @max(-speed, @min(speed, target.x - mob.x));
                mob.*.ly = @max(-speed, @min(speed, target.y - mob.y));
                if (mob.x + mob.*.lx == target.x and mob.y + mob.*.ly == target.y) {
                    mob.*.ai_timer = 0;

                    // if (testPortals(mob_hitbox_local.translate(mob.x, mob.y))) |portal| {
                    if (pointInPortal(mob.x, mob.y)) |portal| {
                        mob.x = portal.dest.x;
                        mob.y = portal.dest.y;
                        mob.*.danger = false;
                        sfx.portal();
                    }
                }
            } else {
                if (danger) {
                    if (mob.is_student or mob.attack_t > 0) {
                        mobRunAwayBeh(mob, hero.x, hero.y, speed);
                    } else {
                        mobSetMove(mob, hero.x - mob.x, hero.y - mob.y, speed);
                    }
                }
                mob.*.ai_timer -= 1;
            }
            // block move to hidden hero
            if (!danger and dist_to_hero < (32 << fbits) and hero_hp != 0) {
                mobRunAwayBeh(mob, hero.x, hero.y, speed);
            }
            var move_vector = FPVec2.init(mob.lx, mob.ly);
            if (mob.forced.t != 0) {
                move_vector = mob.forced.v;
                mob.*.forced.t -= 1;
            }
            if (move_vector.x != 0 or move_vector.y != 0) {
                mob.*.move_timer +%= 2;
                const new_x = mob.x + move_vector.x;
                const new_y = mob.y + move_vector.y;
                if (!map.testRect(mob_hitbox_local.translate(new_x, mob.y))) {
                    mob.*.x = new_x;
                } else {
                    //mob.*.lx = -mob.*.lx;
                }
                if (!map.testRect(mob_hitbox_local.translate(mob.x, new_y))) {
                    mob.*.y = new_y;
                } else {
                    //mob.*.ly = -mob.*.ly;
                }
            } else {
                mob.*.move_timer = 0;
            }

            if (mob.hit_timer != 0) {
                mob.*.hit_timer -= 1;
            }

            if (mob.hp != mob.hp_max and g.rnd.next() & 0x7 == 0 and mob.bleed != 0) {
                particles.add(1, mob.x, mob.y, 20 << fbits);
                mob.bleed -= 1;
            }
            if (game_state == 1) {
                if (mob.text_t > 0) {
                    mob.*.text_t -= 1;
                    if (mob.*.text_t == 0) {
                        clearMobText(i);
                    } else {
                        setText(@bitCast(i + 1), texts.mob[mob.text_i], FPVec2.init(mob.x, mob.y - (48 << fbits)), colors.paper, 2);
                    }
                } else {
                    if (g.rnd.next() & 63 == 0) {
                        var start_index: u32 = 5;
                        if (mob.danger) {
                            if (mob.is_student) {
                                start_index = 0;
                            } else {
                                start_index = 10;
                            }
                        }
                        selectMobText(i, start_index + (g.rnd.next() % 5));
                        // pick text index
                    }
                }
            }

            if (hero_hp != 0) {
                const mob_aabb = mob_hitbox_local.translate(mob.x, mob.y);
                const mob_overlaps_hero = mob_aabb.overlaps(hero_aabb);
                if (mob_overlaps_hero) {
                    if (mob.hit_timer < (hit_timer_max >> 2) and hero_attack_t > 24) {
                        mob.*.hp = @max(0, mob.hp - (if (!mob.danger) mob.hp_max else g.rnd.int(2, 4)));
                        mob.*.hit_timer = hit_timer_max;
                        mob.forced = .{
                            .v = FPVec2.init(mob.x - hero.x, mob.y - hero.y).rescale(3 << fbits),
                            .t = 8,
                        };
                        sfx.hit();
                        const kx = mob.x;
                        const ky = mob.y;
                        particles.add(32, kx, ky, 20 << fbits);
                        mob.*.bleed = 8;
                        if (mob.hp == 0) {
                            spawnItem(mob.x, mob.y, 4);
                            camera.shakeM();
                            var c = getMobColor(mob.kind);
                            var rc = FPRect.init(0, 0, 0, 4 << fbits).expandInt(5);
                            particles.addPart(kx, ky, c, 1, rc);
                            if (!mob.is_student) {
                                c = colors.guards[mob.kind];
                            }
                            rc = FPRect.init(0, 0, 0, 0).expand(2 << fbits, 5 << fbits);
                            particles.addPart(kx, ky, c, 4, rc);
                            particles.addPart(kx, ky, c, 4, rc);
                            particles.addPart(kx, ky, c, 4, rc);
                            particles.addPart(kx, ky, c, 4, rc);
                            particles.addPart(kx, ky, c, 4, FPRect.init(0, 0, 0, 0).expandInt(5));

                            clearMobText(i);

                            if (mob.is_student) {
                                addKill();
                            }
                        } else {
                            camera.shakeS();
                        }
                    }

                    if (!mob.is_student and mob.attack_t > 24) {
                        mob.attack_t = 24;
                        hero_forced = .{
                            .v = FPVec2.init(hero.x - mob.x, hero.y - mob.y).rescale(3 << fbits),
                            .t = 8,
                        };
                        hitHero();
                    }
                }
            }

            if (mob.attack_t > 0) {
                mob.*.attack_t -= 1;
            } else if (danger and !mob.is_student) {
                // attack sfx;
                mob.*.attack_t = 32;
            }
        }
    }
}

fn hitHero() void {
    sfx.hit();
    hero_hp = @max(0, hero_hp - g.rnd.int(1, 3));
    const kx = hero.x;
    const ky = hero.y;
    particles.add(32, kx, ky, 20 << fbits);
    if (hero_hp == 0) {
        camera.shakeM();
        var rc = FPRect.init(0, 0, 0, 4 << fbits).expandInt(5);
        particles.addPart(kx, ky, colors.hero_face_color, 1, rc);
        particles.addPart(kx, ky, colors.hero_face_color, 2, rc);
        particles.addPart(kx, ky, colors.hero_face_color, 3, rc);
        rc = FPRect.init(0, 0, 0, 0).expand(2 << fbits, 5 << fbits);
        particles.addPart(kx, ky, colors.hero_body_color, 4, rc);
        particles.addPart(kx, ky, colors.hero_body_color, 4, rc);
        particles.addPart(kx, ky, colors.hero_body_color, 4, rc);
        particles.addPart(kx, ky, colors.hero_body_color, 4, rc);
        particles.addPart(kx, ky, colors.hero_body_color, 4, FPRect.init(0, 0, 0, 0).expandInt(5));
        unsetText(0);
    } else {
        if (g.is_debug) {
            spawnItem(hero.x, hero.y, 1);
        }
        camera.shakeS();
    }
}

fn selectMobText(i: u32, phrase: u32) void {
    mobs[i].text_i = phrase;
    mobs[i].text_t = texts.mob[phrase].len << 2;
}

fn clearMobText(i: u32) void {
    unsetText(@bitCast(i + 1));
}

fn getInputVector(speed: i32) FPVec2 {
    const keys = gain.keyboard;

    if (g.is_debug) {
        if (game_state == 1) {
            if (keys.down[keys.Code.enter] != 0) {
                addKill();
            }
            if (keys.down[keys.Code.space] != 0) {
                hitHero();
            }
        }
    }

    // 5190
    var dx: i32 = 0;
    var dy: i32 = 0;
    if ((keys.down[keys.Code.a] | keys.down[keys.Code.arrow_left]) != 0) {
        dx -= 1;
    }
    if ((keys.down[keys.Code.d] | keys.down[keys.Code.arrow_right]) != 0) {
        dx += 1;
    }
    if ((keys.down[keys.Code.w] | keys.down[keys.Code.arrow_up]) != 0) {
        dy -= 1;
    }
    if ((keys.down[keys.Code.s] | keys.down[keys.Code.arrow_down]) != 0) {
        dy += 1;
    }

    if (gain.pointers.primary()) |p| {
        if (p.is_down) {
            const dist = camera.ui_scale * (48 << fbits);
            const d = p.pos.sub(p.start);
            const l = d.length();
            if (l > dist / 2) {
                if (l > dist) {
                    p.start = p.pos.sub(d.normalize().scale(dist));
                }
                dx = @intFromFloat(d.x);
                dy = @intFromFloat(d.y);
            }
        }
    }

    return FPVec2.init(dx, dy).rescale(speed);
}

fn updateHeroMovement() void {
    if (hero_hp != 0 and game_state == 1) {
        const max_speed: i32 = if (hero_visible > 8) 2 else 1;
        const speed: i32 = @min(max_speed, 1 + (hero_move_timer >> 4)) << fbits;
        const move_dir = getInputVector(speed);
        var move_v = move_dir;
        if (hero_forced.t != 0) {
            move_v = hero_forced.v;
            hero_forced.t -= 1;
        }

        if (move_dir.x != 0 or move_dir.y != 0) {
            hero_move_timer +%= 2;
            hero_look_x = move_dir.x;
            hero_look_y = move_dir.y;

            if ((hero_move_timer & 0x1F) == 0) {
                sfx.step(hero_visible);
            }
        } else {
            hero_move_timer = 0;
        }

        const new_x = hero.x + move_v.x;
        const new_y = hero.y + move_v.y;

        if (!map.testRect(hero_ground_aabb_local.translate(new_x, hero.y))) {
            hero.x = new_x;
        }
        if (!map.testRect(hero_ground_aabb_local.translate(hero.x, new_y))) {
            hero.y = new_y;
        }
    }
}

fn updateHero() void {
    if (hero_hp == 0) return;

    const aabb = hero_ground_aabb_local.translate(hero.x, hero.y);
    const aabb_item_pick = aabb.expandInt(8);
    for (0..items_num) |i| {
        const item = items[i];
        if (item.alive) {
            if (item.inactive == 0 and aabb_item_pick.test2(item.pos.x, item.pos.y)) {
                if (i == 0 and !hero_mask) {
                    hero_mask = true;
                    //levelup();
                    //camera.shakeS();
                } else if (i == 1 and !hero_knife) {
                    hero_knife = true;
                    //levelup();
                    //camera.shakeS();
                } else if (i == 2 and !hero_13) {
                    hero_13 = true;
                    //levelup();
                    //camera.shakeS();
                }
                if (!hero_ready and hero_mask and hero_knife and hero_13) {
                    hero_ready = true;
                    //levelup();
                    //camera.shakeM();
                }
                if (i > 2) {
                    if (item.kind == 0) {
                        if (hero_hp < hero_hp_max) {
                            hero_hp += 1;
                        } else {
                            continue;
                        }
                    } else {
                        hero_xp += 1;
                        if (hero_xp == hero_xp_max) {
                            hero_xp = 0;
                            hero_hp = hero_hp_max;
                            levelup();
                        }
                    }
                }
                items[i].alive = false;
                sfx.collect();
            }
            if (item.inactive != 0) {
                items[i].inactive -= 1;
            }
            if (item.magnit) {
                if (item.inactive == 0) {
                    const vt = FPVec2.init(hero.x - item.pos.x, hero.y - item.pos.y).rescale(8 << fbits);
                    items[i].vel.x = item.vel.x + ((vt.x - item.vel.x) >> 4);
                    items[i].vel.y = item.vel.y + ((vt.y - item.vel.y) >> 4);
                }
                items[i].pos.x += item.vel.x;
                items[i].pos.y += item.vel.y;
            }
        }
    }

    if (map.getPoint(aabb.cx(), aabb.cy()) > 1) {
        if (hero_visible > 0) {
            hero_visible -= 1;
        }
    } else if (hero_visible < hero_visible_max) {
        hero_visible += 1;
    }

    if (hero_ready) {
        if (pointInPortal(hero.x, hero.y)) |portal| {
            hero.x = portal.dest.x;
            hero.y = portal.dest.y;
            no_black_screen_t = 0;
            no_black_screen_target = 15;
            sfx.portal();
            camera.zoom = 0.5;
        }

        if (hero_attack_t > 0) {
            hero_attack_t -= 1;
        }
        if (hero_attack_t == 0 and hero_visible > 8) {
            hero_attack_t = 32;
            sfx.attack();
        }
    }
}

fn updateGame() void {
    updateHero();
    updateMobs();
}

fn pointInPortal(x: i32, y: i32) ?*Portal {
    for (0..portals_num) |i| {
        const pos = portals[i].pos;
        if (fp32.dist(x, y, pos.x, pos.y) < (8 << fbits)) {
            return &portals[i];
        }
    }
    return null;
}

fn findClosestPortal(x: i32, y: i32) ?*Portal {
    var min_dist: i32 = 1000000;
    var min_portal: ?*Portal = null;
    for (0..portals_num) |i| {
        const pos = portals[i].pos;
        const dist = fp32.dist(x, y, pos.x, pos.y);
        if (dist < min_dist) {
            min_dist = dist;
            min_portal = &portals[i];
        }
    }
    return min_portal;
}

fn levelup() void {
    if (hero_level_up == 0) {
        sfx.levelUp();
        hero_level_up = 48;
        hero_hp = hero_hp_max;
        setText(0, "LEVEL UP", FPVec2.init(hero.x, hero.y), colors.blood_light, 4);
    }
}

var hero_text_i: u32 = 0;
var hero_text_t: u32 = 0;
pub fn update() void {
    if (hero_level_up != 0) {
        hero_level_up -= 1;
    } else {
        updateHeroMovement();
        camera.update(hero.x, hero.y);

        updateGameState();
        updateGame();

        sfx.update();
        particles.update();

        if (hero_level_up == 0 and hero_visible > 8 and game_state == 1 and hero_hp != 0) {
            if (hero_text_t > 0) {
                const msg = texts.hero[hero_text_i];
                setText(0, msg, FPVec2.init(hero.x, hero.y - (48 << fbits)), colors.blood_light, 2);
                hero_text_t -= 1;
            } else {
                unsetText(0);
                if (g.rnd.next() & 0x7F == 0) {
                    hero_text_i = g.rnd.next() % texts.hero.len;
                    hero_text_t = texts.hero[hero_text_i].len << 2;
                }
            }
        }
    }
}

fn setText(handle: i32, text: []const u8, pos: FPVec2, color: u32, size: i32) void {
    if (camera.rc.test2(pos.x, pos.y)) {
        const xy = Vec2.fromIntegers(pos.x, pos.y).transform(camera.matrix);
        gain.js.text(handle, @intFromFloat(xy.x), @intFromFloat(xy.y), color, size, text.ptr, text.len);
    } else {
        unsetText(handle);
    }
}

fn unsetText(handle: i32) void {
    gain.js.text(handle, 0, 0, 0, 0, "", 0);
}

fn unsetAllTexts() void {
    for (0..mobs_max + 3) |i| {
        unsetText(@bitCast(i));
    }
}

fn getHeroOffY(move_timer: i32) i32 {
    return @intCast((((move_timer & 31) + 7) >> 4) << fbits);
}

fn drawTempMan(px: i32, py: i32, dx: i32, dy: i32, move_timer: i32, body_color: u32, head_color: u32, cloth_color: u32, is_hero: bool, is_male: bool, is_student: bool, attack_t: i32) void {
    const x = px + hero_aabb_local.x;
    const y = py + hero_aabb_local.y;
    const hero_y_off = getHeroOffY(move_timer);
    const is_mask = is_hero and hero_mask;
    const is_knife = is_hero and hero_knife;
    const ss = gain.math.sintau(fp32.toFloat(move_timer >> 1)) / 40.0;

    if (is_knife) {
        var ang = ss;
        if (hero_attack_t > 15) {
            ang = @floatFromInt(hero_attack_t - 15);
            ang /= 15;
        }
        gfx.push(x + hero_w, y + (18 << fbits) - hero_y_off, -ang);
        gfx.knife(@max(0, (hero_attack_t - 8) << fbits));
        gfx.restore();
    }

    if (!is_student and !is_hero) {
        var ang = ss;
        if (attack_t > 15) {
            ang = @floatFromInt(attack_t - 15);
            ang /= 15;
        }
        gfx.push(x + hero_w, y + (18 << fbits) - hero_y_off, -ang);
        gfx.guardWeapon(@max(0, (attack_t - 8) << fbits));
        gfx.restore();
    }
    if (is_mask) {
        const ang = -ss / 2;
        gfx.push(x + (hero_w >> 1), y + (4 << fbits) - (hero_y_off >> 1), ang);
        gfx.hockeyMask(head_color);
        gfx.restore();
    }

    if (!is_hero) {
        if (is_student) {
            if (!is_male) {
                // swimming top
                gfx.colorRGB(cloth_color);
                gfx.push(x + (hero_w >> 1), y + (14 << fbits) - hero_y_off, 0);
                if (dy >= 0) {
                    gfx.romb(-3 << fbits, 0, 2 << fbits);
                    gfx.romb(3 << fbits, 0, 2 << fbits);
                }
                gfx.line(-5 << fbits, 0, 5 << fbits, 0, 1 << fbits, 1 << fbits);
                gfx.restore();
            } else {
                if (dy >= 0) {
                    // draw NIPPLES
                    gfx.push(x + (hero_w >> 1), y + (14 << fbits) - hero_y_off, 0);
                    gfx.colorRGB(Color32.lerp8888b(body_color, 0, 0x20));
                    gfx.romb(-3 << fbits, 0, 1 << fbits);
                    gfx.romb(3 << fbits, 0, 1 << fbits);
                    gfx.restore();
                }
            }
        }
    }

    if (!is_mask) {
        gfx.push(x + (hero_w >> 1), y + (4 << fbits) - (hero_y_off >> 1), -ss);
        gfx.head(dx, dy, head_color);
        gfx.restore();
    }

    if (is_hero and hero_13) {
        gfx.push(x + (hero_w >> 1) + (1 << fbits), y + (16 << fbits) - hero_y_off, 0);
        gfx.colorRGB(colors.red);
        gfx.banner13();
        gfx.restore();
    }

    if (!is_hero and is_student) {
        gfx.colorRGB(cloth_color);
        gfx.push(x + (hero_w >> 1), y + (20 << fbits) - hero_y_off, ss);
        gfx.trouses();
        gfx.restore();
    }

    gfx.colorRGB(body_color);
    gfx.quad_(x, y - hero_y_off + (9 << fbits), hero_w, hero_h - hero_y_off - (2 << fbits) - (9 << fbits));

    gfx.quad_(x - (2 << fbits), y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits);
    gfx.quad_(x + hero_w, y + (10 << fbits) - hero_y_off, 2 << fbits, 8 << fbits);

    gfx.quad_(x, y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits);
    gfx.quad_(x + (6 << fbits), y - (hero_y_off << 1) + (hero_h - (2 << fbits)), 4 << fbits, 2 << fbits);
}

fn drawHero() void {
    if (hero_hp != 0) {
        const head_color = Color32.lerp8888b(0x888888, colors.paper, hero_visible << 3);
        const body_color = Color32.lerp8888b(0x0, colors.hero_body_color, hero_visible << 3);
        gfx.depth(hero.x, hero.y);
        drawTempMan(hero.x, hero.y, hero_look_x, hero_look_y, hero_move_timer, body_color, head_color, 0, true, true, false, hero_attack_t);
    }
}

fn drawManShadow(x: i32, y: i32, move_timer: i32) void {
    //const y_off = getHeroOffY(move_timer);
    // const color = Color32.lerp8888b(colors.shadow, 0x00000000, @bitCast(y_off * 5));
    _ = move_timer;
    gfx.shadow(x, y, 7 << fbits);
}

fn drawPortalHoles() void {
    gain.gfx.state.z = 3 << fbits;
    for (0..portals_num) |i| {
        const portal = portals[i];
        const pos = portal.pos;
        if (camera.rc.contains(pos)) {
            gfx.colorRGB(if (hero_ready) colors.cosmos else colors.wood_dark);
            gfx.circle(pos.x, pos.y, cell_size_half, cell_size_half >> 1, 32);
            gfx.colorRGB(colors.blood_dark);
            gfx.circle(pos.x, pos.y - (1 << fbits), cell_size_half, cell_size_half >> 1, 32);
        }
        const p = portal.dest;
        if (camera.rc.contains(p)) {
            const rc2 = FPRect.init(p.x, p.y, 0, 0).expand(cell_size_half >> 1, cell_size_half >> 2);
            gfx.colorRGB(colors.wood_dark);
            gfx.crossWide(rc2);
        }
    }
}

fn drawItem(i: usize) void {
    const item = items[i];
    const x = item.pos.x;
    const y = item.pos.y;
    gfx.depth(x, y);
    gfx.push(x, y - (8 << fbits), fp32.toFloat(@bitCast(gain.app.tic + (i << 4))) / 10);
    switch (i) {
        // draw mask
        0 => gfx.hockeyMask(colors.paper),
        // draw knife
        1 => gfx.knife(-8 << fbits),
        // 13
        2 => {
            gfx.colorRGB(colors.blood_dark);
            gfx.banner13();
        },
        else => {
            gfx.colorRGB(if (item.kind == 0) colors.blood_light else colors.green_light);
            gfx.rect_(FPRect.fromInt(0, 0, 0, 0).expandInt(2));
            gfx.colorRGB(colors.cosmos);
            gfx.rect_(FPRect.fromInt(0, 0, 0, 0).expandInt(4));
        },
    }
    gfx.restore();
}

fn getMobColor(kind: u8) u32 {
    return colors.mob[kind];
}

fn getMobTrousesColor(kind: u8) u32 {
    return colors.mob_trouses[kind];
}

fn drawMob(i: usize) void {
    const mob = mobs[i];
    var x = mob.x;
    var y = mob.y;

    gfx.depth(x, y);

    if (mob.danger_t > 0) {
        x += g.rnd.int(-1, 1) << fbits;
        y += g.rnd.int(-2, 0) << fbits;
        gfx.push(x + (8 << fbits), y - (32 << fbits), 0);
        gfx.scream();
        gfx.restore();
    }

    if (mob.attention > 0 and !mob.danger) {
        gfx.push(x, y - (32 << fbits), 0);
        gfx.attention();
        gfx.restore();
    }

    if (mob.hp != mob.hp_max) {
        gfx.push(x, y - (32 << fbits), 0);
        gfx.bar(mob.hp, mob.hp_max, colors.blood_light);
        gfx.restore();
    }

    var head_color = getMobColor(mob.kind);
    var body_color = head_color;
    if (!mob.is_student) {
        body_color = colors.guards[mob.kind];
    }
    head_color = Color32.lerp8888b(head_color, 0xFFFFFF, mob.hit_timer << 3);
    body_color = Color32.lerp8888b(body_color, 0xFFFFFF, mob.hit_timer << 3);
    drawTempMan(x, y, mob.lx, mob.ly, mob.move_timer, body_color, head_color, getMobTrousesColor(mob.kind), false, mob.male, mob.is_student, mob.attack_t);
}

fn drawVPad() void {
    if (gain.pointers.primary()) |p| {
        if (p.is_down) {
            const scale = camera.ui_scale;
            const q = FPVec2.init(@intFromFloat(p.pos.x), @intFromFloat(p.pos.y));
            const s = FPVec2.init(@intFromFloat(p.start.x), @intFromFloat(p.start.y));
            const r = fp32.scale(fp32.fromInt(64), scale);
            const r2 = fp32.scale(fp32.fromInt(128 - 8), scale);
            const r3 = fp32.scale(fp32.fromInt(128), scale);
            gain.gfx.state.z = (1 << 15) << fbits;
            gfx.color(0x33333333);
            gfx.circle(s.x, s.y, r3, r3, 64);
            gfx.color(0x33000000);
            gfx.circle(s.x, s.y, r2, r2, 64);
            gfx.color(0x99999999);
            gfx.circle(q.x, q.y, r, r, 64);
        }
    }
}

pub fn render() void {
    gain.gfx.setupOpaquePass();
    gain.gfx.state.matrix = Mat2d.identity();

    if (game_state == 1) {
        drawHUD();
    }

    gain.gfx.state.matrix = camera.matrix;

    if (g.is_debug) {
        drawMiniMap();
    }
    drawHero();

    for (0..items_num) |i| {
        const item = items[i];
        if (item.alive and camera.rc.test2(item.pos.x, item.pos.y)) {
            drawItem(i);
        }
    }

    for (0..mobs_num) |i| {
        const mob = mobs[i];
        if (mob.hp != 0 and camera.rc.test2(mob.x, mob.y)) {
            drawMob(i);
        }
    }

    drawPortalHoles();
    particles.draw();

    if (hero_level_up & 7 < 5) {
        drawMap();
    }
    drawBack();

    gain.gfx.setupBlendPass();

    gain.gfx.state.z = 4 << fbits;

    if (hero_hp != 0) {
        drawManShadow(hero.x, hero.y, hero_move_timer);
        if (g.is_debug) {
            gfx.color(0x77FF00FF);
            gfx.rect_(hero_ground_aabb_local.translate(hero.x, hero.y));

            gfx.color(0x77FF0000);
            gfx.rect_(hero_ground_aabb_local.translate(hero.x, hero.y).expandInt(16));
        }
    }
    particles.drawShadows();

    for (0..mobs_num) |i| {
        const mob = mobs[i];
        if (mob.hp != 0 and mob_quad_local.translate(mob.x, mob.y).overlaps(camera.rc)) {
            drawManShadow(mob.x, mob.y, mob.move_timer);
            if (g.is_debug) {
                gfx.color(0x77FF00FF);
                gfx.rect_(mob_hitbox_local.translate(mob.x, mob.y));
            }
        }
    }

    for (0..items_num) |i| {
        const item = items[i];
        if (item.alive and camera.rc.test2(item.pos.x, item.pos.y)) {
            gfx.shadow(item.pos.x, item.pos.y, 8 << fbits);
        }
    }

    // attack circles
    if (hero_hp != 0 and hero_attack_t > 15) {
        gfx.attackCircle(hero.x, hero.y, hero_attack_t);
    }

    for (0..mobs_num) |i| {
        const mob = mobs[i];
        if (mob.hp != 0 and mob_quad_local.translate(mob.x, mob.y).overlaps(camera.rc)) {
            if (mob.attack_t > 15) {
                gfx.attackCircle(mob.x, mob.y, mob.attack_t);
            }
        }
    }

    gain.gfx.state.matrix = Mat2d.identity();
    drawVPad();
    drawBlackOverlay();
}

fn drawHUD() void {
    gain.gfx.state.z = (1 << 15) << fbits;
    gain.gfx.state.matrix = Mat2d
        .identity()
        .translate(Vec2.fromIntegers(app.w >> 1, 0))
        .scale(Vec2.splat(camera.ui_scale))
        .translate(Vec2.fromIntegers((-(512 << fbits) >> 1), 24 << fbits));

    gfx.pushEx(42 << fbits, (8 + 30) << fbits, 0, 2);
    gfx.hockeyMask(colors.white);
    gfx.restore();

    gfx.pushEx(128 << fbits, (32) << fbits, -0.01, 2);
    gfx.bar(hero_hp, hero_hp_max, colors.blood_light);
    gfx.restore();

    gfx.pushEx(128 << fbits, (48) << fbits, -0.005, 2);
    gfx.bar(hero_xp, hero_xp_max, colors.green_light);
    gfx.restore();

    const space_x: i32 = @divTrunc(512 << fbits, 14);
    var ix: i32 = (512 << fbits) - space_x;
    for (0..13) |i| {
        var rc = FPRect.init(0, 0, 0, 0);

        gfx.pushEx(ix, 0, 0.02, 2);
        if (kills + i >= 13) {
            rc = rc.expandInt(3);
            gfx.colorRGB(colors.blood_dark);
            gfx.crossWide(rc);
        }
        gfx.colorRGB(colors.paper);
        gfx.rect_(rc.expandInt(5));
        gfx.colorRGB(colors.black);
        gfx.rect_(rc.expandInt(7).translate(1 << fbits, 1 << fbits));
        gfx.restore();
        ix -= space_x;
    }
}

fn drawMap() void {
    const _cx = camera.rc.x >> cell_size_bits;
    const _cy = camera.rc.y >> cell_size_bits;
    const _cw = camera.rc.w >> cell_size_bits;
    const _ch = camera.rc.h >> cell_size_bits;
    const ccx0: usize = @intCast(@min(map.size - 1, @max(0, _cx)));
    const ccx1: usize = @intCast(@min(map.size - 1, @max(0, _cx + _cw + 2)));
    const ccy0: usize = @intCast(@min(map.size - 1, @max(0, _cy)));
    const ccy1: usize = @intCast(@min(map.size - 1, @max(0, _cy + _ch + 2)));

    //drawPath();

    for (ccy0..ccy1) |cy| {
        const index = cy << map.size_bits;
        for (ccx0..ccx1) |cx| {
            const cell = map.map[index + cx];
            if (cell != 0) {
                gain.gfx.state.z = 2 << fbits;
                const p = map.coordToPos(@bitCast(cx), @bitCast(cy));
                var color = colors.tile[map.colors[map.addr(cx, cy)]];
                if (map.map[index + cx - map.size] == 0) {
                    gfx.colorRGB(Color32.lerp8888b(color, 0x0, 128));
                    gfx.rect_(FPRect.init(p.x - cell_size_half, p.y - cell_size, cell_size, cell_size_half));
                }
                if (cell > 1) {
                    color = Color32.lerp8888b(color, 0x0, 64);
                }
                gfx.colorRGB(color);
                gfx.rect_(FPRect.init(p.x, p.y, 0, 0).expand(cell_size_half, cell_size_half));

                if (cell > 1) {
                    gfx.depth(p.x, p.y + cell_size_half);
                    if (cell == 2) {
                        gfx.colorRGB(colors.wood_dark);
                        for (0..3) |iy| {
                            const iiy: i32 = @intCast(iy);
                            gfx.quad_(p.x - cell_size_half, p.y + (iiy * cell_size_half >> 1) - (1 << fbits), cell_size, 2 << fbits);
                        }
                        for (0..5) |ix| {
                            const iix: i32 = @intCast(ix);
                            gfx.quad_(p.x - cell_size_half + (iix * cell_size >> 2) - (1 << fbits), p.y, 2 << fbits, cell_size_half);
                        }
                    } else if (cell == 3) {
                        const ss = gain.math.sintau(fp32.toFloat(@bitCast(app.tic +% (cx * cy))) / 8) / 100.0;
                        gfx.depth(p.x, p.y + (cell_size_half >> 1));
                        gfx.push(p.x, p.y + (8 << fbits), ss);
                        gfx.colorRGB(colors.green_dark);
                        gfx.circle(0, -(24 << fbits), 16 << fbits, 16 << fbits, 8);
                        gfx.colorRGB(colors.wood_dark);
                        gfx.quad_(-(2 << fbits), -cell_size_half, 4 << fbits, cell_size_half);
                        gfx.restore();
                    } else if (cell == 4) {
                        gfx.push(p.x, p.y + (8 << fbits), 0);
                        gfx.colorRGB(colors.green_dark);
                        gfx.circle(0, -4 << fbits, 10 << fbits, 12 << fbits, 8);
                        gfx.circle(-8 << fbits, 0, 8 << fbits, 8 << fbits, 8);
                        gfx.circle(8 << fbits, 0, 8 << fbits, 8 << fbits, 8);
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
}

fn drawMiniMap() void {
    //gain.gfx.state.matrix = Mat2d.identity();
    gain.gfx.state.z = (1 << 15) << fbits;

    for (0..map.size) |cy| {
        const index = cy << map.size_bits;
        for (0..map.size) |cx| {
            const cell = map.map[index + cx];
            const rc = FPRect.fromInt(@bitCast(cx), @bitCast(cy), 1, 1).translate(hero.x, hero.y);
            var color: u32 = 0xFF000000;
            if (cell != 0) {
                color = colors.tile[map.colors[map.addr(cx, cy)]];
                if (cell > 1) {
                    color = Color32.lerp8888b(color, 0xFF000000, 16);
                }
                gfx.colorRGB(color);
                gfx.rect_(rc);
            }
        }
    }

    for (0..zones_num) |i| {
        gfx.colorRGB(0x113322);
        const rc = zones[i];
        gfx.rect_(FPRect.fromInt(rc.x, rc.y, rc.w, rc.h).translate(hero.x, hero.y));
    }
}

// fn drawPath() void {
//     const rc = FPRect.init(cell_size_half, cell_size_half, 0, 0).expandInt(4);
//     for (0..map.path_num) |i| {
//         gfx.rect(rc.translate(map.path_x[i] << cell_size_bits, map.path_y[i] << cell_size_bits), if (map.path_num > 0) 0xFFFFFFFF else 0xFFFFFF00);
//     }
//     gfx.rect(rc.translate(map.path_dest_x << cell_size_bits, map.path_dest_y << cell_size_bits), 0xFFFF0000);
// }

fn drawBack() void {
    gain.gfx.state.z = 0;

    if (true) {
        const tile_size = 64 << fbits;
        var cy = camera.rc.y;
        gfx.colorRGB(colors.star);
        while (cy < camera.rc.b() + tile_size) {
            var cx = camera.rc.x;
            while (cx < camera.rc.r() + tile_size) {
                const x = (cx >> (6 + fbits)) << (6 + fbits);
                const y = (cy >> (6 + fbits)) << (6 + fbits);
                const local_seed = x +% (y << 8);
                var rnd = gain.math.Rnd{ .seed = @bitCast(local_seed) };
                var n = rnd.next() & 3;
                while (n != 0) {
                    const dx = rnd.int(-32 << fbits, 32 << fbits);
                    const dy = rnd.int(-32 << fbits, 32 << fbits);
                    const t = fp32.toFloat(dx - dy + @as(i32, @bitCast(app.tic))) / 2;
                    const fy = @abs(gain.math.sintau(t / 8));
                    const size = fp32.scale(1 << fbits, fy);
                    gfx.romb(x + dx, y + dy, size);
                    n -= 1;
                }
                cx += 64 << fbits;
            }
            cy += 64 << fbits;
        }
    }

    gfx.colorRGB(colors.cosmos);
    gfx.rect_(camera.rc.expandInt(128 << fbits));
}

// MENU
var game_state: u8 = 0;
var game_state_init: bool = false;
var no_black_screen_t: u8 = 0;
var no_black_screen_target: u8 = 0;
var game_state_tics: i32 = 0;

fn setGameState(state: u8) void {
    game_state_tics = 0;
    no_black_screen_target = if (state == 1) 15 else 7;
    no_black_screen_t = 0;
    game_state = state;
    unsetText(0);
    camera.shakeM();
}

fn updateGameState() void {
    game_state_tics += 1;
    sfx.music_menu = game_state != 1 or hero_visible < hero_visible_thr;
    switch (game_state) {
        0 => {
            setText(100, "FRI3", FPVec2.init(hero.x, hero.y - (128 << fbits)), colors.blood_light, 10);
            setText(101, "TAP TO START", FPVec2.init(hero.x, hero.y + (64 << fbits)), colors.paper, 4);
            setText(102, "js13k game by\n\nIlya Kuzmichev\n&\nAlexandra Alhovik", FPVec2.init(hero.x, hero.y + (128 << fbits)), colors.paper, 2);

            if (game_state_tics == 1) {
                no_black_screen_target = 4;
                hero_hp = 1;
                hero_mask = true;
                hero_knife = true;
                hero_13 = true;
                map.current_color = 2;
                //camera.zoom = 1;
                for (4..16) |cy| {
                    for (4..16) |cx| {
                        setMapPlus(@bitCast(cx), @bitCast(cy), @intCast(g.rnd.int(1, 8)));
                        if (g.rnd.next() & 0x7 == 0) {
                            placeMob(@bitCast(cx), @bitCast(cy), g.rnd.next() % 3, g.rnd.next() & 1 == 0, true);
                        }
                    }
                }
                hero.x = (10 << cell_size_bits);
                hero.y = (10 << cell_size_bits);
            }
            if (gain.pointers.primary()) |p| {
                if (p.down) {
                    setGameState(1);
                    initLevel();
                }
            }
        },
        1 => {
            if (game_state_tics == 1) {
                camera.zoom = 0.5;
            }
            if (hero_hp == 0) {
                no_black_screen_target = 4;
                setText(100, "PARTY FAILED", FPVec2.init(hero.x, hero.y - (96 << fbits)), colors.blood_light, 10);
                setText(101, "no one is afraid of 13...", FPVec2.init(hero.x, hero.y + (48 << fbits)), colors.paper, 4);
                // if (camera.zoom > 0.5) {
                //     camera.zoom -= 0.001;
                // }
                if (game_state_tics > 128) {
                    setText(102, "tap to restart", FPVec2.init(hero.x, hero.y + (96 << fbits)), colors.paper, 3);
                    if (gain.pointers.primary()) |p| {
                        if (p.down) {
                            setGameState(1);
                            initLevel();
                        }
                    }
                }
            } else {
                if (camera.zoom < 1) {
                    camera.zoom += 0.01;
                }
            }
        },
        2 => {
            setText(100, "YEAR COMPLETED", FPVec2.init(hero.x, hero.y - (96 << fbits)), colors.blood_light, 10);
            setText(101, "why are you scared of 13?", FPVec2.init(hero.x, hero.y + (48 << fbits)), colors.blood_light, 4);
            if (game_state_tics > 128) {
                setText(102, "tap to start\nthe next year", FPVec2.init(hero.x, hero.y + (96 << fbits)), colors.star, 3);
                if (gain.pointers.primary()) |p| {
                    if (p.down) {
                        level += 1;
                        setGameState(1);
                        initLevel();
                    }
                }
            }
        },
        else => unreachable,
    }

    if (no_black_screen_t < no_black_screen_target) {
        no_black_screen_t += 1;
    } else if (no_black_screen_t > no_black_screen_target) {
        no_black_screen_t -= 1;
    }
}

fn drawBlackOverlay() void {
    if (no_black_screen_t < 15) {
        gain.gfx.state.z = (1 << 15) << fbits;
        gfx.color(Color32.lerp8888b(
            0xFF << 24,
            0x00000000,
            no_black_screen_t << 4,
        ));
        gfx.quad_(0, 0, @bitCast(app.w), @bitCast(app.h));
    }
}
