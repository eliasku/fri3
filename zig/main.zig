comptime {
    @setFloatMode(.optimized);
}
const gain = @import("./gain/main.zig");
pub const panic = gain.panic;

const game = @import("game/main.zig");

comptime {
    gain.configure(
        game.update,
        game.render,
    );
}

test "main" {}
