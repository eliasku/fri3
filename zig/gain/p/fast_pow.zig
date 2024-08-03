pub fn pow(a: f32, b: f32) f32 {
    const k = 1065307417;
    var i: i32 = @bitCast(a);
    i = @as(i32, @intFromFloat(b * @as(f32, @floatFromInt(i - k)))) + k;
    return @bitCast(i);
}
