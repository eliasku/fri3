const fp32 = @import("fp32.zig");
const gain = @import("../gain/main.zig");
const std = @import("std");
const map = @import("map.zig");
const FPRect = @import("FPRect.zig");
const gfx = @import("gfx.zig");
const Color32 = gain.math.Color32;
const colors = @import("colors.zig");
const camera = @import("camera.zig");
const g = @import("g.zig");

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
    spr: u32,
    a: i32,
    r: i32,
    rc: FPRect,
};

const particles_max = 4096;
var particles: [particles_max]Particle = undefined;
var particles_num: u32 = 0;

pub fn update() void {
    for (0..particles_num) |i| {
        const p = &particles[i];
        if (p.t != 0) {
            p.*.t -= 1;
            if (p.spr != 0 and p.t & 1 == 0) {
                add(1, p.x, p.y, p.z);
            }
            const f = fp32.div(p.t, p.max_time);
            p.a += fp32.mul(p.r, f);
            const x2 = p.x + fp32.mul(p.vx, f);
            const y2 = p.y + fp32.mul(p.vy, f);
            if (map.testPoint(x2, p.y)) {
                p.vx = -p.vx;
            } else {
                p.x = x2;
            }
            if (map.testPoint(p.x, y2)) {
                p.vy = -p.vy;
            } else {
                p.y = y2;
            }
        }

        if (p.z > 0) {
            p.z = @max(0, p.z + p.vz);
            p.vz -= 3;
        }
    }
}

pub fn draw() void {
    for (0..particles_num) |i| {
        const p = particles[i];
        const y = p.y - p.z;
        if (camera.rc.test2(p.x, y)) {
            //if (camera_rc.x < p.x and camera_rc.y < p.y and p.x < camera_rc.r() and p.y < camera_rc.b()) {
            gfx.depth(0, if (p.t > 0 or p.spr != 0) p.y else (3 << fp32.fbits));
            gfx.push(p.x, y, fp32.toFloat(p.a) / 4);
            switch (p.spr) {
                1 => {
                    gfx.deadHead(p.color);
                },
                2 => {
                    gfx.hockeyMask(p.color);
                },
                3 => {
                    gfx.knife(0, 2);
                },
                else => {
                    gfx.colorRGB(p.color);
                    gfx.rect_(p.rc);
                },
            }
            gfx.restore();
        }
    }
}

pub fn drawShadows() void {
    const rc = camera.rc;
    for (0..particles_num) |i| {
        const p = particles[i];
        if (p.t > 0 and rc.test2(p.x, p.y)) {
            gfx.shadow(p.x, p.y, p.rc.w >> 1);
        }
    }
}

pub fn addPart(x: i32, y: i32, color: u32, spr: u32, rc: FPRect) void {
    if (particles_num < particles_max) {
        const d = 10 * g.rnd.float();
        const a = g.rnd.float();
        const t = g.rnd.int(20, 40);
        particles[particles_num] = .{
            .x = x,
            .y = y,
            .z = 16 << fp32.fbits,
            .vx = fp32.fromFloat(d * gain.math.costau(a)),
            .vy = fp32.fromFloat(d * gain.math.sintau(a) / 2),
            .vz = 1 << fp32.fbits,
            .color = color,
            .max_time = t,
            .t = t,
            //.size = if (spr == 1) (10 << fp32.fbits) else (4 << fp32.fbits),
            .spr = spr,
            .a = 0,
            .r = g.rnd.int(-1 << fp32.fbits, 1 << fp32.fbits),
            .rc = rc,
        };
        particles_num += 1;
    }
}

pub fn add(n: i32, x: i32, y: i32, z: i32) void {
    const N: usize = @intCast(n);
    for (0..N) |_| {
        if (particles_num < particles_max) {
            const d = 8 * g.rnd.float();
            const a = g.rnd.float();
            const t = g.rnd.int(10, 20);
            const sz = g.rnd.int(1 << fp32.fbits >> 1, 3 << fp32.fbits);
            particles[particles_num] = .{
                .x = x,
                .y = y,
                .z = z,
                .vx = fp32.fromFloat(d * gain.math.costau(a)),
                .vy = fp32.fromFloat(d * gain.math.sintau(a) / 2),
                .vz = g.rnd.int(0, 1 << fp32.fbits),
                .color = Color32.lerp8888b(
                    colors.blood_dark,
                    colors.blood_light,
                    g.rnd.next() >> 24,
                ),
                .max_time = t,
                .spr = 0,
                .t = t,
                .a = 0,
                .r = 0,
                .rc = FPRect.init(0, 0, 0, 0).expand(sz, sz >> 1),
            };
            particles_num += 1;
        }
    }
}

pub fn reset() void {
    particles_num = 0;
}
