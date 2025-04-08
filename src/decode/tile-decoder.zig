const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const protobuf = @import("protobuf");
pub const Tile = @import("vector_tile.pb.zig").Tile;
const Value = Tile.Value;
pub const Layer = Tile.Layer;
pub const Feature = Tile.Feature;

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
        fn handle_transportation(self: *This, layer: *const Layer, feat: *const Feature, d: *const Transportation) void {
            _ = .{ layer, feat, d, self };
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
                const field_rek = try print_any(@field(t, field.name), alloc);
                try slist.appendSlice(try aprint(alloc, "{s} :{} = {s}\n", .{
                    field.name,
                    field.type,
                    field_rek,
                }));
            }
        },
        .pointer => |p| {
            if (comptime p.size == .one) {
                try slist.appendSlice(try print_any(t.*, alloc));
            } else if (comptime p.is_const and p.child == u8) {
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
        aeroway: ?*const fn (*T, *const Layer, *const Feature, *const Aeroway) void = null,
        aerodrome_label: ?*const fn (*T, *const Layer, *const Feature, *const Aerodrome_label) void = null,
        boundary: ?*const fn (*T, *const Layer, *const Feature, *const Boundary) void = null,
        building: ?*const fn (*T, *const Layer, *const Feature, *const Building) void = null,
        housenumber: ?*const fn (*T, *const Layer, *const Feature, *const Housenumber) void = null,
        landcover: ?*const fn (*T, *const Layer, *const Feature, *const Landcover) void = null,
        landuse: ?*const fn (*T, *const Layer, *const Feature, *const Landuse) void = null,
        mountain_peak: ?*const fn (*T, *const Layer, *const Feature, *const Mountain_peak) void = null,
        park: ?*const fn (*T, *const Layer, *const Feature, *const Park) void = null,
        place: ?*const fn (*T, *const Layer, *const Feature, *const Place) void = null,
        poi: ?*const fn (*T, *const Layer, *const Feature, *const Poi) void = null,
        transportation: ?*const fn (*T, *const Layer, *const Feature, *const Transportation) void = null,
        transportation_name: ?*const fn (*T, *const Layer, *const Feature, *const Transportation_name) void = null,
        water: ?*const fn (*T, *const Layer, *const Feature, *const Water) void = null,
        water_name: ?*const fn (*T, *const Layer, *const Feature, *const Water_name) void = null,
        waterway: ?*const fn (*T, *const Layer, *const Feature, *const Waterway) void = null,

        pub fn traverse_tile(self: *const This, tile: *const Tile, t: *T) void {
            for (tile.layers.items) |layer| {
                const en = LayerEnum.init(&layer) catch continue;
                switch (en) {
                    .aeroway => {
                        if (self.aeroway) |cb| {
                            comptime_parse_struct(Aeroway, t, &layer, cb);
                        }
                    },
                    .aerodrome_label => {
                        if (self.aerodrome_label) |cb| {
                            comptime_parse_struct(Aerodrome_label, t, &layer, cb);
                        }
                    },
                    .boundary => {
                        if (self.boundary) |cb| {
                            comptime_parse_struct(Boundary, t, &layer, cb);
                        }
                    },
                    .building => {
                        if (self.building) |cb| {
                            comptime_parse_struct(Building, t, &layer, cb);
                        }
                    },
                    .housenumber => {
                        if (self.housenumber) |cb| {
                            comptime_parse_struct(Housenumber, t, &layer, cb);
                        }
                    },
                    .landcover => {
                        if (self.landcover) |cb| {
                            comptime_parse_struct(Landcover, t, &layer, cb);
                        }
                    },
                    .landuse => {
                        if (self.landuse) |cb| {
                            comptime_parse_struct(Landuse, t, &layer, cb);
                        }
                    },
                    .mountain_peak => {
                        if (self.mountain_peak) |cb| {
                            comptime_parse_struct(Mountain_peak, t, &layer, cb);
                        }
                    },
                    .park => {
                        if (self.park) |cb| {
                            comptime_parse_struct(Park, t, &layer, cb);
                        }
                    },
                    .place => {
                        if (self.place) |cb| {
                            comptime_parse_struct(Place, t, &layer, cb);
                        }
                    },
                    .poi => {
                        if (self.poi) |cb| {
                            comptime_parse_struct(Poi, t, &layer, cb);
                        }
                    },
                    .transportation => {
                        if (self.transportation) |cb| {
                            comptime_parse_struct(Transportation, t, &layer, cb);
                        }
                    },
                    .transportation_name => {
                        if (self.transportation_name) |cb| {
                            comptime_parse_struct(Transportation_name, t, &layer, cb);
                        }
                    },
                    .water => {
                        if (self.water) |cb| {
                            comptime_parse_struct(Water, t, &layer, cb);
                        }
                    },
                    .water_name => {
                        if (self.water_name) |cb| {
                            comptime_parse_struct(Water_name, t, &layer, cb);
                        }
                    },
                    .waterway => {
                        if (self.waterway) |cb| {
                            comptime_parse_struct(Waterway, t, &layer, cb);
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

pub fn comptime_parse_struct(T: type, tpointer: anytype, layer: *const Layer, callback: *const fn (@TypeOf(tpointer), *const Layer, *const Feature, *const T) void) void {
    const features: []Tile.Feature = layer.features.items;
    for (features) |feature| {
        var t = T{};
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
        callback(tpointer, layer, &feature, &t);
    }
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

pub const Cmd = enum {
    None,
    MoveTo,
    LineTo,
    ClosePath,

    fn op_param_count(cmd: *const Cmd) usize {
        return switch (cmd.*) {
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
        const a: i32 = @intCast(x >> 1);
        const b: i32 = @intCast(x & 1);
        return a ^ -b;
    }

    pub fn decode(
        geometry: []const u32,
        user_data: anytype,
        cb_close_path: *const fn (@TypeOf(user_data)) void,
        cb_move_to: *const fn (@TypeOf(user_data), i32, i32) void,
        cb_line_to: *const fn (@TypeOf(user_data), i32, i32) void,
    ) !void {
        var idx: usize = 0;
        while (true) {
            const cmdint = command_integer(geometry[idx]);
            idx += 1;
            const op_count = cmdint.cmd.op_param_count();
            switch (cmdint.cmd) {
                .None => return error.InvalidCommandId,
                .ClosePath => {
                    if (op_count != 0) return error.InvalidOpCount;
                    cb_close_path(user_data);
                },
                .MoveTo => {
                    const advance: usize = cmdint.count;
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
                    const advance: usize = cmdint.count;
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
            if (idx >= geometry.len) return;
        }
    }
};
test "cmd 2" {
    const x1 = Cmd.param_integer(20); // should give 10;
    const x2 = Cmd.param_integer(179); // should give -90;
    try expect(x1 == 10);
    try expect(x2 == -90);
}

const Debugger = struct {
    x: i32 = 0,
    y: i32 = 0,
    idx: usize = 0,
    buf: [100]i32 = undefined,
    result: []i32 = undefined,
    const XX = @This();
    fn print(self: *XX) void {
        self.buf[self.idx] = self.x;
        self.buf[self.idx + 1] = self.y;
        self.idx += 2;
    }
    fn close(self: *XX) void {
        // std.log.warn("close", .{});
        self.print();
        self.result = self.buf[0..self.idx];
    }
    fn move(self: *XX, x: i32, y: i32) void {
        self.x += x;
        self.y += y;
        self.print();
        // std.log.warn("move to x: {}, y: {}", .{ self.x, self.y });
    }
    fn line(self: *XX, x: i32, y: i32) void {
        self.x += x;
        self.y += y;
        self.print();
        // std.log.warn("line to x: {}, y: {}", .{ self.x, self.y });
    }
};
test "cmd 1" {
    const geometry: []const u32 = &.{
        9, // MoveTo 1 point
        20, // zigzag(10)
        20,
        26, // LineTo 3 points
        180, // zigzag(90)
        0, // zigzag(0)
        0, // zigzag(0)
        180, // zigzag(90)
        179, // zigzag(-90)
        0, // zigzag(0)
        7, // ClosePath
    };
    var xx = Debugger{};
    try Cmd.decode(
        geometry,
        &xx,
        Debugger.close,
        Debugger.move,
        Debugger.line,
    );
    const expected: []const i32 = &.{ 10, 10, 100, 10, 100, 100, 10, 100, 10, 100 };
    try expect(std.mem.eql(i32, expected, xx.result));
}

test "cmd 3" {
    // const geometry: []const u32 = &.{
    //     9,   5140, 3234, 66, 90,  27, 610, 101, 184, 41,  94, 33, 76, 33, 118, 77, 48,  61,  86,  193, 9,  1357, 522, 114,
    //     114, 71,   94,   23, 572, 79, 86,  19,  98,  29,  74, 31, 68, 37, 54,  39, 198, 185, 544, 751, 84, 73,   510, 403,
    //     74,  37,   110,  89, 9,   91, 3,   10,  91,  132,
    // };
    // var xx = Debugger{};
    // try Cmd.decode(
    //     geometry,
    //     &xx,
    //     Debugger.close,
    //     Debugger.move,
    //     Debugger.line,
    // );
    // const expected: []const i32 = &.{};
    // try expect(std.mem.eql(i32, expected, xx.result));
}
