const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const z2d = @import("z2d");
const root = @import("../root.zig");
const dec = root.decoder;
const Layer = dec.Layer;
const Feature = dec.Feature;

const This = @This();
const Traverser = dec.LayerTraverser(This);

const WRender = struct {
    extent: u32,
    ctx: z2d.Context,
    pub fn render_geometry(self: *WRender, cmd_buffer: []u32) void {
        Cmd.decode(
            cmd_buffer,
            self,
            close_path,
            move_to,
            line_to,
        );
    }
    fn close_path(self: *WRender) void {
        self.ctx.closePath() catch {};
    }
    fn move_to(self: *WRender, x: i32, y: i32) void {
        const xy = self.convert(x, y);
        self.ctx.moveTo(@floatFromInt(xy.x), @floatFromInt(xy.y)) catch {};
    }
    fn line_to(self: *WRender, x: i32, y: i32) void {
        const xy = self.convert(x, y);
        self.ctx.lineTo(@floatFromInt(xy.x), @floatFromInt(xy.y)) catch {};
    }
    fn convert(self: *WRender, x: i32, y: i32) struct { x: i32, y: i32 } {
        const img_width = self.ctx.surface.getWidth();
        const xa = tile2img(x, self.extent, img_width);
        const ya = tile2img(y, self.extent, img_width);
        return .{
            .x = xa,
            .y = ya,
        };
    }
    fn tile2img(tile_coord: i32, extent: i32, image_size: i32) i32 {
        return (tile_coord * image_size) / extent;
    }
};

alloc: Allocator,
surface0: z2d.Surface,
context0: z2d.Context,

pub fn init(alloc: Allocator, width_height: u32) !This {
    const sfc = try z2d.Surface.init(
        .image_surface_rgb,
        alloc,
        @intCast(width_height),
        @intCast(width_height),
    );
    const context = z2d.Context.init(alloc, sfc);
    return This{
        .alloc = alloc,
        .surface0 = sfc,
        .context0 = context,
    };
}

pub fn deinit(self: *This) void {
    const alloc = self.alloc;
    self.surface0.deinit(alloc);
    self.context0.deinit();
}

pub fn render_aeroway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aeroway) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_aerodrome_label(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aerodrome_label) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_boundary(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Boundary) void {
    _ = .{ feat, self, d, layer };
    const alloc = self.alloc;
    const extent = layer.extent orelse {
        std.log.err("no extent specified", .{});
        return;
    };
    // const geomtype = feat.type orelse .UNKNOWN;
    const geo = feat.geometry.items;
    const surface = &self.surface0;
    var context = z2d.Context.init(alloc, surface);
    defer context.deinit();
    const r = WRender{ .ctx = context, .extent = extent };
    r.render_geometry(geo);
}

pub fn render_building(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Building) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_housenumber(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Housenumber) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_landcover(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Landcover) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_landuse(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Landuse) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_mountain_peak(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Mountain_peak) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_park(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Park) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_place(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Place) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_poi(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Poi) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_transportation(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Transportation) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_transportation_name(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Transportation_name) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_water(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Water) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_water_name(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Water_name) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_waterway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Waterway) void {
    _ = .{ feat, self, d, layer };
}

pub fn render(self: *This, tile: *const dec.Tile) void {
    const traverser = Traverser{
        .aeroway = render_aeroway,
        .aerodrome_label = render_aerodrome_label,
        .boundary = render_boundary,
        .building = render_building,
        .housenumber = render_housenumber,
        .landcover = render_landcover,
        .landuse = render_landuse,
        .mountain_peak = render_mountain_peak,
        .park = render_park,
        .place = render_place,
        .poi = render_poi,
        .transportation = render_transportation,
        .transportation_name = render_transportation_name,
        .water = render_water,
        .water_name = render_water_name,
        .waterway = render_waterway,
    };
    traverser.traverse_tile(tile, self);
}

const Cmd = enum {
    None,
    MoveTo,
    LineTo,
    ClosePath,

    fn op_param_count(cmd: *const Cmd) usize {
        return switch (cmd) {
            .LineTo => 2,
            .MoveTo => 2,
            else => 0,
        };
    }
    fn command_integer(x: u32) struct {
        cmd: Cmd,
        count: usize,
    } {
        const cmd_id: Cmd = switch (x & 0x7) {
            1 => .MoveTo,
            2 => .LineTo,
            7 => .ClosePath,
            else => .None,
        };
        const count = x >> 3;
        return .{
            .cmd = cmd_id,
            .count = count,
        };
    }
    fn param_integer(x: u32) i32 {
        return ((x >> 1) ^ (-(x & 1)));
    }
    fn decode(
        geometry: []const u32,
        user_data: anytype,
        cb_close_path: *const fn (@TypeOf(user_data)) void,
        cb_move_to: *const fn (@TypeOf(user_data), i32, i32) void,
        cb_line_to: *const fn (@TypeOf(user_data), i32, i32) void,
    ) !void {
        var idx: usize = 0;
        var cmdint = command_integer(geometry[0]);
        const op_count = cmdint.cmd.op_param_count();
        switch (cmdint.cmd) {
            .None => return error.InvalidCommandId,
            .ClosePath => {
                if (op_count != 0) return error.InvalidOpCount;
                cb_close_path(user_data);
            },
            .MoveTo => {
                const advance: usize = @intCast(cmdint.count);
                if (idx + advance * op_count > geometry.len) return error.InvalidEncoding;
                for (0..advance) |i| {
                    const s = idx + i * op_count;
                    const xy = geometry[s .. s + op_count];
                    const x = param_integer(xy[0]);
                    const y = param_integer(xy[1]);
                    cb_move_to(user_data, x, y);
                }
                idx += op_count * advance;
            },
            .LineTo => {
                const advance: usize = @intCast(cmdint.count);
                if (idx + advance * op_count > geometry.len) return error.InvalidEncoding;
                for (0..advance) |i| {
                    const s = idx + i * op_count;
                    const xy = geometry[s .. s + op_count];
                    const x = param_integer(xy[0]);
                    const y = param_integer(xy[1]);
                    cb_line_to(user_data, x, y);
                }
                idx += op_count * advance;
            },
        }
    }
};

test "render 1" {
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    var file = try std.fs.cwd().openFile("./testdata/leipzig_tile", .{});
    const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
    const tile: dec.Tile = try dec.decode(input, alloc);

    var rend = try This.init(alloc);
    defer rend.deinit();
    rend.render(&tile);
}
