const std = @import("std");
const js = @import("js.zig");

pub fn log(msg: []const u8) void {
    if (@hasDecl(js, "log")) {
        js.log(msg.ptr, msg.len);
    } else {
        std.log.info("{s}", .{msg});
    }
}
