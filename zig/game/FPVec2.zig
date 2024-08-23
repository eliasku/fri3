const fp32 = @import("fp32.zig");
const Self = @This();

x: i32,
y: i32,

pub fn fromInt(x: i32, y: i32) Self {
    return .{
        .x = x << fp32.fbits,
        .y = y << fp32.fbits,
    };
}
