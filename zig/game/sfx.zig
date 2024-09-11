const gain = @import("../gain/main.zig");
const g = @import("g.zig");

var audio_buffer: [8 * 4096]f32 = undefined;

fn playZzfxFromParams(params: gain.zzfx.ZzfxParameters, vol: f32, pan: f32, detune: f32, when: f32) void {
    const len = gain.zzfx.buildSamples(params, &audio_buffer);
    if (gain.js.enabled) {
        gain.js.playUserAudioBuffer(&audio_buffer, len, vol, pan, detune, when);
    }
}

fn playZzfxEx(comptime params: anytype, vol: f32, pan: f32, detune: f32, when: f32) void {
    playZzfxFromParams(gain.zzfx.ZzfxParameters.fromSlice(params), vol, pan, detune, when);
}

fn playZzfx(comptime params: anytype) void {
    playZzfxEx(params, 1, 0, 0, 0);
}

pub fn portal() void {
    playZzfx(.{ 1, 0.05, 177, 0, 0.09, 0.07, 2, 1.4, 0, 0, 0, 0, 0.09, 0, 38, 50, 0.28, 0.58, 0.1, 0 });
}

pub fn step(visible: u32) void {
    const vol: f32 = @as(f32, @floatFromInt(visible)) / 31.0;
    // var params = gain.zzfx.ZzfxParameters.fromSlice(.{ 0, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 });
    // params.volume = vol;
    // playZzfx(params);
    playZzfxEx(.{ 0, 0.1, 553, 0.02, 0.01, 0, 0, 1.17, -85, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0 }, vol, 0, 0, 0);
}

pub fn collect() void {
    playZzfx(.{ 0.5, 0.05, 1578, 0, 0.03, 0.15, 1, 0.87, 0, 0, 141, 0.01, 0, 0.1, 0, 0, 0, 0.52, 0.01, 0.04 });
}

pub fn hit() void {
    playZzfx(.{ 1, 0.05, 337, 0.01, 0.02, 0.1, 0, 2.17, -6.3, 3.5, 0, 0, 0, 1.2, 0, 10, 0.01, 0.69, 0.07, 0.03 });
}

pub fn fear() void {
    playZzfx(.{ 1, 0.05, 600, 0.01, 0.1, 0.2, 0, 1, 1, 0, 0, 0, 0.1, 0, 0, 0, 0, 1, 0, 0 });
}

pub fn attack() void {
    playZzfx(.{ 1, 0.05, 300, 0.01, 0.1, 0.05, 0, 1, 0, 0, 0, 0, 0.1, 1, 0, 0, 0.1, 0, 0.05, 0 });
}

pub fn levelUp() void {
    playZzfx(.{ 0.5, 0, 100, 0.1, 0.5, 0.5, 1, 0.5, 4, 0, -400, 0.05, 0.05, 0, 0, 10, 0.05, 1, 0.2, 0 });
}

pub fn update() void {
    updateMusic();
}

// MUSIC

var music_end_time: f32 = 0;
var music_bar: u32 = 0;
const gen_music_bars = 1;
pub var music_menu = false;
fn updateMusic() void {
    const time: f32 = @as(f32, @floatFromInt(gain.app.tic)) * (1.0 / 60.0);
    const temp: f32 = if (music_menu) 40 else 80;
    const k: f32 = (60.0 / temp) / 4.0;
    if (time >= music_end_time - k) {
        generateNextMusicBar(music_end_time, k, time);
        music_end_time += gen_music_bars * k;
        music_bar += 1;
    }
}

fn badNote(v: f32, note: f32, t: f32) void {
    playZzfxEx(.{ 1, 0, 440, 0.01, 0.1, 0.2, 0, 1, 1, 0, 0, 0, 0.1, 0, 0, 0, 0, 1, 0, 0 }, v, 0, note * 100, t);
}

var base_note: f32 = 0;

fn generateNextMusicBar(time: f32, k: f32, cur_time: f32) void {
    var t = time;
    if (t >= cur_time) {
        const j = music_bar % 16;
        const i = j & 0x3;
        if (j == 0) {
            base_note = @floatFromInt(g.rnd.next() % 12);
        }
        if (i == 0 or i == 3) {
            playZzfxEx(.{ 1, 0, 100, 2e-3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5e-3, 0 }, 1, 0, 0, t);
        }

        if (!music_menu) {
            const v: f32 = if (i > 1) 0.2 else 0.1;
            playZzfxEx(.{ 1, 0, 1e3, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0.1, 0 }, v, 0, 0, t);
        }

        const note_volume: f32 = if (music_menu) 0.05 else 0.1;
        //const note: f32 = @floatFromInt(j);
        if (music_menu or g.rnd.next() & 1 == 0) {
            if (j != 7) {
                badNote(note_volume, base_note, t);
                badNote(note_volume / 2, base_note + 5, t + 2 * k / 4);
            } else {
                badNote(note_volume, base_note + 3, t);
                badNote(note_volume / 2, base_note + 10, t + 2 * k / 4);
            }
        }

        t += k;
    }
}
