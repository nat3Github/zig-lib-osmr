const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const dec = root.decoder;
const Layer = dec.Layer;

const This = @This();
const Traverser = dec.LayerTraverser(This);

alloc: Allocator,

pub fn init(alloc: Allocator) !This {
    return This{
        .alloc = alloc,
    };
}
pub fn deinit(self: *This) void {
    _ = self;
}

pub fn handle_aeroway(self: *This, layer: *const Layer, d: *const dec.Aeroway) void {
    _ = .{layer};
    std.log.warn("aeroways: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_aerodrome_label(self: *This, layer: *const Layer, d: *const dec.Aerodrome_label) void {
    _ = .{layer};
    std.log.warn("aerodromes: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_boundary(self: *This, layer: *const Layer, d: *const dec.Boundary) void {
    _ = .{layer};
    std.log.warn("boundaries: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_building(self: *This, layer: *const Layer, d: *const dec.Building) void {
    _ = .{layer};
    std.log.warn("buildings: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_housenumber(self: *This, layer: *const Layer, d: *const dec.Housenumber) void {
    _ = .{layer};
    std.log.warn("housenumbers: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_landcover(self: *This, layer: *const Layer, d: *const dec.Landcover) void {
    _ = .{layer};
    std.log.warn("landcover: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_landuse(self: *This, layer: *const Layer, d: *const dec.Landuse) void {
    _ = .{layer};
    std.log.warn("landuse: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_mountain_peak(self: *This, layer: *const Layer, d: *const dec.Mountain_peak) void {
    _ = .{layer};
    std.log.warn("mountain peaks: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_park(self: *This, layer: *const Layer, d: *const dec.Park) void {
    _ = .{layer};
    std.log.warn("parks: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_place(self: *This, layer: *const Layer, d: *const dec.Place) void {
    _ = .{layer};
    std.log.warn("place: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_poi(self: *This, layer: *const Layer, d: *const dec.Poi) void {
    _ = .{layer};
    std.log.warn("poi: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_transportation(self: *This, layer: *const Layer, d: *const dec.Transportation) void {
    _ = .{layer};
    std.log.warn("transportation: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_transportation_name(self: *This, layer: *const Layer, d: *const dec.Transportation_name) void {
    _ = .{layer};
    std.log.warn("transportation name: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_water(self: *This, layer: *const Layer, d: *const dec.Water) void {
    _ = .{layer};
    std.log.warn("water: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_water_name(self: *This, layer: *const Layer, d: *const dec.Water_name) void {
    _ = .{layer};
    std.log.warn("water name: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}
pub fn handle_waterway(self: *This, layer: *const Layer, d: *const dec.Waterway) void {
    _ = .{layer};
    std.log.warn("waterway: {s}", .{
        dec.print_any(d.*, self.alloc) catch "",
    });
}

pub fn render(self: *This, tile: *const dec.Tile) void {
    const traverser = Traverser{
        .aeroway = handle_aeroway,
        .aerodrome_label = handle_aerodrome_label,
        .boundary = handle_boundary,
        .building = handle_building,
        .housenumber = handle_housenumber,
        .landcover = handle_landcover,
        .landuse = handle_landuse,
        .mountain_peak = handle_mountain_peak,
        .park = handle_park,
        .place = handle_place,
        .poi = handle_poi,
        .transportation = handle_transportation,
        .transportation_name = handle_transportation_name,
        .water = handle_water,
        .water_name = handle_water_name,
        .waterway = handle_waterway,
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

    var rend = try This.init(alloc);
    defer rend.deinit();
    rend.render(&tile);
}
