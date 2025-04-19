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
const Color = root.Color;

// tailwind colors
const Tailwind = @import("tailwind");
const Line = root.thickness;
const WRender = @import("wrender.zig").WRender2;

alloc: Allocator,
arena: std.heap.ArenaAllocator,
surface0: z2d.Surface,
context0: ?z2d.Context = null,
counter: usize = 0,

const padding_pixels = 16;

pub fn init(alloc: Allocator, width_height: u32) !This {
    const w = width_height + padding_pixels * 2;
    return This{
        .alloc = alloc,
        .arena = std.heap.ArenaAllocator.init(alloc),
        .surface0 = try z2d.Surface.init(
            .image_surface_rgba,
            alloc,
            @intCast(w),
            @intCast(w),
        ),
    };
}

pub fn deinit(self: *This) void {
    const alloc = self.alloc;
    self.surface0.deinit(alloc);
    if (self.context0 != null) {
        self.arena.deinit();
    }
}
pub fn set_background(self: *This, pixel: Color) void {
    const width_height: usize = @intCast(self.surface0.getWidth());
    const r, const g, const b, const a = pixel.rgba();
    for (0..width_height) |x| {
        for (0..width_height) |y| {
            self.surface0.putPixel(
                @intCast(x),
                @intCast(y),
                z2d.Pixel{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } },
            );
        }
    }
}

inline fn swallow_error(res: anyerror!void) void {
    _ = res catch |e| std.log.err("error: {}", .{e});
}

