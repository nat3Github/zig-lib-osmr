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
const Cmd = dec.Cmd;
const color = root.color;

const WRender = struct {
    const Type = enum {
        Polygon,
        LineString,
    };
    x: i32 = 0,
    y: i32 = 0,
    extent: u32,
    ctx: *z2d.Context,
    rtype: Type = .Polygon,
    pub fn render_geometry(
        self: *WRender,
        cmd_buffer: []u32,
    ) void {
        Cmd.decode(
            cmd_buffer,
            self,
            close_path,
            move_to,
            line_to,
        ) catch |e| {
            std.log.err("cmd decode error: {}", .{e});
            return;
        };
        switch (self.rtype) {
            .Polygon => {},
            .LineString => {
                self.ctx.stroke() catch {};
            },
        }
    }
    fn close_path(self: *WRender) void {
        // std.log.warn("close path", .{});
        self.ctx.closePath() catch {};
        switch (self.rtype) {
            .Polygon => {
                self.ctx.fill() catch {};
            },
            .LineString => {
                self.ctx.stroke() catch {};
            },
        }
    }
    fn move_to(self: *WRender, x: i32, y: i32) void {
        self.set_xy(x, y);
        const mx, const my = self.get_xy_f64();
        self.ctx.moveTo(mx, my) catch {};
        // std.log.warn("moved to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }
    fn line_to(self: *WRender, x: i32, y: i32) void {
        self.add_xy(x, y);
        const mx, const my = self.get_xy_f64();
        self.ctx.lineTo(mx, my) catch {};
        // std.log.warn("line to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }

    inline fn clamped_xy(self: *WRender, x: i32, y: i32) struct { i32, i32 } {
        const img_width = self.ctx.surface.getWidth();
        const clampedx = std.math.clamp(x, 0, img_width - 1);
        const clampedy = std.math.clamp(y, 0, img_width - 1);
        return .{ clampedx, clampedy };
    }
    inline fn convert_and_clamp(self: *WRender, x: i32, y: i32) struct { i32, i32 } {
        const img_width = self.ctx.surface.getWidth();
        const extent_signed: i32 = @intCast(self.extent);
        const xa = tile2img(x, extent_signed, img_width);
        const ya = tile2img(y, extent_signed, img_width);
        return self.clamped_xy(xa, ya);
    }
    inline fn get_xy_f64(self: *WRender) struct { f64, f64 } {
        const x, const y = self.convert_and_clamp(self.x, self.y);
        return .{ @floatFromInt(x), @floatFromInt(y) };
    }
    inline fn set_xy(self: *WRender, x: i32, y: i32) void {
        self.x = x;
        self.y = y;
    }
    inline fn add_xy(self: *WRender, x: i32, y: i32) void {
        self.x += x;
        self.y += y;
    }
    inline fn tile2img(tile_coord: i32, extent: i32, image_size: i32) i32 {
        if (extent == 0) return 0;
        return @divTrunc((tile_coord * image_size), extent);
    }
};

alloc: Allocator,
surface0: z2d.Surface,
context0: z2d.Context = undefined,
counter: usize = 2,

const toggle_aeroway = false;
const toggle_aerodrome_label = false;
const toggle_boundary = false;
const toggle_building = false;
const toggle_housenumber = false;
const toggle_landcover = false;
const toggle_landuse = false;
const toggle_mountain_peak = false;
const toggle_park = false;
const toggle_place = false;
const toggle_poi = false;
const toggle_transportation = true;
const toggle_transportation_name = false;
const toggle_water = false;
const toggle_water_name = false;
const toggle_waterway = false;

pub fn init(alloc: Allocator, width_height: u32) !This {
    var t = This{
        .alloc = alloc,
        .surface0 = try z2d.Surface.init(
            .image_surface_rgb,
            alloc,
            @intCast(width_height),
            @intCast(width_height),
        ),
    };
    t.context0 = z2d.Context.init(alloc, &t.surface0);
    return t;
}

pub fn deinit(self: *This) void {
    const alloc = self.alloc;
    self.surface0.deinit(alloc);
    self.context0.deinit();
}

pub fn draw(self: *This, layer: *const Layer, feat: *const Feature, col: color, surface: *z2d.Surface) void {
    const alloc = self.alloc;
    const extent = get_extent(layer);
    const geomtype = feat.type orelse .UNKNOWN;
    const geo = feat.geometry.items;
    var context = z2d.Context.init(alloc, surface);
    defer context.deinit();
    var ren = WRender{ .ctx = &context, .extent = extent };
    switch (geomtype) {
        .POINT => std.log.warn("not implemented", .{}),
        .LINESTRING => {
            ren.rtype = .LineString;
        },
        .POLYGON => {
            ren.rtype = .Polygon;
        },
        else => return,
    }
    const r, const g, const b = col.rgb();
    context.setSourceToPixel(.{ .rgb = .{ .r = r, .g = g, .b = b } });
    ren.render_geometry(geo);
}

inline fn get_extent(layer: *const Layer) u32 {
    const extent = layer.extent orelse {
        std.log.err("no extent specified", .{});
        return 4096;
    };
    return extent;
}

pub fn render_aeroway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aeroway) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_aerodrome_label(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aerodrome_label) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_boundary(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Boundary) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_building(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Building) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_housenumber(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Housenumber) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_landcover(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Landcover) void {
    if (toggle_landcover) {
        const LandCoverColors = struct {
            pub const dark_green = color.TreesAndNature.dark_green;
            pub const green = color.TreesAndNature.light_green; //Green.grass;
            pub const yellow = color.Nature.ocker;
            pub const brown = color.Nature.brown;
            pub const white = color.Aquatic.white;
            pub const gray = color.Gray.light_gray;
        };
        const LandCoverKeyMap = struct {
            pub const white = &.{"ice"};
            pub const gray = &.{"rock"};
            pub const dark_green = &.{"wood"};
            pub const green = &.{"grass"};
            pub const yellow = &.{"sand"};
            pub const brown = &.{ "wetland", "farmland" };
        };
        const Col = color.ColorMap(LandCoverKeyMap, LandCoverColors);
        const col = Col.map(d.class) orelse color.from_hex(LandCoverColors.green);
        self.draw(layer, feat, col, &self.surface0);
    }
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
    if (toggle_transportation) {
        const highway = &.{
            "motorway",
            "trunk",
            "motorway_construction",
            "trunk_construction",
        };

        const primary = &.{
            "primary",
            "secondary",
            "tertiary",
            "primary_construction",
            "secondary_construction",
            "tertiary_construction",
        };

        const minor = &.{
            "minor",
            "service",
            "minor_construction",
            "service_construction",
        };

        const path = &.{
            "path",
            "track",
            "raceway",
            "path_construction",
            "track_construction",
            "raceway_construction",
        };

        const transit = &.{
            "busway",
            "bus_guideway",
            "ferry",
        };

        const Color = struct {
            pub const purple = color.DarkPurple.purple900;
            pub const black = color.Gray.dark_gray;
            pub const gray = color.Gray.gray;
            pub const light_gray = color.Gray.light_gray;
            pub const red = color.DeepRed.red800;
        };
        const Keys = struct {
            pub const purple = highway;
            pub const black = primary;
            pub const gray = minor;
            pub const light_gray = path;
            pub const red = transit;
        };
        const M = color.ColorMap(Keys, Color);
        const col = M.map(d.class) orelse color.from_hex(Color.gray);

        self.draw(layer, feat, col, &self.surface0);
    }
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

test "render 1" {
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    var file = try std.fs.cwd().openFile("./testdata/leipzig_tile", .{});
    const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
    const tile: dec.Tile = try dec.decode(input, alloc);

    var rend = try This.init(alloc, 1024);
    rend.render(&tile);

    try z2d.png_exporter.writeToPNGFile(rend.surface0, "./testdata/surface0.png", .{});
}

test "render test" {
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    const width_height = 1024;
    var sfc = try z2d.Surface.init(
        .image_surface_rgb,
        alloc,
        @intCast(width_height),
        @intCast(width_height),
    );
    var context = z2d.Context.init(alloc, &sfc);
    context.setSourceToPixel(.{ .rgb = .{ .r = 0xFF, .g = 0xFF, .b = 0x00 } });
    // [default] (warn): moved to x: 30, y: 692
    // [default] (warn): line to x: 25, y: 696
    // [default] (warn): line to x: 0, y: 713
    // [default] (warn): line to x: 0, y: 717
    // [default] (warn): line to x: 0, y: 700
    // [default] (warn): line to x: 6, y: 691
    // [default] (warn): line to x: 0, y: 678
    // [default] (warn): line to x: 0, y: 683
    // [default] (warn): line to x: 0, y: 681
    // [default] (warn): line to x: 0, y: 680
    // [default] (warn): line to x: 0, y: 674
    // [default] (warn): line to x: 0, y: 675
    // [default] (warn): line to x: 0, y: 651
    // [default] (warn): line to x: 23, y: 680
    // [default] (warn): close path

    try context.moveTo(30, 692);
    try context.lineTo(25, 696);
    try context.lineTo(0, 713);
    try context.lineTo(0, 717);
    try context.lineTo(0, 700);
    try context.lineTo(6, 691);
    try context.lineTo(0, 678);
    try context.lineTo(0, 683);
    try context.lineTo(0, 681);
    try context.lineTo(0, 680);
    try context.lineTo(0, 674);
    try context.lineTo(0, 675);
    try context.lineTo(0, 651);
    try context.lineTo(23, 680);
    try context.closePath();
    try context.fill();
    // context.stroke() catch {};

    try z2d.png_exporter.writeToPNGFile(sfc, "./testdata/surface1.png", .{});
}
