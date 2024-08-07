comptime {
    @setFloatMode(.optimized);
}
const gain = @import("./gain/main.zig");
pub const panic = gain.panic;

const colorsense = @import("./colorsense/main.zig");
const fun1 = @import("fun1.zig");

var font: gain.gfx.Font = undefined;

pub fn update() void {
    if (gain.app.tic == 0) {
        font = gain.gfx.Font.init("main", "defaultfont.ttf");
    }
    if (font.status() != 0) {
        colorsense.update();
    }
    fun1.update();
}

pub fn render() void {
    fun1.render();
    colorsense.render();
}

comptime {
    gain.configure(update, render);
}

test "main" {}
