pub usingnamespace @import("functions.zig");
pub const Vec2 = @import("Vec2.zig");
pub const Vec3 = @import("Vec3.zig");
pub const Vec4 = @import("Vec4.zig");
pub const Color32 = @import("Color32.zig");
pub const Rect = @import("Rect.zig");
pub const Mat2d = @import("Mat2d.zig");
pub const Rot = @import("Rot.zig");
pub const Rnd = @import("Rnd.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@import("col/test.zig"));
    std.testing.refAllDecls(@import("functions.zig"));
    std.testing.refAllDecls(@import("Vec2.zig"));
    std.testing.refAllDecls(@import("Vec3.zig"));
    std.testing.refAllDecls(@import("Vec4.zig"));
    std.testing.refAllDecls(@import("Color32.zig"));
    std.testing.refAllDecls(@import("Rot.zig"));
    std.testing.refAllDecls(@import("Mat2d.zig"));
    std.testing.refAllDecls(@import("Rnd.zig"));
}
