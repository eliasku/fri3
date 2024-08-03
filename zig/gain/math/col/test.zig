const Vec2 = @import("../Vec2.zig");
const Rect = @import("../Rect.zig");

fn testLineLine(a: Vec2, b: Vec2, c: Vec2, d: Vec2) ?Vec2 {
    const a1 = b.y - a.y;
    const a2 = d.y - c.y;
    const b1 = a.x - b.x;
    const b2 = c.x - d.x;

    const denom = a1 * b2 - a2 * b1;

    if (denom == 0) {
        return null;
    }

    const c1 = b.x * a.y - a.x * b.y;
    const c2 = d.x * c.y - c.x * d.y;

    return .{
        .x = (b1 * c2 - b2 * c1) / denom,
        .y = (a2 * c1 - a1 * c2) / denom,
    };
}

test "testLineLine" {
    const std = @import("std");
    try std.testing.expect(testLineLine(Vec2.init(-1, -1), Vec2.init(1, -1), Vec2.init(-1, 1), Vec2.init(1, 1)) == null);
    const z = testLineLine(Vec2.init(-1, -1), Vec2.init(1, 1), Vec2.init(-1, 1), Vec2.init(1, -1));
    try std.testing.expect(z != null);
    try std.testing.expect(z.?.x == 0 and z.?.y == 0);
}

pub fn testSegSeg(a: Vec2, b: Vec2, c: Vec2, d: Vec2) ?Vec2 {
    if (testLineLine(a, b, c, d)) |ip| {
        {
            const l = a.distanceToSquared(b);
            if (ip.distanceToSquared(b) > l or ip.distanceToSquared(a) > l) {
                return null;
            }
        }

        {
            const l = c.distanceToSquared(d);
            if (ip.distanceToSquared(d) > l or ip.distanceToSquared(c) > l) {
                return null;
            }
        }

        return ip;
    }
    return null;
}

test "testSegSeg" {
    const std = @import("std");
    try std.testing.expect(testSegSeg(Vec2.init(-1, -1), Vec2.init(1, -1), Vec2.init(-1, 1), Vec2.init(1, 1)) == null);
    const z = testSegSeg(Vec2.init(-1, -1), Vec2.init(1, 1), Vec2.init(-1, 1), Vec2.init(1, -1));
    try std.testing.expect(z != null);
    try std.testing.expect(z.?.x == 0 and z.?.y == 0);
}

fn v2Sign(v0: Vec2, v1: Vec2, v2: Vec2) f32 {
    return (v0.x - v2.x) * (v1.y - v2.y) - (v1.x - v2.x) * (v0.y - v2.y);
}

pub fn testPointTriangle(point: Vec2, v0: Vec2, v1: Vec2, v2: Vec2) bool {
    const m = v2Sign(point, v1, v2) < 0.0;
    return m == (v2Sign(point, v0, v1) < 0.0) and m == (v2Sign(point, v2, v0) < 0.0);
}

test "testPointTriangle" {
    const std = @import("std");
    try std.testing.expect(testPointTriangle(Vec2.init(-1, -1), Vec2.init(-1, -1), Vec2.init(0, 0), Vec2.init(-1, 0)));
    try std.testing.expect(!testPointTriangle(Vec2.init(1, -1), Vec2.init(-1, -1), Vec2.init(0, 0), Vec2.init(-1, 0)));
}

pub fn testRectLine(rect: Rect, p0: Vec2, p1: Vec2) bool {

    // Calculate m and c for the equation for the line (y = mx+c)
    const m = (p1.y - p0.y) / (p1.x - p0.x);
    const c = p0.y - (m * p0.x);

    const l = rect.x;
    const r = rect.r();

    var top_intersection: f32 = undefined;
    var bottom_intersection: f32 = undefined;

    // if the line is going up from right to left then the top intersect point is on the left
    if (m > 0.0) {
        top_intersection = m * l + c;
        bottom_intersection = m * r + c;
    } else {
        // otherwise it's on the right
        top_intersection = m * r + c;
        bottom_intersection = m * l + c;
    }

    // work out the top and bottom extents for the triangle
    const top_triangle_point = if (p0.y < p1.y) p0.y else p1.y;
    const bottom_triangle_point = if (p0.y < p1.y) p1.y else p0.y;

    // and calculate the overlap between those two bounds
    const top_overlap = if (top_intersection > top_triangle_point) top_intersection else top_triangle_point;
    const bottom_overlap = if (bottom_intersection < bottom_triangle_point) bottom_intersection else bottom_triangle_point;

    // (topoverlap<botoverlap) :
    // if the intersection isn't the right way up then we have no overlap

    // (!((botoverlap<t) || (topoverlap>b)) :
    // If the bottom overlap is higher than the top of the rectangle or the top overlap is
    // lower than the bottom of the rectangle we don't have intersection. So return the negative
    // of that. Much faster than checking each of the points is within the bounds of the rectangle.
    return top_overlap < bottom_overlap and
        bottom_overlap >= rect.y and
        top_overlap <= rect.b();
}

pub fn testRectTriangle(rect: Rect, v0: Vec2, v1: Vec2, v2: Vec2) bool {
    return testRectLine(rect, v0, v1) or testRectLine(rect, v1, v2) or testRectLine(rect, v2, v0);
}
