comptime {
    @setFloatMode(.optimized);
}
const gain = @import("./gain/main.zig");
pub const panic = gain.panic;

const colorsense = @import("./colorsense/main.zig");
const fun1 = @import("fun1.zig");

var font: gain.gfx.Font = undefined;

pub fn initialize() void {
    font = gain.gfx.Font.init("main", "defaultfont.ttf");
    // font = gain.gfx.Font.init("main", "arial");
}

pub fn update() void {
    if (font.status() != 0) {
        colorsense.update();
    }
    fun1.update();
    fun1.render();
}

comptime {
    gain.configure(initialize, update);
}

test "main" {}