inline fn draw(self: *This, layer: *const Layer, feat: *const Feature, col: Color, line_width: f64, dotted: bool) void {
    assert(self.context0 != null);
    if (self.context0) |*context| {
        swallow_error(context.moveTo(0, 0));
        context.resetPath();
        const extent = get_extent(layer);
        const geomtype = feat.type orelse .UNKNOWN;
        const geo = feat.geometry.items;
        var ren = WRender{ .ctx = context, .extent = @floatFromInt(extent), .padding_pixels = padding_pixels };
        if (dotted) {
            context.setDashes(&.{ 10, 7 });
        } else context.setDashes(&.{});

        switch (geomtype) {
            .POINT => std.log.debug("point drawing not implemented", .{}),
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
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    const s = dec.print_any_leaky(t, alloc) catch |e| {
        std.log.err("failed to print log because of {}", .{e});
        return;
    };
    std.log.warn("{s}", .{s});
}

pub fn draw_aeroway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aeroway) void {
    const Keys = struct {
        pub const sky100 = &.{"aerodrome"};
        pub const neutral300 = &.{ "runway", "taxiway" };
        pub const yellow100 = &.{"apron"};
        pub const orange400 = &.{"gate"};
        pub const amber300 = &.{ "heliport", "helipad" };
    };
    const col = Color.ColorMap(Keys, Tailwind).map(d.class) orelse Color.from_hex(Tailwind.neutral400);
    self.draw(layer, feat, col, 1.0, false);
}
pub fn draw_aerodrome_label(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Aerodrome_label) void {
    _ = .{ feat, self, d, layer };
}
pub fn draw_boundary(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Boundary) void {
    var col = Color.from_hex(Tailwind.zinc300);
    const line_width: f64 = Line.StandardSizes.M;
    var dashed = false;
    if (d.admin_level) |admin_level| {
        if (d.maritime) |m| {
            if (m == 1) {
                dashed = true;
                if (admin_level <= 2) {
                    col = Color.from_hex(Tailwind.indigo300);
                } else if (admin_level <= 4) {
                    col = Color.from_hex(Tailwind.blue300);
                }
            } else {
                if (admin_level <= 2) {
                    col = Color.from_hex(Tailwind.stone400);
                } else if (admin_level <= 4) {
                    col = Color.from_hex(Tailwind.orange200);
                }
            }
        }
    }
    self.draw(layer, feat, col, line_width, dashed);
}
pub fn draw_building(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Building) void {
    const default_col = Color.from_hex(Tailwind.stone300);
    const col = Color.convert_hex(d.colour) catch default_col;
    self.draw(layer, feat, col, 2.0, false);
}
pub fn draw_housenumber(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Housenumber) void {
    _ = .{ feat, self, d, layer };
}
pub fn draw_landcover(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Landcover) void {
    const Keys = struct {
        pub const cyan100 = &.{"ice"};
        pub const zinc500 = &.{"rock"};
        pub const green300 = &.{"wood"};
        pub const lime200 = &.{"grass"};
        pub const yellow200 = &.{"sand"};
        pub const green200 = &.{"farmland"};
        pub const orange200 = &.{"wetland"};
    };
    const col = Color.ColorMap(Keys, Tailwind).map(d.class) orelse Color.from_hex(Tailwind.green300);
    self.draw(layer, feat, col, 1.0, false);
}

pub fn draw_landuse(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Landuse) void {
    const t = feat.type orelse return;
    switch (t) {
        .POLYGON, .LINESTRING => {
            const Keys = struct {
                pub const red200 = &.{
                    "railway",
                };
                pub const slate300 = &.{
                    "cemetery",
                    "quarry",
                };
                pub const emerald500 = &.{
                    "military",
                    "dam",
                };
                pub const amber100 = &.{
                    "residential",
                    "suburb",
                    "quarter",
                    "neighbourhood",
                };
                pub const yellow200 = &.{
                    "commercial",
                    "industrial",
                    "retail",
                };
                pub const zinc200 = &.{
                    "garages",
                    "pitch",
                    "track",
                };
                pub const fuchsia200 = &.{
                    "stadium",
                    "playground",
                    "theme_park",
                    "zoo",
                };

                pub const pink200 = &.{
                    "hospital",
                };

                pub const green200 = &.{
                    "kindergarten",
                    "school",
                    "university",
                    "college",
                    "library",
                };

                pub const orange300 = &.{
                    "bus_station",
                };
            };

            const col = Color.ColorMap(Keys, Tailwind).map(d.class) orelse return self.log_any(d.*);
            //color.from_hex(Tailwind.blue500);

            self.draw(layer, feat, col, 2.0, false);
        },
        else => return,
    }
}
pub fn draw_mountain_peak(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Mountain_peak) void {
    const t = feat.type orelse return;
    switch (t) {
        .POLYGON, .LINESTRING => {
            self.log_any(d.*);
        },
        else => return,
    }
    _ = .{layer};
}
pub fn draw_park(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Park) void {
    const t = feat.type orelse return;
    switch (t) {
        .POLYGON, .LINESTRING => {
            self.draw(layer, feat, .from_hex(Tailwind.green300), 3.0, false);
            // self.log_any(d.*);
            _ = d;
        },
        else => return,
    }
    _ = .{layer};
}
/// not implemented because this draws points with text no poly / lines
pub fn draw_place(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Place) void {
    const t = feat.type orelse return;
    switch (t) {
        .POLYGON, .LINESTRING => {
            self.log_any(d.*);
        },
        else => return,
    }
    _ = .{layer};
}
pub fn draw_poi(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Poi) void {
    const t = feat.type orelse return;
    switch (t) {
        .POLYGON, .LINESTRING => {
            self.log_any(d.*);
        },
        else => return,
    }
    _ = .{layer};
}
fn draw_transport(self: *This, layer: *const Layer, feat: *const Feature, key: []const u8) void {
    const Keys = struct {
        pub const purple300 = &.{
            "motorway",
            "trunk",
            "motorway_construction",
            "trunk_construction",
        };
        pub const slate400 = &.{
            "primary",
            "secondary",
            "tertiary",
            "primary_construction",
            "secondary_construction",
            "tertiary_construction",
        };
        pub const gray400 = &.{
            "minor",
            "service",
            "minor_construction",
            "service_construction",
        };
        pub const stone400 = &.{
            "track",
            "track_construction",
            "path",
            "path_construction",
        };
        pub const red300 = &.{
            "raceway",
            "raceway_construction",
        };
        pub const neutral500 = &.{
            "bridge",
            "pier",
        };
        pub const rose400 = &.{
            "rail",
        };
        pub const sky300 = &.{
            "ferry",
        };
        pub const orange300 = &.{
            "busway",
            "bus_guideway",
        };
        pub const rose300 = &.{
            "transit",
        };
    };
    const Thickness = struct {
        // pub const xl = &.{};
        // pub const l = &.{};
        pub const m = &.{
            "motorway",
            "trunk",
            "motorway_construction",
            "trunk_construction",

            "primary",
            "primary_construction",

            "secondary",
            "secondary_construction",

            "bridge",
            "pier",
            "rail",
            "ferry",
            "transit",
            "busway",
            "bus_guideway",
            "tertiary",
            "tertiary_construction",
            "minor",
            "service",
            "minor_construction",
            "service_construction",
        };
        pub const s = &.{
            "path",
            "path_construction",
            "track",
            "track_construction",
            "raceway",
            "raceway_construction",
        };
    };
    const linewidth = Line.line_width(Thickness, key) orelse return self.log_any(key);
    // _ = Thickness;
    // const linewidth = Line.StandardSizes.M;
    const M = Color.ColorMap(Keys, Tailwind);
    const col = M.map(key) orelse return self.log_any(key);
    self.draw(layer, feat, col, linewidth, false);
}

pub fn draw_transportation(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Transportation) void {
    self.draw_transport(layer, feat, d.class);
}
pub fn draw_transportation_name(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Transportation_name) void {
    self.draw_transport(layer, feat, d.class);
}
inline fn water_layer(self: *This, layer: *const Layer, feat: *const Feature, d: []const u8) void {
    const Keys = struct {
        pub const sky300 = &.{"river"};
        pub const teal300 = &.{"pond"};
        pub const cyan400 = &.{ "dock", "swimming_pool" };
        pub const blue300 = &.{"lake"};
        pub const teal400 = &.{"ocean"};
    };
    const col = Color.ColorMap(Keys, Tailwind).map(d) orelse Color.from_hex(Tailwind.blue500);
    self.draw(layer, feat, col, 2.0, false);
}
pub fn draw_water(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Water) void {
    self.water_layer(layer, feat, d.class);
}
pub fn layer_water_name(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Water_name) void {
    const t = feat.type orelse return;
    switch (t) {
        .POLYGON, .LINESTRING => {
            self.water_layer(layer, feat, d.class);
        },
        else => return,
    }
}
pub fn draw_waterway(self: *This, layer: *const Layer, feat: *const Feature, d: *const dec.Waterway) void {
    const Keys = struct {
        pub const teal400 = &.{"stream"};
        pub const blue500 = &.{"river"};
        pub const cyan700 = &.{"canal"};
        pub const teal800 = &.{ "drain", "ditch" };
    };
    const col = Color.ColorMap(Keys, Tailwind).map(d.class) orelse Color.from_hex(Tailwind.blue500);
    self.draw(layer, feat, col, 2.0, true);
}

fn set_context(self: *This) void {
    if (self.context0 != null) {
        _ = self.arena.reset(.retain_capacity);
        self.context0 = null;
    }
    const alloc = self.arena.allocator();
    self.context0 = z2d.Context.init(alloc, &self.surface0);
}
pub fn render_basic(self: *This, tile: *const dec.Tile) !void {
    self.set_context();
    self.context0.?.anti_aliasing_mode = .none;
    self.set_background(.from_hex(Tailwind.lime100));
    const RenderAll = struct {
        landuse: *const fn (*This, *const Layer, *const Feature, *const dec.Landuse) void = draw_landuse,
        park: *const fn (*This, *const Layer, *const Feature, *const dec.Park) void = draw_park,
        place: *const fn (*This, *const Layer, *const Feature, *const dec.Place) void = draw_place,
        landcover: *const fn (*This, *const Layer, *const Feature, *const dec.Landcover) void = draw_landcover,

        water: *const fn (*This, *const Layer, *const Feature, *const dec.Water) void = draw_water,
        water_name: *const fn (*This, *const Layer, *const Feature, *const dec.Water_name) void = layer_water_name,

        aeroway: *const fn (*This, *const Layer, *const Feature, *const dec.Aeroway) void = draw_aeroway,
        aerodrome_label: *const fn (*This, *const Layer, *const Feature, *const dec.Aerodrome_label) void = draw_aerodrome_label,
        boundary: *const fn (*This, *const Layer, *const Feature, *const dec.Boundary) void = draw_boundary,
    };
    try dec.traverse_tile(This, self, tile, RenderAll{});
}
pub fn render_lines(self: *This, tile: *const dec.Tile) !void {
    self.set_context();
    self.context0.?.anti_aliasing_mode = .none;
    self.set_background(.transparent);
    const RenderAll = struct {
        waterway: *const fn (*This, *const Layer, *const Feature, *const dec.Waterway) void = draw_waterway,
        transportation: *const fn (*This, *const Layer, *const Feature, *const dec.Transportation) void = draw_transportation,
        // transportation_name: *const fn (*This, *const Layer, *const Feature, *const dec.Transportation_name) void = draw_transportation_name,
        // boundary: *const fn (*This, *const Layer, *const Feature, *const dec.Boundary) void = draw_boundary,
        building: *const fn (*This, *const Layer, *const Feature, *const dec.Building) void = draw_building,
    };
    try dec.traverse_tile(This, self, tile, RenderAll{});
}

pub fn render(self: *This, tile: *const dec.Tile) !void {
    self.set_context();
    const RenderAll = struct {
        landuse: *const fn (*This, *const Layer, *const Feature, *const dec.Landuse) void = draw_landuse,

        park: *const fn (*This, *const Layer, *const Feature, *const dec.Park) void = draw_park,
        place: *const fn (*This, *const Layer, *const Feature, *const dec.Place) void = draw_place,
        landcover: *const fn (*This, *const Layer, *const Feature, *const dec.Landcover) void = draw_landcover,

        water: *const fn (*This, *const Layer, *const Feature, *const dec.Water) void = draw_water,
        water_name: *const fn (*This, *const Layer, *const Feature, *const dec.Water_name) void = layer_water_name,
        waterway: *const fn (*This, *const Layer, *const Feature, *const dec.Waterway) void = draw_waterway,

        aeroway: *const fn (*This, *const Layer, *const Feature, *const dec.Aeroway) void = draw_aeroway,
        aerodrome_label: *const fn (*This, *const Layer, *const Feature, *const dec.Aerodrome_label) void = draw_aerodrome_label,

        transportation: *const fn (*This, *const Layer, *const Feature, *const dec.Transportation) void = draw_transportation,
        transportation_name: *const fn (*This, *const Layer, *const Feature, *const dec.Transportation_name) void = draw_transportation_name,

        boundary: *const fn (*This, *const Layer, *const Feature, *const dec.Boundary) void = draw_boundary,

        // mountain_peak: *const fn (*This, *const Layer, *const Feature, *const dec.Mountain_peak) void = render_mountain_peak,
        building: *const fn (*This, *const Layer, *const Feature, *const dec.Building) void = draw_building,
        // poi: *const fn (*This, *const Layer, *const Feature, *const dec.Poi) void = render_poi,
        // housenumber: *const fn (*This, *const Layer, *const Feature, *const dec.Housenumber) void = render_housenumber,
    };
    try dec.traverse_tile(This, self, tile, RenderAll{});
}

pub fn get_pixel_rgba(self: *@This(), x: usize, y: usize) struct { u8, u8, u8, u8 } {
    const px = self.surface0.getPixel(@intCast(x + padding_pixels), @intCast(y + padding_pixels)).?.rgba;
    return .{ px.r, px.g, px.b, px.a };
}

fn leipzig_new_york_rendering(comptime zoom_level: struct { comptime_int, comptime_int }) !void {
    const gpa = std.testing.allocator;
    const width_height = 1024;
    var rend = try This.init(gpa, width_height);
    defer rend.deinit();
    const render_list: []const []const u8 = &.{
        "leipzig",
        "new_york",
    };
    inline for (render_list) |city| {
        inline for (zoom_level[0]..zoom_level[1]) |zoom| {
            var arena = std.heap.ArenaAllocator.init(gpa);
            defer arena.deinit();
            const alloc = arena.allocator();
            const zoom_str = city ++ std.fmt.comptimePrint("_z{}", .{zoom});
            const tile_subpath = "./testdata/" ++ zoom_str;
            const output_subpath = "./output/" ++ zoom_str ++ ".png";
            std.log.warn("render: {s} to {s}", .{ tile_subpath, output_subpath });
            var file = try std.fs.cwd().openFile(tile_subpath, .{});
            const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
            const tile: dec.Tile = try dec.decode(input, alloc);
            try rend.render(&tile);
            try z2d.png_exporter.writeToPNGFile(rend.surface0, output_subpath, .{});
        }
    }
}
fn test_render_all_zoom() !void {
    if (false) return;
    const gpa = std.testing.allocator;

    const h1 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 0, 2 }});
    const h2 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 2, 4 }});
    const h3 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 4, 6 }});
    const h4 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 6, 8 }});
    const h5 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 8, 10 }});
    const h6 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 10, 12 }});
    const h7 = try std.Thread.spawn(.{ .allocator = gpa }, leipzig_new_york_rendering, .{.{ 12, 14 }});
    try leipzig_new_york_rendering(.{ 14, 16 });
    h1.join();
    h2.join();
    h3.join();
    h4.join();
    h5.join();
    h6.join();
    h7.join();
}

