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

// tailwind colors
pub const Tailwind = @import("tailwind");
const Line = root.thickness;

const WRender = struct {
    const Type = enum { Polygon, LineString };
    x: i32 = 0,
    y: i32 = 0,
    debug: bool = false,
    extent: u32,
    ctx: *z2d.Context,
    rtype: Type = .Polygon,
    pub fn render_geometry(self: *WRender, cmd_buffer: []u32) void {
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
    fn close_path(self: *WRender) void {
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
    fn move_to(self: *WRender, x: i32, y: i32) void {
        self.add_xy(x, y);
        const mx, const my = self.get_xy_f64();
        swallow_error(self.ctx.moveTo(mx, my));
        if (self.debug) std.log.warn("moved to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }
    fn line_to(self: *WRender, x: i32, y: i32) void {
        self.add_xy(x, y);
        const mx, const my = self.get_xy_f64();
        swallow_error(self.ctx.lineTo(mx, my));
        if (self.debug) std.log.warn("line to x: {d:.0}, y: {d:.0}", .{ mx, my });
    }

    inline fn clamped_xy(self: *WRender, x: i32, y: i32) struct { i32, i32 } {
        const img_width = self.ctx.surface.getWidth();
        if (img_width < 1) std.debug.panic("img width was smaller than 1", .{});
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
    inline fn add_xy(self: *WRender, x: i32, y: i32) void {
        self.x += x;
        self.y += y;
    }
    inline fn tile2img(tile_coord: i32, extent: i32, image_size: i32) i32 {
        if (extent == 0) return 0;
        return @divTrunc((tile_coord * image_size), extent);
    }
};

inline fn swallow_error(res: anyerror!void) void {
    _ = res catch |e| std.log.err("error: {}", .{e});
}
alloc: Allocator,
surface0: z2d.Surface,
context0: ?z2d.Context = null,
counter: usize = 0,

const RenderConfig = struct {
    toggle_building: bool = false,
    toggle_landcover: bool = false,
    toggle_transportation: bool = false,
    toggle_transportation_name: bool = false,
    toggle_water: bool = false,
    toggle_waterway: bool = false,
    toggle_aeroway: bool = false,
    toggle_boundary: bool = false,

    // NOTE: not implemented for now
    toggle_aerodrome_label: bool = false,
    toggle_housenumber: bool = false,
    toggle_landuse: bool = false,
    toggle_mountain_peak: bool = false,
    toggle_park: bool = false,
    toggle_place: bool = false,
    toggle_poi: bool = false,
    toggle_water_name: bool = false,

    pub const Implemented = RenderConfig{
        .toggle_transportation = true,
        // .toggle_transportation_name = true,
        // .toggle_building = true,
        // .toggle_landcover = true,
        // .toggle_water = true,
        // .toggle_waterway = true,
        // in implementation
        .toggle_boundary = true,
        .toggle_aeroway = true,
    };
    pub const LandAndWater = RenderConfig{
        .toggle_landcover = true,
        .toggle_water = true,
        .toggle_waterway = true,
    };
    pub const StreetsAndBuildings = RenderConfig{
        .toggle_transportation = true,
        .toggle_transportation_name = true,
        .toggle_building = true,
        .toggle_aeroway = true,
        .toggle_boundary = true,
    };
};

pub fn init(alloc: Allocator, width_height: u32) !This {
    return This{
        .alloc = alloc,
        .surface0 = try z2d.Surface.init(
            .image_surface_rgb,
            alloc,
            @intCast(width_height),
            @intCast(width_height),
        ),
    };
}
fn set_context(self: *This) void {
    self.context0 = z2d.Context.init(self.alloc, &self.surface0);
}

pub fn deinit(self: *This) void {
    const alloc = self.alloc;
    self.surface0.deinit(alloc);
    self.context0.deinit();
}

inline fn draw(self: *This, layer: *const Layer, feat: *const Feature, col: color, line_width: f64) void {
    assert(self.context0 != null);
    if (self.context0) |*context| {
        swallow_error(context.moveTo(0, 0));
        context.resetPath();
        const extent = get_extent(layer);
        const geomtype = feat.type orelse .UNKNOWN;
        const geo = feat.geometry.items;
        var ren = WRender{ .ctx = context, .extent = extent };
        switch (geomtype) {
            .POINT => std.log.warn("point drawing not implemented", .{}),
            .LINESTRING => {
                ren.rtype = .LineString;
                context.setLineWidth(line_width);
            },
            .POLYGON => {
                ren.rtype = .Polygon;
                context.setLineWidth(line_width);
            },
            else => return,
        }
        const r, const g, const b = col.rgb();
        context.setSourceToPixel(.{ .rgb = .{ .r = r, .g = g, .b = b } });
        ren.render_geometry(geo);
    }
}

inline fn get_extent(layer: *const Layer) u32 {
    const extent = layer.extent orelse {
        std.log.err("no extent specified", .{});
        return 4096;
    };
    return extent;
}
inline fn log_any(self: *This, t: anytype) void {
    const s = dec.print_any(t, self.alloc) catch |e| {
        std.log.err("failed to print log because of {}", .{e});
        return;
    };
    std.log.warn("{s}", .{s});
    self.alloc.free(s);
}

pub fn render_aeroway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aeroway) void {
    const Keys = struct {
        pub const sky100 = &.{"aerodrome"};
        pub const neutral300 = &.{ "runway", "taxiway" };
        pub const yellow100 = &.{"apron"};
        pub const orange400 = &.{"gate"};
        pub const amber300 = &.{ "heliport", "helipad" };
    };
    const col = color.ColorMap(Keys, Tailwind).map(d.class) orelse color.from_hex(Tailwind.neutral400);
    self.draw(layer, feat, col, 1.0);
}
pub fn render_aerodrome_label(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aerodrome_label) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_boundary(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Boundary) void {
    const col = color.from_hex(Tailwind.zinc300);
    const line_width = Line.StandardSizes.L;
    _ = d;
    self.draw(layer, feat, col, line_width);
}
pub fn render_building(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Building) void {
    const default_col = color.from_hex(Tailwind.slate300);
    const col = color.convert_hex(d.colour) catch default_col;
    self.draw(layer, feat, col, 2.0);
}
pub fn render_housenumber(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Housenumber) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_landcover(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Landcover) void {
    const Keys = struct {
        pub const cyan100 = &.{"ice"};
        pub const zinc500 = &.{"rock"};
        pub const green500 = &.{"wood"};
        pub const lime300 = &.{"grass"};
        pub const yellow200 = &.{"sand"};
        pub const lime500 = &.{"farmland"};
        pub const lime700 = &.{"wetland"};
    };
    const col = color.ColorMap(Keys, Tailwind).map(d.class) orelse color.from_hex(Tailwind.green300);
    self.draw(layer, feat, col, 1.0);
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
/// not implemented because this draws points with text no poly / lines
pub fn render_place(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Place) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_poi(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Poi) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_transportation(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Transportation) void {
    const Keys = struct {
        pub const violet800 = &.{
            "motorway",
            "trunk",
            "motorway_construction",
            "trunk_construction",
        };
        pub const slate800 = &.{
            "primary",
            "secondary",
            "tertiary",
            "primary_construction",
            "secondary_construction",
            "tertiary_construction",
        };
        pub const gray700 = &.{
            "minor",
            "service",
            "minor_construction",
            "service_construction",
        };
        pub const stone400 = &.{
            "path",
            "track",
            "raceway",
            "path_construction",
            "track_construction",
            "raceway_construction",
            "bridge",
            "pier",
        };
        pub const rose800 = &.{
            "transit",
            "busway",
            "bus_guideway",
            "ferry",
        };
    };
    const Thickness = struct {
        pub const xxl = &.{
            "motorway",
            "trunk",
            "motorway_construction",
            "trunk_construction",
            "primary",
            "primary_construction",
        };
        pub const xl = &.{
            "secondary",
            "secondary_construction",
            "tertiary",
            "tertiary_construction",
            "ferry",
        };
        pub const l = &.{
            "minor",
            "service",
            "minor_construction",
            "service_construction",
            "transit",
            "busway",
            "bus_guideway",
            "bridge",
            "pier",
        };
        pub const m = &.{
            "path",
            "path_construction",
            "track",
            "track_construction",
            "raceway",
            "raceway_construction",
        };
    };
    const linewidth = Line.line_width(Thickness, d.class) orelse return self.log_any(d.class);
    const M = color.ColorMap(Keys, Tailwind);
    const col = M.map(d.class) orelse return self.log_any(d.class);
    self.draw(layer, feat, col, linewidth);
}
pub fn render_transportation_name(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Transportation_name) void {
    const Keys = struct {
        pub const violet800 = &.{
            "trunk",
            "motorway_construction",
            "trunk_construction",
        };
        pub const slate600 = &.{
            "primary",
            "primary_construction",
            "secondary",
            "secondary_construction",
            "tertiary",
            "tertiary_construction",
        };
        pub const gray500 = &.{
            "minor",
            "service",
            "minor_construction",
            "service_construction",
        };
        pub const stone500 = &.{
            "track",
            "track_construction",
        };
        pub const lime600 = &.{
            "path",
            "path_construction",
        };
        pub const orange700 = &.{
            "raceway",
            "raceway_construction",
        };
        pub const red700 = &.{
            "rail",
            "transit",
        };
    };
    const Thickness = struct {
        pub const xxl = &.{
            "trunk",
            "motorway_construction",
            "trunk_construction",
        };
        pub const xl = &.{
            "primary",
            "primary_construction",
            "secondary",
            "secondary_construction",
            "tertiary",
            "tertiary_construction",
        };
        pub const l = &.{
            "minor",
            "service",
            "minor_construction",
            "service_construction",

            "rail",
            "transit",
        };
        pub const m = &.{
            "track",
            "track_construction",
            "path",
            "path_construction",
            "raceway",
            "raceway_construction",
        };
    };
    // std.log.warn("{s} index: {}", .{ d.name, self.counter });
    const linewidth = Line.line_width(Thickness, d.class) orelse return self.log_any(d.*);
    const M = color.ColorMap(Keys, Tailwind);
    const col = M.map(d.class) orelse return self.log_any(d.*); //color.from_hex(Color.gray);
    self.draw(layer, feat, col, linewidth);
}
pub fn render_water(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Water) void {
    const Keys = struct {
        pub const sky300 = &.{"river"};
        pub const teal400 = &.{"pond"};
        pub const cyan500 = &.{ "dock", "swimming_pool" };
        pub const blue500 = &.{"lake"};
        pub const cyan800 = &.{"ocean"};
    };
    const col = color.ColorMap(Keys, Tailwind).map(d.class) orelse color.from_hex(Tailwind.blue500);
    self.draw(layer, feat, col, 2.0);
}
pub fn render_water_name(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Water_name) void {
    _ = .{ feat, self, d, layer };
}
pub fn render_waterway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Waterway) void {
    const Keys = struct {
        pub const teal400 = &.{"stream"};
        pub const blue500 = &.{"river"};
        pub const cyan800 = &.{"canal"};
        pub const teal950 = &.{ "drain", "ditch" };
    };
    const col = color.ColorMap(Keys, Tailwind).map(d.class) orelse color.from_hex(Tailwind.blue500);
    self.draw(layer, feat, col, 2.0);
}

fn make_traverser(config: RenderConfig) Traverser {
    return Traverser{
        .aeroway = if (config.toggle_aeroway) render_aeroway else null,
        .aerodrome_label = if (config.toggle_aerodrome_label) render_aerodrome_label else null,
        .boundary = if (config.toggle_boundary) render_boundary else null,
        .building = if (config.toggle_building) render_building else null,
        .housenumber = if (config.toggle_housenumber) render_housenumber else null,
        .landcover = if (config.toggle_landcover) render_landcover else null,
        .landuse = if (config.toggle_landuse) render_landuse else null,
        .mountain_peak = if (config.toggle_mountain_peak) render_mountain_peak else null,
        .park = if (config.toggle_park) render_park else null,
        .place = if (config.toggle_place) render_place else null,
        .poi = if (config.toggle_poi) render_poi else null,
        .transportation = if (config.toggle_transportation) render_transportation else null,
        .transportation_name = if (config.toggle_transportation_name) render_transportation_name else null,
        .water = if (config.toggle_water) render_water else null,
        .water_name = if (config.toggle_water_name) render_water_name else null,
        .waterway = if (config.toggle_waterway) render_waterway else null,
    };
}
pub fn render(self: *This, tile: *const dec.Tile, config: RenderConfig) void {
    if (self.context0 == null) self.set_context();
    const traverser = make_traverser(config);
    traverser.traverse_tile(tile, self);
}
test "test render all zoom" {
    if (true) return;
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();

    const render_list: []const []const u8 = &.{ "leipzig", "new_york" };
    inline for (render_list) |city| {
        inline for (14..15) |zoom| {
            const alloc = arena.allocator();
            const zoom_str = city ++ std.fmt.comptimePrint("_z{}", .{zoom});
            const tile_subpath = "./testdata/" ++ zoom_str;
            const output_subpath = "./output/" ++ zoom_str ++ ".png";
            std.log.warn("render: {s} to {s}", .{ tile_subpath, output_subpath });
            var file = try std.fs.cwd().openFile(tile_subpath, .{});
            const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
            const tile: dec.Tile = try dec.decode(input, alloc);
            const width_height = 1024;
            var rend = try This.init(alloc, width_height);
            for (0..width_height) |x| {
                for (0..width_height) |y| {
                    rend.surface0.putPixel(
                        @intCast(x),
                        @intCast(y),
                        z2d.Pixel{ .rgb = .{ .r = 255, .g = 255, .b = 255 } },
                    );
                }
            }
            rend.render(&tile, .StreetsAndBuildings);
            try z2d.png_exporter.writeToPNGFile(rend.surface0, output_subpath, .{});
            _ = arena.reset(.retain_capacity);
        }
    }
}

test "test render 1" {
    if (true) return;
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    var file = try std.fs.cwd().openFile("./testdata/leipzig_tile", .{});
    const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
    const tile: dec.Tile = try dec.decode(input, alloc);

    const width_height = 1024;
    var rend = try This.init(alloc, width_height);
    for (0..width_height) |x| {
        for (0..width_height) |y| {
            rend.surface0.putPixel(
                @intCast(x),
                @intCast(y),
                z2d.Pixel{ .rgb = .{ .r = 255, .g = 255, .b = 255 } },
            );
        }
    }
    rend.render(&tile, .StreetsAndBuildings);

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
    try z2d.png_exporter.writeToPNGFile(sfc, "./testdata/surface1.png", .{});
}
