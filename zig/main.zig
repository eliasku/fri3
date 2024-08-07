comptime {
    @setFloatMode(.optimized);
}
const gain = @import("./gain/main.zig");
pub const panic = gain.panic;

const colorsense = @import("./colorsense/main.zig");
const fun1 = @import("fun1.zig");

pub fn update() void {
    colorsense.update();
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
