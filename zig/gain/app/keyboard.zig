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
};
pub var down: [0x100]u1 = undefined;
pub var pressed: [0x100]u1 = undefined;
pub var released: [0x100]u1 = undefined;

pub fn reset() void {
    @memset(pressed, 0);
    @memset(released, 0);
}

pub fn onEvent(event: u32, code_val: u32) void {
    // keep range ( mask for 8bit );
    const key: u8 = @truncate(code_val);
    switch (event) {
        // DOWN
        0 => if (down[key] == 0) {
            pressed[key] = 1;
            down[key] = 1;
        },
        // UP
        1 => if (down[key] == 1) {
            released[key] = 1;
            down[key] = 0;
        },
        else => unreachable,
    }
}
