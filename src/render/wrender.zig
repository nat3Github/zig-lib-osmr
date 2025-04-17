const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const z2d = @import("z2d");
const root = @import("../root.zig");
const dec = root.decoder;
const Layer = dec.Layer;
const Feature = dec.Feature;

const Cmd = dec.Cmd;

pub const WRender = struct {
    const Type = enum { Polygon, LineString };
    x: i32 = 0,
    y: i32 = 0,
    debug: bool = false,
    extent: u32,
    ctx: *z2d.Context,
    rtype: Type = .Polygon,
    pub fn render_geometry(self: *@This(), cmd_buffer: []u32) void {
        self.x = 0;
        self.y = 0;
        Cmd.decode(cmd_buffer, self, close_path, move_to, line_to) catch |e| {
            std.log.err("cmd decode error: {}", .{e});
            return;
        };
        switch (self.rtype) {
            .Polygon => {},
            .LineString => {
                swallow_error(self.ctx.stroke());
            },
        }
    }
    fn close_path(self: *@This()) void {
        if (self.debug) std.log.warn("close path", .{});
        swallow_error(self.ctx.closePath());
        switch (self.rtype) {
            .Polygon => {
                swallow_error(self.ctx.fill());
                self.ctx.resetPath();
            },
            .LineString => {
                swallow_error(self.ctx.stroke());
                self.ctx.resetPath();
            },
        }
    }
    fn move_to(self: *@This(), x: i32, y: i32) void {
        self.add_xy(x, y);
        const mx, const my = self.get_xy_f64();
        swallow_error(self.ctx.moveTo(mx, my));
        if (self.debug) std.log.warn("moved to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }
    fn line_to(self: *@This(), x: i32, y: i32) void {
        self.add_xy(x, y);
        const mx, const my = self.get_xy_f64();
        swallow_error(self.ctx.lineTo(mx, my));
        if (self.debug) std.log.warn("line to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }

    inline fn clampi(self: *@This(), x: i32) i32 {
        const img_width = self.ctx.surface.getWidth();
        return std.math.clamp(x, -1, img_width);
    }
    inline fn clamped_xy(self: *@This(), x: i32, y: i32) struct { i32, i32 } {
        const clampedx = self.clampi(x);
        const clampedy = self.clampi(y);
        return .{ clampedx, clampedy };
    }
    inline fn convert_and_clamp(self: *@This(), x: i32, y: i32) struct { i32, i32 } {
        const xa = self.tile2img(x);
        const ya = self.tile2img(y);
        return self.clamped_xy(xa, ya);
    }
    inline fn get_xy_f64(self: *@This()) struct { f64, f64 } {
        const x, const y = self.convert_and_clamp(self.x, self.y);
        return .{ @floatFromInt(x), @floatFromInt(y) };
    }
    inline fn add_xy(self: *@This(), x: i32, y: i32) void {
        self.x += x;
        self.y += y;
    }
    inline fn tile2img(self: *@This(), tile_coord: i32) i32 {
        const img_width = self.ctx.surface.getWidth();
        const ext: i32 = @intCast(self.extent);
        if (ext <= 1) return 0;
        return @divTrunc((tile_coord * img_width), ext);
    }
};
pub const WRender2 = struct {
    const Type = enum { Polygon, LineString };
    x: f32 = 0,
    y: f32 = 0,
    last_linev: Vec2 = .{ .x = -1, .y = -1 },
    debug: bool = false,
    extent: f32,
    ctx: *z2d.Context,
    rtype: Type = .Polygon,
    pub fn render_geometry(self: *@This(), cmd_buffer: []u32) void {
        self.x = 0;
        self.y = 0;
        Cmd.decode(cmd_buffer, self, close_path, move_to, line_to) catch |e| {
            std.log.err("cmd decode error: {}", .{e});
            return;
        };
        switch (self.rtype) {
            .Polygon => {},
            .LineString => {
                swallow_error(self.ctx.stroke());
            },
        }
    }
    fn close_path(self: *@This()) void {
        if (self.debug) std.log.warn("close path", .{});
        swallow_error(self.ctx.closePath());
        switch (self.rtype) {
            .Polygon => {
                swallow_error(self.ctx.fill());
                self.ctx.resetPath();
            },
            .LineString => {
                swallow_error(self.ctx.stroke());
                self.ctx.resetPath();
            },
        }
    }
    fn move_to(self: *@This(), dx: i32, dy: i32) void {
        self.add_xy(dx, dy);
        const v = self.transformV(Vec2{
            .x = self.x,
            .y = self.y,
        });
        swallow_error(self.ctx.moveTo(v.x, v.y));
        // if (self.debug) std.log.warn("moved to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }
    fn line_to(self: *@This(), dx: i32, dy: i32) void {
        const from = Vec2{
            .x = self.x,
            .y = self.y,
        };
        self.add_xy(dx, dy);
        const to = Vec2{
            .x = self.x,
            .y = self.y,
        };
        const res = liangBarskyClip(0, 0, self.extent, self.extent, from, to);
        if (res) |v| {
            const p0 = self.transformV(v.start);
            const p1 = self.transformV(v.end);
            if (!eqlVec2(p0, self.last_linev)) {
                swallow_error(self.ctx.lineTo(p0.x, p0.y));
            }
            swallow_error(self.ctx.lineTo(p1.x, p1.y));
            self.last_linev = p1;
        } else {
            const v = self.transformV(Vec2{
                .x = self.x,
                .y = self.y,
            });
            switch (self.rtype) {
                .Polygon => {
                    swallow_error(self.ctx.lineTo(v.x, v.y));
                },
                .LineString => {
                    swallow_error(self.ctx.stroke());
                    self.ctx.resetPath();
                    swallow_error(self.ctx.moveTo(v.x, v.y));
                },
            }
        }
    }
    inline fn eqlVec2(a: Vec2, b: Vec2) bool {
        const difx = @abs(a.x) - @abs(b.x);
        const dify = @abs(a.y) - @abs(b.y);
        return @abs(difx) + @abs(dify) < 3;
    }

    inline fn add_xy(self: *@This(), x: i32, y: i32) void {
        self.x += @floatFromInt(x);
        self.y += @floatFromInt(y);
    }
    inline fn transformV(self: *@This(), v: Vec2) Vec2 {
        const xdim: f32 = @floatFromInt(self.ctx.surface.getWidth());
        const ydim: f32 = @floatFromInt(self.ctx.surface.getHeight());
        return Vec2{
            .x = std.math.clamp(self.transformf32(v.x), -1, xdim),
            .y = std.math.clamp(self.transformf32(v.y), -1, ydim),
        };
    }
    inline fn transformf32(self: *@This(), tile_coord: f32) f32 {
        const img_width: f32 = @floatFromInt(self.ctx.surface.getWidth());
        if (self.extent <= 1) return 0;
        return (tile_coord * (img_width)) / self.extent;
    }

    inline fn transform(self: *@This(), tile_coord: i32) i32 {
        const img_width = self.ctx.surface.getWidth();
        const ext: i32 = @intFromFloat(self.extent);
        if (ext <= 1) return 0;
        return @divTrunc((tile_coord * img_width), ext);
    }
};

inline fn swallow_error(res: anyerror!void) void {
    _ = res catch |e| std.log.err("error: {}", .{e});
}

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
pub fn liangBarskyClip(
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
