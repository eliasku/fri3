const gain = @import("../gain/main.zig");
const gfx = gain.gfx;
const app = gain.app;
const pointers = gain.pointers;
const Color32 = @import("../gain/main.zig").math.Color32;
const Vec2 = @import("../gain/main.zig").math.Vec2;
const Mat2d = @import("../gain/main.zig").math.Mat2d;
const AABB = @import("aabbi.zig");
const bg = @import("background.zig");

// Base Resolution : 360 x 480

pub fn update() void {
    bg.update();
    if (pointers.primary()) |p| {
        if (p.down) {
            bg.click(p.start.center());
        }
    }
}

pub fn render() void {
    const app_size = app.size();

    gfx.setupOpaquePass();
    gfx.setTexture(0);

    gfx.state.z = 0;
    gfx.state.matrix = Mat2d.identity();
    gfx.quadColors(Vec2.zero(), app_size, .{ 0xFF002020, 0xFF002020, 0xFF000909, 0xFF000909 });

    gfx.state.z = 2;
    gfx.setupBlendPass();
    gfx.setTexture(0);

    bg.render();

    // draw text
    {
        gfx.setTexture(1);
        var buffer: [128 * 128 * 4]u8 = undefined;
        const image = gfx.drawText("START GAME", &buffer);
        gfx.setTextureData(.{
            .id = 1,
            .w = image.w,
            .h = image.h,
            .filter = 0,
            .wrap_s = 0,
            .wrap_t = 0,
            .data = gfx.CRange.fromSlice(image.pixels),
        });

        gfx.setTexture(1);
        //gfx.state.z = 4;
        gfx.state.matrix = Mat2d.identity();
        gfx.quad(Vec2.splat(200), Vec2.fromIntegers(image.w, image.h), 0xFFFFFFFF);
    }

    gfx.setTexture(0);
    const aabb1 = AABB.init(400, 400, 400, 400);

    if (pointers.primary()) |p| {
        const x: i32 = @intFromFloat(p.rc.centerX());
        const y: i32 = @intFromFloat(p.rc.centerY());
        const aabb2 = AABB.init(x, y, 100, 200);
        gfx.quad(aabb2.posf(), aabb2.sizef(), if (aabb1.check(aabb2)) 0xFF999933 else 0xFF993333);
    }
    gfx.quad(aabb1.posf(), aabb1.sizef(), 0xFF999999);
}

fn drawDebugPointers() void {
    for (pointers.map.values()) |p| {
        gfx.state.matrix = Mat2d.identity();
        const radius = (if (p.device == .mouse) Vec2.init(32, 32) else p.rc.size()).scale(0.5);
        if (p.device == .mouse) {
            gfx.fillCircleEx(
                p.rc.center(),
                radius,
                16,
                0x99FFFFFF,
                0x00FFFFFF,
            );
        }
        {
            gfx.fillCircleEx(
                p.rc.center(),
                radius,
                16,
                if (p.is_primary) 0xFF00FF00 else 0xFFFFFF00,
                0x00000000,
            );
        }
    }
    if (pointers.primary()) |p| {
        _ = p; // autofix
        // gfx.matrix = Mat2d.identity();
        // gfx.quad(
        //     p.rc.pos(),
        //     p.rc.size(),
        //     0xFF00FF00,
        // );
    }
}
