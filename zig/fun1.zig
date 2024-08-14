const std = @import("std");
const builtin = @import("builtin");
const gain = @import("gain/main.zig");
const gfx = gain.gfx;
const app = gain.app;
const Color32 = gain.math.Color32;
const Mat2d = gain.math.Mat2d;
const Vec2 = gain.math.Vec2;
const Vec4 = gain.math.Vec4;
const fract = gain.math.fract;
const Rnd = gain.math.Rnd;
const pi = std.math.pi;
const W = 512.0;

const zzfx = gain.zzfx;
const sfx = [_]zzfx.ZzfxParameters{
    .{
        .volume = 1.09,
        .frequency = 1474,
        .attack = 0.02,
        .sustain = 0.03,
        .release = 0.14,
        .shape = 1,
        .shapeCurve = 1.87,
        .slide = 0.3,
        .noise = 0.1,
        .sustainVolume = 0.75,
    },
    zzfx.ZzfxParameters.fromSlice(.{
        1.24, 0.05, 110, 0.02, 0.01, 0.01, 2, 1.1, 0, 0, -40, 0.09, 0, 0, 0, 0, 0, 0.21, 0.01, 0,
    }),
    zzfx.ZzfxParameters.fromSlice(.{
        1, 0.05, 81, 0.03, 0.04, 0.1, 0, 1.82, 2.5, 0.5, 0, 0, 0, 0, 0, 0, 0, 0.72, 0.07, 0,
    }),
    zzfx.ZzfxParameters.fromSlice(.{
        2.77, 0.05, 91, 0, 0.01, 0.08, 4, 1.7, 0, 0, 0, 0, 0, 0.3, 0, 10, 0.18, 0.72, 0, 0.24,
    }),
    zzfx.ZzfxParameters.fromSlice(.{
        1.9, 0.05, 307, 0, 0.12, 0.26, 0, 0.38, 0, 0, 187, 0.03, 0.12, 0, 0, 0, 0.14, 0.56, 0.14, 0,
    }),
    zzfx.ZzfxParameters.fromSlice(.{
        1.03, 0.35, 382, 0.01, 0.04, 0.07, 3, 0.76, -7.5, 4.9, 0, 0, 0, 1.3, 0, 0, 0, 0.85, 0.01, 0,
        //1, 0, 382, 0.01, 0.04, 0.07, 3, 0.76, -7.5, 4.9, 0, 0, 0, 1.3, 0, 0, 0, 0.85, 0.01, 0,
    }),
};

pub fn update() void {
    if (app.tic % 20 == 0) {
        var audio_buffer: [8 * 4096]f32 = undefined;
        const index = (app.tic % 120) / 20;
        const index2 = 1;
        _ = index2;
        const len = zzfx.buildSamples(sfx[index], &audio_buffer);
        if (gain.js.enabled) {
            gain.js.playUserAudioBuffer(&audio_buffer, len);
        }
    }
}

fn effect_ring(r: f32, p: Vec2, r2: f32, color: Color32) void {
    _ = r;
    _ = p;
    _ = r2;
    _ = color;
}
var gRnd = Rnd{ .seed = 0 };

pub fn render() void {
    // gfx.setupOpaquePass();
    // gfx.setTexture(0);
    // @setFloatMode(.optimized);
    const appSize = app.size();
    var scale: f32 = @min(appSize.x, appSize.y);
    scale /= W;
    var view = Mat2d.identity();
    view = view.translate(appSize.scale(0.5));
    view = view.scale(Vec2.splat(scale));
    view = view.translate(Vec2.splat(-0.5 * W));
    // gfx.state.z = 100;
    // gfx.state.matrix = view;
    // gfx.state.color = 0xFFFFFFFF;
    const t: f32 = @as(f32, @floatFromInt(app.tic)) * 0.08;

    // // render_game();

    // {
    //     var rnd = Rnd{ .seed = 0 };

    //     for (0..20) |i| {
    //         const p = (Vec2{
    //             .x = 0.1 + 0.8 * rnd.float(),
    //             .y = 0.1 + 0.8 * rnd.float(),
    //         }).scale(W);
    //         const c = 0.2 * rnd.float();
    //         const color = Color32.fromFloats(c, c, c, 1);
    //         const fi: f32 = @floatFromInt(i);

    //         effect_ring(fract(t * 1.5 + fi * 0.05), p, 10 + 40 * rnd.float(), color);
    //     }
    // }

    gfx.state.matrix = view;
    // gfx.state.z = 5;

    var rnd0 = Rnd{ .seed = 0 };
    const angle = 0.1 * t;

    gfx.state.z = 50;
    gfx.setupBlendPass();
    gfx.setTexture(0);
    for (0..25) |i| {
        const cx = i % 5;
        const cy = i / 5;
        gfx.state.matrix = view;
        // const vec2_t pos = vec2(
        //  (0.0f + 0.99f * rnd_f(&seed)) * W,
        //  (0.0f + 0.99f * rnd_f(&seed)) * W);
        const pos = Vec2.init(
            @floatFromInt(cx),
            @floatFromInt(cy),
        ).add(Vec2.half()).scale(W / 5.0);
        gfx.state.matrix = gfx.state.matrix.translate(pos);
        gfx.state.matrix = gfx.state.matrix.rotate(pi * 2 * (2 * rnd0.float() + (0.5 + 0.5 * rnd0.float()) * angle));

        const sz = Vec2.init(1 + 10 * rnd0.float(), 40 + 40 * rnd0.float());
        // const color_t color = color_f(1, 0.5f + 0.5f * rnd_f(&seed), 0.5f + 0.5f * rnd_f(&seed), 1);

        gfx.quad(
            sz.scale(-0.5),
            sz,
            Color32.fromFloats(1, 1, 0.5 + 0.5 * rnd0.float(), if ((app.tic >> 6) & 1 == 0) 0.0 else 1.0).argb(),
        );
    }
}
