const std = @import("std");
const Vec2 = @import("../math/Vec2.zig");

pub const EventType = enum(u32) {
    down = 0,
    move = 1,
    up = 2,
    enter = 3,
    leave = 4,
};

pub const DeviceType = enum(u32) {
    mouse = 0,
    finger = 1,
    pen = 2,
};

const Pointer = struct {
    id: u32,
    device: DeviceType,
    pos: Vec2,
    start: Vec2,
    down: bool,
    up: bool,
    is_down: bool,
    active: bool,
    buttons: u32,
    is_primary: bool,
};

const Pointers = std.BoundedArray(Pointer, 8);

pub var items: Pointers = Pointers{};

pub fn primary() ?*Pointer {
    for (items.slice()) |*item| {
        if (item.is_primary) {
            return item;
        }
    }
    return null;
}

pub fn get(id: u32) ?*Pointer {
    for (items.slice()) |*item| {
        if (item.id == id) {
            return item;
        }
    }
    return null;
}

pub fn reset() void {
    for (items.slice(), 0..) |*item, i| {
        item.down = false;
        item.up = false;
        if (!item.active) {
            _ = items.swapRemove(i);
        }
    }
}

pub fn onEvent(id: u32, is_primary: u32, buttons: u32, event: EventType, device: DeviceType, pos: Vec2) void {
    const p = get(id) orelse items.addOne() catch @panic("");
    p.id = id;
    p.pos = pos;
    p.is_primary = is_primary != 0;
    p.device = device;
    p.buttons = buttons;
    switch (event) {
        .down => {
            p.active = true;
            p.is_down = true;
            p.start = pos;
            p.down = true;
        },
        .move => p.active = true,
        .up => {
            p.up = p.active;
            p.is_down = false;
        },
        .enter => p.active = true,
        .leave => {
            p.active = false;
            p.is_down = false;
        },
    }
}
