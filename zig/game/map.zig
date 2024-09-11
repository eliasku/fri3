const fp32 = @import("fp32.zig");
const FPRect = @import("FPRect.zig");
const FPVec2 = @import("FPVec2.zig");
const gain = @import("../gain/main.zig");

const fbits = fp32.fbits;
pub const Cell = u8;
pub const size_bits = 8;
pub const size = 1 << size_bits;
pub const size_mask = size - 1;
pub var map: [1 << (size_bits << 1)]Cell = undefined;
pub var colors: [1 << (size_bits << 1)]u8 = undefined;
pub var gen: [1 << (size_bits << 1)]u8 = undefined;

pub const cell_size_bits = 5 + fbits;
pub const cell_size = 1 << cell_size_bits;
pub const cell_size_half = cell_size >> 1;

pub fn addr(x: anytype, y: anytype) usize {
    @setRuntimeSafety(false);
    const _x: usize = @intCast(x);
    const _y: usize = @intCast(y);
    return (_y << size_bits) + _x;
}

pub fn get(x: anytype, y: anytype) Cell {
    @setRuntimeSafety(false);
    return map[addr(x, y)];
}

pub var current_color: u8 = 0;

pub fn set(x: anytype, y: anytype, v: Cell) void {
    @setRuntimeSafety(false);
    const i = addr(x, y);
    map[i] = v;
    colors[i] = current_color % 6;
}

pub fn setGen(x: i32, y: i32) void {
    @setRuntimeSafety(false);
    gen[addr(x, y)] = 1;
}

pub fn isGenFree(x: i32, y: i32) bool {
    @setRuntimeSafety(false);
    return gen[addr(x, y)] == 0;
}

pub fn getPoint(x: i32, y: i32) Cell {
    const cx = @max(0, x) >> cell_size_bits;
    const cy = @max(0, y) >> cell_size_bits;
    return map[(cy << size_bits) + cx];
}

pub fn testPoint(x: i32, y: i32) bool {
    return getPoint(x, y) == 0;
}

pub fn testRect(rc: FPRect) bool {
    return testPoint(rc.x, rc.y) or
        testPoint(rc.x, rc.b()) or
        testPoint(rc.r(), rc.y) or
        testPoint(rc.r(), rc.b());
}

pub fn coordToPos(x: i32, y: i32) FPVec2 {
    return .{
        .x = (x << cell_size_bits) + cell_size_half,
        .y = (y << cell_size_bits) + cell_size_half,
    };
}

// path find

const path_max = 16;
pub var path_x: [path_max]i32 = undefined;
pub var path_y: [path_max]i32 = undefined;
pub var path_num: usize = undefined;
pub var path_dest_x: i32 = undefined;
pub var path_dest_y: i32 = undefined;
var pf_visited: [1 << (size_bits << 1)]u8 = undefined;
var pf_parent_x: [path_max]i32 = undefined;
var pf_parent_y: [path_max]i32 = undefined;

fn visitNeighbor(x: i32, y: i32, depth: usize) void {
    if (x > 0 and y > 0 and x < size - 1 and y < size - 1) {
        const i = addr(x, y);
        if (pf_visited[i] == 0 and map[i] == 1) {
            pf_visited[i] = 1;
            searchPath(x, y, depth + 1);
            pf_visited[i] = 0;
        }
    }
}

fn searchPath(x: i32, y: i32, depth: usize) void {
    const path_len = depth + 1;
    if (path_num == 0 or path_len < path_num) {
        pf_parent_x[depth] = x;
        pf_parent_y[depth] = y;
        if (path_dest_x == x and path_dest_y == y) {
            path_num = path_len;
            var i = path_len;
            while (i != 0) {
                i -= 1;
                path_x[i] = pf_parent_x[i];
                path_y[i] = pf_parent_y[i];
            }
        } else if (path_len < path_max) {
            visitNeighbor(x - 1, y, depth);
            visitNeighbor(x + 1, y, depth);
            visitNeighbor(x, y - 1, depth);
            visitNeighbor(x, y + 1, depth);
        }
    }
}

pub fn findPath(bx: i32, by: i32, ex: i32, ey: i32) void {
    path_num = 0;
    path_dest_x = ex >> cell_size_bits;
    path_dest_y = ey >> cell_size_bits;
    const i = addr(bx >> cell_size_bits, by >> cell_size_bits);
    pf_visited[i] = 1;
    searchPath(bx >> cell_size_bits, by >> cell_size_bits, 0);
    pf_visited[i] = 0;
}