fn test_render_1() !void {
    if (false) return;
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
    try rend.render_lines(&tile);
    try z2d.png_exporter.writeToPNGFile(rend.surface0, "./testdata/surface0.png", .{});
}

fn test_render_0() !void {
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

fn test_error_repro_z2d() !void {
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    const width_height = 300;

    var surface0 = try z2d.Surface.init(
        .image_surface_rgb,
        alloc,
        @intCast(width_height),
        @intCast(width_height),
    );
    var context0 = z2d.Context.init(alloc, &surface0);
    context0.setSourceToPixel(.{ .rgb = .{ .r = 255, .b = 0, .g = 0 } });
    try context0.lineTo(-12000, -10);
    try context0.lineTo(10, 100);
    try context0.lineTo(-910, 12000);
    try context0.lineTo(10, 100);
    try context0.stroke();

    try z2d.png_exporter.writeToPNGFile(surface0, "./testdata/surfaceX.png", .{});
}

test "test kkk" {
    // try test_render_all_zoom();
    // try test_render_1();
    // try test_error_repro_z2d();
    try test_failing();
}

fn test_failing() !void {
    if (false) return;
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    var file = try std.fs.cwd().openFile("./testdata/failing_x136_y85_z8", .{});
    const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
    const tile: dec.Tile = try dec.decode(input, alloc);

    // warning: x: 136, y: 84, z: 8 from cache
    // warning: x: 136, y: 85, z: 8 from cache
    // warning: x: 137, y: 84, z: 8 from cache
    // warning: x: 137, y: 85, z: 8 from cache
    // const img_width = 1920;
    const width_height = 300;
    // const width_height = 1024;
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
    try rend.render_lines(&tile);
    try z2d.png_exporter.writeToPNGFile(rend.surface0, "./testdata/failing.png", .{});
}
