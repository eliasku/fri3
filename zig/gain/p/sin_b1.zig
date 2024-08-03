const wasm = @import("../wasm.zig");
const std = @import("std");

pub fn sintau(x: f32) f32 {
    const k = 40500.0 / (360.0 * 360.0);
    var y = x - @floor(x);
    const sign = 0.5 - y;
    y = @min(y, 1.0 - y);
    y *= 0.5 - y;
    y *= 4.0 / (k - y);
    return wasm.copysign(y, sign);
}

pub fn costau(x: f32) f32 {
    return sintau(x + 0.25);
}

pub fn tantau(x: f32) f32 {
    return sintau(x) / sintau(x + 0.25);
}

const tau = std.math.tau;

pub fn sin(x: f32) f32 {
    return sintau(x / tau);
}

pub fn cos(x: f32) f32 {
    return costau(x / tau);
}

pub fn tan(x: f32) f32 {
    return tantau(x / tau);
}

test "sin cos b.I" {
    const expect = std.testing.expect;
    try expect(sintau(0) == 0);
    try expect(costau(0) == 1);
    try expect(sintau(0.5) == 0);
    try expect(costau(0.5) == -1);
    try expect(sin(0) == 0);
    try expect(cos(0) == 1);
    try expect(tantau(-0.25) == -std.math.inf(f32));
}
