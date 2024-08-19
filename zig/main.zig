comptime {
    @setFloatMode(.optimized);
}
const gain = @import("./gain/main.zig");
pub const panic = gain.panic;

const colorsense = @import("./colorsense/main.zig");
const fun1 = @import("fun1.zig");

const game = @import("game/main.zig");

pub fn update() void {
    //colorsense.update();
    //fun1.update();
    game.update();
}

pub fn render() void {
    //colorsense.render();
    //fun1.render();
    game.render();
}

comptime {
    gain.configure(update, render);
}

test "main" {}
