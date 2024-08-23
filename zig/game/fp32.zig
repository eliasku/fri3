pub const fbits = 8;
pub const fp32 = i32;

pub fn fromInt(integer_value: i32) fp32 {
    return integer_value << fbits;
}

pub fn getInt(v: fp32) i32 {
    return v >> fbits;
}
