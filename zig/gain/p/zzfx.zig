// play(params...) {
//      buildSamples()
//      playSamples()
// }
// playSamples(..samples) {
//
// }

const _volume = 0.3;
const _sampleRate = 44100;

const std = @import("std");
const Rnd = @import("../math/Rnd.zig");
const mathf = @import("../math/functions.zig");
const copysign = @import("../wasm.zig").copysign;
const g = @import("../../game/g.zig");

// -1 .. +1
fn randomNorm() f32 {
    return 2 * g.rnd.float() - 1;
}

fn clamp(x: f32) f32 {
    return @max(@min(x, 1), -1);
}

fn fract(x: f32) f32 {
    return x - @floor(x);
}

fn pow3(x: f32) f32 {
    return x * x * x;
}

fn pow2(x: f32) f32 {
    return x * x;
}

//var pi: f32 = std.math.pi;
const tau = std.math.tau;

pub const ZzfxParameters = struct {
    volume: f32 = 1.0,
    randomness: f32 = 0.05,
    frequency: f32 = 220.0,
    attack: f32 = 0.0,
    sustain: f32 = 0.0,
    release: f32 = 0.1,
    shape: u32 = 0,
    shapeCurve: f32 = 1.0,
    slide: f32 = 0.0,
    deltaSlide: f32 = 0.0,
    pitchJump: f32 = 0.0,
    pitchJumpTime: f32 = 0.0,
    repeatTime: f32 = 0.0,
    noise: f32 = 0.0,
    modulation: f32 = 0,
    bitCrush: u32 = 0,
    delay: f32 = 0,
    sustainVolume: f32 = 1,
    decay: f32 = 0,
    tremolo: f32 = 0,

    pub fn fromSlice(comptime slice: anytype) ZzfxParameters {
        return .{
            .volume = slice[0],
            .randomness = slice[1],
            .frequency = slice[2],
            .attack = slice[3],
            .sustain = slice[4],
            .release = slice[5],
            .shape = slice[6],
            .shapeCurve = slice[7],
            .slide = slice[8],
            .deltaSlide = slice[9],
            .pitchJump = slice[10],
            .pitchJumpTime = slice[11],
            .repeatTime = slice[12],
            .noise = slice[13],
            .modulation = slice[14],
            .bitCrush = slice[15],
            .delay = slice[16],
            .sustainVolume = slice[17],
            .decay = slice[18],
            .tremolo = slice[19],
        };
    }
};

fn waveformTriangle(time: f32) f32 {
    return 2.0 * @abs(2.0 * (fract(time) - 0.5)) - 1.0;
}

fn waveformSaw(time: f32) f32 {
    return 2.0 * (0.5 - fract(time));
}

pub fn buildSamples(p: ZzfxParameters, b: []f32) u32 {
    @setFloatMode(.optimized);

    std.debug.assert(b.len > 0);

    const sampleRate = _sampleRate;
    var slide = p.slide * 500.0 * tau / sampleRate / sampleRate;
    const startSlide = slide;
    var frequency = p.frequency * (1 + p.randomness * randomNorm()) * tau / sampleRate;
    var startFrequency = frequency;

    // scale by sample rate
    const attack = p.attack * sampleRate + 9.0; // minimum attack to prevent pop
    const decay = p.decay * sampleRate;
    const sustain = p.sustain * sampleRate;
    const release = p.release * sampleRate;
    const delay = p.delay * sampleRate;
    const deltaSlide = p.deltaSlide * 500.0 * tau / pow3(sampleRate);
    const modulation = p.modulation / sampleRate;
    const pitchJump = p.pitchJump * tau / sampleRate;
    const pitchJumpTime: u32 = @intFromFloat(p.pitchJumpTime * sampleRate);
    const repeatTime: u32 = @intFromFloat(p.repeatTime * sampleRate);

    var t: f32 = 0;
    var tm: f32 = 0;
    var j: u32 = 1;
    var r: u32 = 0;
    var c: u32 = 0;
    var s: f32 = 0;
    var f: f32 = undefined;
    var i: f32 = 0.0;
    const length: f32 = @min(attack + decay + sustain + release + delay, @as(f32, @floatFromInt(b.len - 1)));
    while (i < length) : (i += 1.0) {
        // bit crush
        c +%= 1;
        if (p.bitCrush == 0 or c % p.bitCrush == 0) {
            const x = t / tau;
            s = switch (p.shape) {
                // sin
                0 => mathf.sintau(x),
                // triangle
                1 => waveformTriangle(x),
                // saw
                2 => waveformSaw(x),
                // tan
                3 => clamp(mathf.tantau(x)),
                // noise
                4 => mathf.sintau(pow2(tau) * pow3(fract(x))),
                else => unreachable,
            };

            s = copysign(mathf.pow(@abs(s), p.shapeCurve), s) * // curve 0=square, 2=pointy
                p.volume * _volume;
            if (repeatTime != 0) {
                s *= 1 - p.tremolo + p.tremolo * mathf.sintau(i / @as(f32, @floatFromInt(repeatTime))); // tremolo
            }
            s *= // envelope
                if (i < attack) i / attack else // attack
            if (i < attack + decay) // decay
                1 - ((i - attack) / decay) * (1 - p.sustainVolume)
            else // decay falloff
            if (i < attack + decay + sustain) // sustain
                p.sustainVolume
            else // sustain volume
            if (i < length - delay) // release
                (length - i - delay) / release * // release falloff
                    p.sustainVolume
            else // release volume
                0; // post release

            if (delay != 0) {
                s = s / 2.0 +
                    (if (delay > i) 0.0 else // delay
                (if (i < length - delay) 1.0 else (length - i) / delay) * // release delay
                    b[@intFromFloat(i - delay)] / 2.0);
            } // sample delay
        }

        slide += deltaSlide;
        frequency += slide;
        f = frequency * mathf.costau(modulation * tm);
        tm += 1;
        // noise
        t += f * (1 + p.noise * randomNorm());
        // pitch jump
        if (j != 0) {
            j +%= 1;
            if (j > pitchJumpTime) {
                frequency += pitchJump; // apply pitch jump
                startFrequency += pitchJump; // also apply to start
                j = 0; // stop pitch jump time
            }
        }
        // repeat
        if (repeatTime != 0) {
            r +%= 1;
            if (r % repeatTime == 0) {
                frequency = startFrequency; // reset frequency
                slide = startSlide; // reset slide
                if (j == 0) {
                    // reset pitch jump time
                    j = 1;
                }
            }
        }

        b[@intFromFloat(i)] = s;
    }
    return @intFromFloat(length);
}

// get frequency of a musical note on a diatonic scale
fn getNote(params: struct { semitoneOffset: f32 = 0.0, rootNoteFrequency: f32 = 440.0 }) f32 {
    // return params.rootNoteFrequency * (@exp2(params.semitoneOffset / 12.0));
    return params.rootNoteFrequency * (mathf.pow(2, params.semitoneOffset / 12.0));
}
