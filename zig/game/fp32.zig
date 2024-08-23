pub const fbits = 8;
pub const fp32 = i32;

pub fn fromInt(integer_value: i32) fp32 {
    return integer_value << fbits;
}

pub fn getInt(v: fp32) i32 {
    return v >> fbits;
}

pub fn scale(v: fp32, f: f32) fp32 {
    const sc: i32 = @intFromFloat(f * (1 << fbits));
    return (sc * v) >> fbits;
}
