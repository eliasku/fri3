const std = @import("std");

const Code = enum(u32) {
    dead = 0,
    escape = 1,
    space = 2,
    enter = 3,
};

const KeyState = struct {
    code: Code,
    pressed: u32 = 0,
    released: u32 = 0,
    is_down: bool = false,
};

const Map = std.EnumMap(Code, KeyState);

pub var map: Map = Map{};

pub fn reset() void {
    var it = map.iterator();
    while (it.next()) |*state| {
        state.value.pressed = 0;
        state.value.released = 0;
    }
}

pub fn onEvent(event: u32, code_val: u32) void {
    const code: Code = @enumFromInt(code_val);
    if (!map.contains(code)) {
        map.put(code, .{ .code = code });
    }
    var state: *KeyState = map.getPtr(code).?;
    // DOWN
    if (event == 0) {
        if (!state.is_down) {
            state.pressed += 1;
            state.is_down = true;
        }
    }
    // UP
    else if (event == 1) {
        if (state.is_down) {
            state.released += 1;
            state.is_down = false;
        }
    }
}
