const std = @import("std");

// https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/keyCode
pub const Code = .{
    .dead = 0,
    .escape = 0x1B,
    .space = 0x20,
    .enter = 0x0D,
    .w = 0x57,
    .a = 0x41,
    .s = 0x53,
    .d = 0x44,
    .arrow_left = 0x25,
    .arrow_up = 0x26,
    .arrow_right = 0x27,
    .arrow_down = 0x28,
};
pub var down: [0x100]u1 = undefined;

pub fn onEvent(event: u32, code_val: u32) void {
    down[code_val & 0xFF] = switch (event) {
        0 => 1,
        1 => 0,
        else => unreachable,
    };
}
