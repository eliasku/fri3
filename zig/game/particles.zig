const fp32 = @import("fp32.zig");
const gain = @import("../gain/main.zig");
const std = @import("std");
const map = @import("map.zig");
const FPRect = @import("FPRect.zig");
const gfx = @import("gfx.zig");
const Color32 = gain.math.Color32;

var g_rnd: gain.math.Rnd = .{ .seed = 0 };

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

const particles_max = 2048;
var particles: [particles_max]Particle = undefined;
var particles_num: u32 = 0;

pub fn update() void {
    for (0..particles_num) |i| {
        const p = &particles[i];
        if (p.t > 0) {
            p.*.t -= 1;
            //p.*.p = p.p.add(p.v);
            const f = fp32.div(p.t, p.max_time);
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
            p.vz -= 2;
            //p.vz = -fp32.mul(p.vz, fp32.fromFloat(0.5));
        }
    }
}

pub fn draw(camera_rc: FPRect) void {
    for (0..particles_num) |i| {
        const p = particles[i];
        const y = p.y - p.z;
        if (camera_rc.test2(p.x, y)) {
            //if (camera_rc.x < p.x and camera_rc.y < p.y and p.x < camera_rc.r() and p.y < camera_rc.b()) {
            gfx.depth(p.x, p.y);
            gfx.rect(FPRect.init(p.x, y, 0, 0).expand(p.size, p.size >> 1), p.color);
        }
    }
}

pub fn drawShadows(camera_rc: FPRect) void {
    for (0..particles_num) |i| {
        const p = particles[i];
        if (camera_rc.test2(p.x, p.y)) {
            gfx.shadow(p.x, p.y, p.size, 0x77000000);
            //gfx.rect(FPRect.init(p.x, p.y, 0, 0).expand(p.size, p.size >> 1), 0x77000000);
        }
    }
}

pub fn add(n: i32, x: i32, y: i32) void {
    const N: usize = @intCast(n);
    for (0..N) |_| {
        if (particles_num < particles_max) {
            const d = 5 * g_rnd.float();
            const a = g_rnd.float();
            const t = g_rnd.int(10, 20);
            particles[particles_num] = .{
                .x = x,
                .y = y,
                .z = g_rnd.int(0, 20 << fp32.fbits),
                .vx = fp32.fromFloat(d * gain.math.costau(a)),
                .vy = fp32.fromFloat(d * gain.math.sintau(a) / 2),
                .vz = 0,
                .color = Color32.lerp8888b(
                    0xFFCC0000,
                    0xFF990000,
                    g_rnd.next() & 0xFF,
                ),
                .max_time = t,
                .t = t,
                .size = g_rnd.int(1, 4) << fp32.fbits,
            };
            particles_num += 1;
        }
    }
}

pub fn reset() void {
    particles_num = 0;
}
