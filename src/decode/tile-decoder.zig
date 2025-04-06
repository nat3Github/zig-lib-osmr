const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const protobuf = @import("protobuf");
pub const Tile = @import("vector_tile.pb.zig").Tile;
const Value = Tile.Value;
pub const Layer = Tile.Layer;

pub fn decode(input: []const u8, alloc: Allocator) !Tile {
    return try protobuf.pb_decode(Tile, input, alloc);
}

test "tile 1" {
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    var file = try std.fs.cwd().openFile("./testdata/leipzig_tile", .{});
    const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
    const tile: Tile = try protobuf.pb_decode(Tile, input, alloc);

    const XX = struct {
        const This = @This();
        alloc: Allocator,
        fn handle_transportation(self: *This, layer: *const Layer, d: *const Transportation) void {
            _ = .{layer};
            std.log.warn("transportation: {s}", .{
                print_any(d.*, self.alloc) catch "",
            });
        }
    };
    const XXTraverser = LayerTraverser(XX);
    const traverser = XXTraverser{
        .transportation = XX.handle_transportation,
    };
    var xx = XX{
        .alloc = alloc,
    };
    traverser.traverse_tile(&tile, &xx);
}

pub fn print_any(t: anytype, alloc: Allocator) ![]const u8 {
    var slist = std.ArrayList(u8).init(alloc);
    const aprint = std.fmt.allocPrint;
    const T = @TypeOf(t);
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            try slist.appendSlice(try aprint(alloc, "struct {}\n", .{T}));
            inline for (s.fields) |field| {
                try slist.appendSlice(try aprint(alloc, "{s} :{} = {s}\n", .{
                    field.name,
                    field.type,
                    try print_any(@field(t, field.name), alloc),
                }));
            }
        },
        .pointer => |p| {
            if (p.is_const and p.child == u8) {
                try slist.appendSlice(try aprint(alloc, "{s}", .{t}));
            } else {
                try slist.appendSlice(try aprint(alloc, "{any}\n", .{t}));
            }
        },
        else => {
            try slist.appendSlice(try aprint(alloc, "{any}\n", .{t}));
        },
    }
    return slist.items;
}
pub fn LayerTraverser(T: type) type {
    return struct {
        const This = @This();
        aeroway: ?*const fn (*T, *const Layer, *const Aeroway) void = null,
        aerodrome_label: ?*const fn (*T, *const Layer, *const Aerodrome_label) void = null,
        boundary: ?*const fn (*T, *const Layer, *const Boundary) void = null,
        building: ?*const fn (*T, *const Layer, *const Building) void = null,
        housenumber: ?*const fn (*T, *const Layer, *const Housenumber) void = null,
        landcover: ?*const fn (*T, *const Layer, *const Landcover) void = null,
        landuse: ?*const fn (*T, *const Layer, *const Landuse) void = null,
        mountain_peak: ?*const fn (*T, *const Layer, *const Mountain_peak) void = null,
        park: ?*const fn (*T, *const Layer, *const Park) void = null,
        place: ?*const fn (*T, *const Layer, *const Place) void = null,
        poi: ?*const fn (*T, *const Layer, *const Poi) void = null,
        transportation: ?*const fn (*T, *const Layer, *const Transportation) void = null,
        transportation_name: ?*const fn (*T, *const Layer, *const Transportation_name) void = null,
        water: ?*const fn (*T, *const Layer, *const Water) void = null,
        water_name: ?*const fn (*T, *const Layer, *const Water_name) void = null,
        waterway: ?*const fn (*T, *const Layer, *const Waterway) void = null,

        pub fn traverse_tile(self: *const This, tile: *const Tile, t: *T) void {
            for (tile.layers.items) |layer| {
                const en = LayerEnum.init(&layer) catch continue;
                switch (en) {
                    .aeroway => {
                        if (self.aeroway) |function| {
                            const parsed_struct = comptime_parse_struct(Aeroway, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .aerodrome_label => {
                        if (self.aerodrome_label) |function| {
                            const parsed_struct = comptime_parse_struct(Aerodrome_label, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .boundary => {
                        if (self.boundary) |function| {
                            const parsed_struct = comptime_parse_struct(Boundary, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .building => {
                        if (self.building) |function| {
                            const parsed_struct = comptime_parse_struct(Building, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .housenumber => {
                        if (self.housenumber) |function| {
                            const parsed_struct = comptime_parse_struct(Housenumber, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .landcover => {
                        if (self.landcover) |function| {
                            const parsed_struct = comptime_parse_struct(Landcover, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .landuse => {
                        if (self.landuse) |function| {
                            const parsed_struct = comptime_parse_struct(Landuse, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .mountain_peak => {
                        if (self.mountain_peak) |function| {
                            const parsed_struct = comptime_parse_struct(Mountain_peak, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .park => {
                        if (self.park) |function| {
                            const parsed_struct = comptime_parse_struct(Park, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .place => {
                        if (self.place) |function| {
                            const parsed_struct = comptime_parse_struct(Place, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .poi => {
                        if (self.poi) |function| {
                            const parsed_struct = comptime_parse_struct(Poi, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .transportation => {
                        if (self.transportation) |function| {
                            const parsed_struct = comptime_parse_struct(Transportation, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .transportation_name => {
                        if (self.transportation_name) |function| {
                            const parsed_struct = comptime_parse_struct(Transportation_name, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .water => {
                        if (self.water) |function| {
                            const parsed_struct = comptime_parse_struct(Water, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .water_name => {
                        if (self.water_name) |function| {
                            const parsed_struct = comptime_parse_struct(Water_name, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                    .waterway => {
                        if (self.waterway) |function| {
                            const parsed_struct = comptime_parse_struct(Waterway, &layer);
                            function(t, &layer, &parsed_struct);
                        }
                    },
                }
            }
        }
    };
}

const KViterator = struct {
    const This = @This();
    counter: usize = 0,
    layer: *const Layer,
    feature: *const Tile.Feature,

    pub fn init(layer: *const Layer, feature: *const Tile.Feature) This {
        return This{
            .layer = layer,
            .feature = feature,
        };
    }
    pub inline fn next(self: *This) ?struct {
        key: []const u8,
        val: Value,
    } {
        const tags = self.feature.tags.items;
        if (self.counter >= tags.len / 2) return null;
        const tag = tags[self.counter * 2 .. self.counter * 2 + 2];
        self.counter += 1;
        const keys: []protobuf.ManagedString = self.layer.keys.items;
        const values: []Value = self.layer.values.items;
        const key = keys[tag[0]].getSlice();
        const val = values[tag[1]];
        return .{
            .key = key,
            .val = val,
        };
    }
};

pub const MetaData = @This();

const StringU8 = []const u8;
pub const Aeroway = struct {
    class: StringU8 = "",
    ref: StringU8 = "",
};
pub const Aerodrome_label = struct {
    class: StringU8 = "",
    name: StringU8 = "",
    icao: Value = Value{},
    ele: ?i64 = null, // elevation in meters
};
pub const Boundary = struct {
    class: StringU8 = "",
    name: StringU8 = "",
    admin_level: ?i64 = null,
    maritime: ?i64 = null,
};
pub const Building = struct {
    render_height: ?i64 = null,
    render_min_height: ?i64 = null,
    colour: StringU8 = "",
    hide_3d: ?bool = null,
};
pub const Housenumber = struct {
    housenumber: StringU8 = "",
};
pub const Landcover = struct {
    class: StringU8 = "",
    subclass: StringU8 = "",
};
pub const Landuse = struct {
    class: StringU8 = "",
};
pub const Mountain_peak = struct {
    name: StringU8 = "",
    class: StringU8 = "",
    ele: ?i64 = null,
    rank: ?i64 = null,
};
pub const Park = struct {
    name: StringU8 = "",
    class: StringU8 = "",
    rank: ?i64 = null,
};
pub const Place = struct {
    name: StringU8 = "",
    class: StringU8 = "",
    rank: ?i64 = null,
};
pub const Poi = struct {
    name: StringU8 = "",
    class: StringU8 = "",
    subclass: StringU8 = "",
    rank: ?i64 = null,
};
pub const Transportation = struct {
    class: StringU8 = "",
    subclass: StringU8 = "",
    brunnel: ?Brunnel = null,
};
pub const Transportation_name = struct {
    name: StringU8 = "",
    ref: StringU8 = "",
    class: StringU8 = "",
    subclass: StringU8 = "",
    brunnel: ?Brunnel = null,
};
pub const Water = struct {
    class: StringU8 = "",
    brunnel: ?Brunnel = null,
    intermittent: ?bool = null,
};
pub const Water_name = struct {
    name: StringU8 = "",
    class: StringU8 = "",
    intermittent: ?bool = null,
};
pub const Waterway = struct {
    name: StringU8 = "",
    class: StringU8 = "",
    brunnel: ?Brunnel = null,
    intermittent: ?bool = null,
};

const Brunnel = enum {
    bridge,
    tunnel,
    ford,
};

fn comptime_parse_struct(T: type, layer: *const Layer) T {
    var t = T{};
    const features: []Tile.Feature = layer.features.items;
    for (features) |feature| {
        var it = KViterator.init(layer, &feature);
        while (it.next()) |kv| {
            const fields = @typeInfo(T).@"struct".fields;
            inline for (fields) |field| {
                if (std.mem.eql(u8, field.name, kv.key)) {
                    const fref = &@field(t, field.name);
                    switch (field.type) {
                        Value => {
                            fref.* = kv.val;
                        },
                        StringU8 => {
                            if (kv.val.string_value) |v| {
                                fref.* = v.getSlice();
                            }
                        },
                        ?bool => {
                            if (kv.val.bool_value) |v| {
                                fref.* = v;
                            }
                        },
                        ?Brunnel => {
                            if (kv.val.string_value) |v| {
                                const brstr = v.getSlice();
                                if (std.mem.eql(u8, "bridge", brstr)) {
                                    fref.* = .bridge;
                                }
                                if (std.mem.eql(u8, "tunnel", brstr)) {
                                    fref.* = .tunnel;
                                }
                                if (std.mem.eql(u8, "ford", brstr)) {
                                    fref.* = .ford;
                                }
                            }
                        },
                        ?i64 => {
                            if (kv.val.uint_value) |v| {
                                fref.* = std.math.cast(i64, v);
                            }
                            if (kv.val.int_value) |v| {
                                fref.* = v;
                            }
                            if (kv.val.sint_value) |v| {
                                fref.* = v;
                            }
                        },
                        else => unreachable,
                    }
                }
            }
        }
    }
    return t;
}

/// NOTE: the definition follows the OpenMapTiles Schema (CC-BY) https://openmaptiles.org/schema/
/// MapTiler is based on the OpenMapTiles Schema
pub const LayerDef = struct {
    const aeroway = "aeroway";
    const aerodrome_label = "aerodrome_label";
    const boundary = "boundary";
    const building = "building";
    const housenumber = "housenumber";
    const landcover = "landcover";
    const landuse = "landuse";
    const mountain_peak = "mountain_peak";
    const park = "park";
    const place = "place";
    const poi = "poi";
    const transportation = "transportation";
    const transportation_name = "transportation_name";
    const water = "water";
    const water_name = "water_name";
    const waterway = "waterway";
};

const LayerEnum = enum {
    aeroway,
    aerodrome_label,
    boundary,
    building,
    housenumber,
    landcover,
    landuse,
    mountain_peak,
    park,
    place,
    poi,
    transportation,
    transportation_name,
    water,
    water_name,
    waterway,

    pub fn init(layer: *const Layer) !LayerEnum {
        const s = layer.name.getSlice();
        const eql = std.mem.eql;
        if (eql(u8, "aeroway", s)) {
            return .aeroway;
        }
        if (eql(u8, "aerodrome_label", s)) {
            return .aerodrome_label;
        }
        if (eql(u8, "boundary", s)) {
            return .boundary;
        }
        if (eql(u8, "building", s)) {
            return .building;
        }
        if (eql(u8, "housenumber", s)) {
            return .housenumber;
        }
        if (eql(u8, "landcover", s)) {
            return .landcover;
        }
        if (eql(u8, "landuse", s)) {
            return .landuse;
        }
        if (eql(u8, "mountain_peak", s)) {
            return .mountain_peak;
        }
        if (eql(u8, "park", s)) {
            return .park;
        }
        if (eql(u8, "place", s)) {
            return .place;
        }
        if (eql(u8, "poi", s)) {
            return .poi;
        }
        if (eql(u8, "transportation", s)) {
            return .transportation;
        }
        if (eql(u8, "transportation_name", s)) {
            return .transportation_name;
        }
        if (eql(u8, "water", s)) {
            return .water;
        }
        if (eql(u8, "water_name", s)) {
            return .water_name;
        }
        if (eql(u8, "waterway", s)) {
            return .waterway;
        }
        return error.InvalidLayerFormat;
    }
    pub fn struct_type(self: *const LayerEnum) type {
        return switch (self.*) {
            .aeroway => Aeroway,
            .aerodrome_label => Aerodrome_label,
            .boundary => Boundary,
            .building => Building,
            .housenumber => Housenumber,
            .landcover => Landcover,
            .landuse => Landuse,
            .mountain_peak => Mountain_peak,
            .park => Park,
            .place => Place,
            .poi => Poi,
            .transportation => Transportation,
            .transportation_name => Transportation_name,
            .water => Water,
            .water_name => Water_name,
            .waterway => Waterway,
        };
    }
};
