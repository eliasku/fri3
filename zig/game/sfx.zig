const gain = @import("../gain/main.zig");

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

pub fn portal() void {
    playZzfx(.{ 1, 0.05, 177, 0, 0.09, 0.07, 2, 1.4, 0, 0, 0, 0, 0.09, 0, 38, 50, 0.28, 0.58, 0.1, 0 });
}

pub fn step(visible: u32) void {
    const vol: f32 = @as(f32, @floatFromInt(visible)) / 31.0;
    playZzfxEx(.{ 1, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 }, vol, 0, 0, 0);
}

pub fn collect() void {
    playZzfx(.{ 1, 0.05, 1578, 0, 0.03, 0.15, 1, 0.87, 0, 0, 141, 0.01, 0, 0.1, 0, 0, 0, 0.52, 0.01, 0.04 });
}

pub fn hit() void {
    playZzfx(.{ 1, 0.05, 337, 0.01, 0.02, 0.1, 0, 2.17, -6.3, 3.5, 0, 0, 0, 1.2, 0, 10, 0.01, 0.69, 0.07, 0.03 });
}

pub fn fear() void {
    playZzfx(.{ 1, 0.05, 600, 0.01, 0.1, 0.2, 0, 1, 1, 0, 0, 0, 0.1, 0, 0, 0, 0, 1, 0, 0 });
}

pub fn update() void {
    updateMusic();
}

// MUSIC

var music_end_time: f32 = 0;
var music_bar: u32 = 0;

fn updateMusic() void {
    const time: f32 = @as(f32, @floatFromInt(gain.app.tic << 4)) / 1000;
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
