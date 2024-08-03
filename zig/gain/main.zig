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
pub const dirty_trig = @import("./p/sin_b1.zig");
pub const dirty_pow = @import("./p/fast_pow.zig");
// temp: move to library
pub const zzfx = @import("./p/zzfx.zig");

//pub usingnamespace if (builtin.mode == .ReleaseSmall) struct {
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    @setCold(true);
    if (js.enabled and !builtin.is_test) {
        console.log(msg);
        while (true) {
            @breakpoint();
        }
    } else {
        std.builtin.default_panic(msg, error_return_trace, ret_addr);
    }
}

//} else struct {};

pub inline fn configure(comptime init: fn () void, comptime update: fn () void) void {
    const A = struct {
        export fn onSetup() void {
            // if (builtin.cpu.arch.isWasm()) {
            //     allocator = std.heap.wasm_allocator;
            // } else {
            //     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            //     //defer std.testing.expect(gpa.deinit() == .ok) catch @panic("leak");
            //     allocator = gpa.allocator();
            // }
            // keyboard.setup();
        }

        export fn onFirstFrame(t: f32, w: u32, h: u32) void {
            app.w = w;
            app.h = h;
            app.time_prev = t;
            app.t = t;
            app.tic = 0;

            init();
        }

        export fn onFrame(t: f32, w: u32, h: u32) void {
            app.w = w;
            app.h = h;
            app.t = t;
            app.dt = t - app.time_prev;
            app.time_prev = t;
            app.tic += 1;

            gfx.beginFrame();
            update();
            gfx.endFrame();

            pointers.reset();
        }

        export fn onPointerEvent(id: u32, primary: u32, buttons: u32, event: u32, device: u32, x: f32, y: f32, w: f32, h: f32) void {
            pointers.onEvent(
                id,
                primary,
                buttons,
                @enumFromInt(event),
                @enumFromInt(device),
                .{
                    .x = x - w / 2,
                    .y = y - h / 2,
                    .w = w,
                    .h = h,
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
