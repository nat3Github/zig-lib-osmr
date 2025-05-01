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

pub const WRender2 = struct {
    const Type = enum { Polygon, LineString };
    x: f64 = 0,
    y: f64 = 0,
    last_linev: Vec2 = .{ .x = -1, .y = -1 },
    debug: bool = false,
    extent: f64,
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
    }
    fn line_to(self: *@This(), dx: i32, dy: i32) void {
        self.add_xy(dx, dy);
        const v = self.transformV(Vec2{
            .x = self.x,
            .y = self.y,
        });
        swallow_error(self.ctx.lineTo(v.x, v.y));
    }
    inline fn add_xy(self: *@This(), x: i32, y: i32) void {
        self.x += @floatFromInt(x);
        self.y += @floatFromInt(y);
    }
    inline fn transformV(self: *@This(), v: Vec2) Vec2 {
        const overshoot_percentage = 0.25;
        const xdim: f64 = @floatFromInt(self.ctx.surface.getWidth());
        const ydim: f64 = @floatFromInt(self.ctx.surface.getHeight());
        const xovershoot: f64 = xdim * overshoot_percentage;
        const yovershoot: f64 = ydim * overshoot_percentage;
        return Vec2{
            .x = std.math.clamp(self.transformf64(v.x), -xovershoot, xdim + xovershoot),
            .y = std.math.clamp(self.transformf64(v.y), -yovershoot, ydim + yovershoot),
        };
    }
    inline fn transformf64(self: *@This(), tile_coord: f64) f64 {
        const width: f64 = @floatFromInt(self.ctx.surface.getWidth());
        if (self.extent <= 1) return 0;
        const res = (tile_coord * width) / self.extent;
        return res;
    }
};

inline fn swallow_error(res: anyerror!void) void {
    _ = res catch |e| std.log.err("error: {}", .{e});
}

const Vec2 = struct {
    x: f64,
    y: f64,
};
