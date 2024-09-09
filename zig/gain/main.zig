const std = @import("std");
const builtin = @import("builtin");

pub const app = @import("app/app.zig");
pub const keyboard = @import("app/keyboard.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const pointers = @import("app/pointers.zig");

pub const math = @import("./math/main.zig");
pub const js = @import("./js.zig");
pub const wasm = @import("./wasm.zig");
pub const console = @import("./console.zig");

pub const zzfx = @import("./p/zzfx.zig");

//pub usingnamespace if (builtin.mode == .ReleaseSmall) struct {
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    @setCold(true);
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    //if (js.enabled and !builtin.is_test) {
    //while (true) {
    @breakpoint();
    unreachable;
    //}
    //}
    // else {
    //     std.builtin.default_panic(msg, error_return_trace, ret_addr);
    // }
}

//} else struct {};

pub inline fn configure(comptime update: fn () void, comptime render: fn () void) void {
    const A = struct {
        export fn onFrameRequest(total_steps: u32, w: u32, h: u32) void {
            app.w = w;
            app.h = h;

            var steps_left = total_steps;
            while (steps_left != 0) {
                // drop extra frames
                if (steps_left < 8) {
                    update();
                }
                app.tic += 1;
                steps_left -= 1;
                pointers.reset();
            }

            gfx.beginFrame();
            render();
            gfx.endFrame();
        }

        export fn onPointerEvent(id: u32, primary: u32, buttons: u32, event: u32, device: u32, x: f32, y: f32) void {
            pointers.onEvent(
                id,
                primary,
                buttons,
                @enumFromInt(event),
                @enumFromInt(device),
                .{
                    .x = x,
                    .y = y,
                },
            );
        }

        export fn onKeyboardEvent(event: u32, code_val: u32) void {
            keyboard.onEvent(event, code_val);
        }
    };

    @import("_bridge.zig").declareExports(A);
}

test "gain" {
    std.testing.refAllDeclsRecursive(@This());
}
