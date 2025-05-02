const Vec2 = struct {
    x: f32,
    y: f32,
};

inline fn clip_test(p: f32, q: f32, t0: *f32, t1: *f32) bool {
    if (p == 0.0) {
        return q >= 0.0;
    }
    const r = q / p;
    if (p < 0.0) {
        if (r > t1.*) return false;
        if (r > t0.*) t0.* = r;
    } else {
        if (r < t0.*) return false;
        if (r < t1.*) t1.* = r;
    }
    return true;
}
pub fn liang_barksy_clip_f32(
    xMin: f32,
    yMin: f32,
    xMax: f32,
    yMax: f32,
    p0: Vec2,
    p1: Vec2,
) ?struct { start: Vec2, end: Vec2 } {
    const dx = p1.x - p0.x;
    const dy = p1.y - p0.y;

    var t0: f32 = 0.0;
    var t1: f32 = 1.0;

    if (!clip_test(-dx, p0.x - xMin, &t0, &t1)) return null;
    if (!clip_test(dx, xMax - p0.x, &t0, &t1)) return null;
    if (!clip_test(-dy, p0.y - yMin, &t0, &t1)) return null;
    if (!clip_test(dy, yMax - p0.y, &t0, &t1)) return null;

    return .{
        .start = .{
            .x = p0.x + t0 * dx,
            .y = p0.y + t0 * dy,
        },
        .end = .{
            .x = p0.x + t1 * dx,
            .y = p0.y + t1 * dy,
        },
    };
}
