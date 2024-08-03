const std = @import("std");

const js = @import("../js.zig");
pub const sin = js.sin;
pub const cos = js.cos;
pub const pow = js.pow;
pub const atan2 = js.atan2;

pub fn sintau(x: f32) f32 {
    return sin(x * std.math.tau);
}

pub fn costau(x: f32) f32 {
    return cos(x * std.math.tau);
}

pub fn tantau(x: f32) f32 {
    return sintau(x) / costau(x);
}

pub fn fract(v: f32) f32 {
    @setFloatMode(.optimized);
    return v - @floor(v);
}

test "fract" {
    try std.testing.expectApproxEqRel(
        @as(f32, 0.23),
        fract(33.23),
        1e-4,
    );

    // CHECK this is for linear behaviour
    try std.testing.expectApproxEqRel(
        @as(f32, 0.77),
        fract(-33.23),
        1e-4,
    );
}

pub fn getCircleSegments(r: f32) u32 {
    @setRuntimeSafety(false);
    const quality = 2;
    return @intFromFloat(@ceil(quality * pow(r, 2.0 / 3.0)));
}
