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
    const parsed = try parse_tile(alloc, &tile);
    _ = parsed;
    // std.log.warn("{s}", .{try print_any_leaky(parsed, alloc)});
}

pub fn print_any_leaky(t: anytype, alloc: Allocator) ![]const u8 {
    var slist = std.ArrayList(u8).init(alloc);
    const aprint = std.fmt.allocPrint;
    const T = @TypeOf(t);
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            try slist.appendSlice(try aprint(alloc, "struct {}\n", .{T}));
            inline for (s.fields) |field| {
                const field_rek = try print_any_leaky(@field(t, field.name), alloc);
                try slist.appendSlice(try aprint(alloc, "{s} :{} = {s}\n", .{
                    field.name,
                    field.type,
                    field_rek,
                }));
            }
        },
        .pointer => |p| {
            if (comptime p.size == .one) {
                try slist.appendSlice(try print_any_leaky(t.*, alloc));
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
pub const LayerNames = &.{
    "aeroway",
    "aerodrome_label",
    "boundary",
    "building",
    "housenumber",
    "landcover",
    "landuse",
    "mountain_peak",
    "park",
    "place",
    "poi",
    "transportation",
    "transportation_name",
    "water",
    "water_name",
    "waterway",
};
/// NOTE: the definition follows the OpenMapTiles Schema (CC-BY) https://openmaptiles.org/schema/
/// MapTiler is based on the OpenMapTiles Schema
const LayerSchema = struct {
    pub const aeroway: void = undefined;
    pub const aerodrome_label: void = undefined;
    pub const boundary: void = undefined;
    pub const building: void = undefined;
    pub const housenumber: void = undefined;
    pub const landcover: void = undefined;
    pub const landuse: void = undefined;
    pub const mountain_peak: void = undefined;
    pub const park: void = undefined;
    pub const place: void = undefined;
    pub const poi: void = undefined;
    pub const transportation: void = undefined;
    pub const transportation_name: void = undefined;
    pub const water: void = undefined;
    pub const water_name: void = undefined;
    pub const waterway: void = undefined;
};

pub const LayerData = struct {
    aeroway: []const LayerParsed(ParseMeta.aeroway) = undefined,
    aerodrome_label: []const LayerParsed(ParseMeta.aerodrome_label) = undefined,
    boundary: []const LayerParsed(ParseMeta.boundary) = undefined,
    building: []const LayerParsed(ParseMeta.building) = undefined,
    housenumber: []const LayerParsed(ParseMeta.housenumber) = undefined,
    landcover: []const LayerParsed(ParseMeta.landcover) = undefined,
    landuse: []const LayerParsed(ParseMeta.landuse) = undefined,
    mountain_peak: []const LayerParsed(ParseMeta.mountain_peak) = undefined,
    park: []const LayerParsed(ParseMeta.park) = undefined,
    place: []const LayerParsed(ParseMeta.place) = undefined,
    poi: []const LayerParsed(ParseMeta.poi) = undefined,
    transportation: []const LayerParsed(ParseMeta.transportation) = undefined,
    transportation_name: []const LayerParsed(ParseMeta.transportation_name) = undefined,
    water: []const LayerParsed(ParseMeta.water) = undefined,
    water_name: []const LayerParsed(ParseMeta.water_name) = undefined,
    waterway: []const LayerParsed(ParseMeta.waterway) = undefined,
};

const LayerDataP = struct {
    aeroway: std.ArrayList(LayerParsed(ParseMeta.aeroway)),
    aerodrome_label: std.ArrayList(LayerParsed(ParseMeta.aerodrome_label)),
    boundary: std.ArrayList(LayerParsed(ParseMeta.boundary)),
    building: std.ArrayList(LayerParsed(ParseMeta.building)),
    housenumber: std.ArrayList(LayerParsed(ParseMeta.housenumber)),
    landcover: std.ArrayList(LayerParsed(ParseMeta.landcover)),
    landuse: std.ArrayList(LayerParsed(ParseMeta.landuse)),
    mountain_peak: std.ArrayList(LayerParsed(ParseMeta.mountain_peak)),
    park: std.ArrayList(LayerParsed(ParseMeta.park)),
    place: std.ArrayList(LayerParsed(ParseMeta.place)),
    poi: std.ArrayList(LayerParsed(ParseMeta.poi)),
    transportation: std.ArrayList(LayerParsed(ParseMeta.transportation)),
    transportation_name: std.ArrayList(LayerParsed(ParseMeta.transportation_name)),
    water: std.ArrayList(LayerParsed(ParseMeta.water)),
    water_name: std.ArrayList(LayerParsed(ParseMeta.water_name)),
    waterway: std.ArrayList(LayerParsed(ParseMeta.waterway)),
    pub fn init(alloc: Allocator) @This() {
        return @This(){
            .aeroway = .init(alloc),
            .aerodrome_label = .init(alloc),
            .boundary = .init(alloc),
            .building = .init(alloc),
            .housenumber = .init(alloc),
            .landcover = .init(alloc),
            .landuse = .init(alloc),
            .mountain_peak = .init(alloc),
            .park = .init(alloc),
            .place = .init(alloc),
            .poi = .init(alloc),
            .transportation = .init(alloc),
            .transportation_name = .init(alloc),
            .water = .init(alloc),
            .water_name = .init(alloc),
            .waterway = .init(alloc),
        };
    }
};

pub fn LayerParsed(T: type) type {
    return struct {
        meta: T,
        draw: DrawCmd,
    };
}

pub fn parse_tile(alloc: Allocator, tile: *const Tile) !LayerData {
    var layer_data = LayerDataP.init(alloc);
    var rlayer_data = LayerData{};
    const layer_items = tile.layers.items;
    for (layer_items) |layer| {
        const layer_name = layer.name.getSlice();
        const features: []Tile.Feature = layer.features.items;
        inline for (@typeInfo(LayerSchema).@"struct".decls) |decl| {
            const def_layer = decl.name;
            if (std.mem.eql(u8, layer_name, def_layer)) {
                for (features) |feature| {
                    const xmeta = feature_meta_data(
                        @field(ParseMeta, def_layer),
                        &layer,
                        &feature,
                    );
                    const draw = try DrawCmd.parse(
                        alloc,
                        feature.geometry.items,
                        @floatFromInt(layer.extent orelse 1024 * 16),
                    );
                    const parsed = LayerParsed(@field(ParseMeta, def_layer)){
                        .draw = draw,
                        .meta = xmeta,
                    };
                    const kf = &@field(layer_data, def_layer);
                    try kf.append(parsed);
                }
            }
        }
    }
    inline for (@typeInfo(LayerData).@"struct".fields) |field| {
        const kf = &@field(rlayer_data, field.name);
        kf.* = @field(layer_data, field.name).items;
    }
    return rlayer_data;
}
pub inline fn feature_meta_data(T: type, layer: *const Layer, feature: *const Feature) T {
    var t = T{};
    var it = KViterator.init(layer, feature);
    while (it.next()) |kv| {
        const fields = @typeInfo(T).@"struct".fields;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, kv.key)) {
                const fref = &@field(t, field.name);
                if (comptime @hasDecl(T, "f" ++ field.name)) {
                    fref.* = try @call(.auto, @field(T, "f" ++ field.name), .{kv.val});
                } else fref.* = get_as_val(field.type, kv.val);
            }
        }
    }
    return t;
}
pub fn get_as_val(T: type, val: Value) T {
    switch (T) {
        Value => {
            return val;
        },
        []const u8 => {
            if (val.string_value) |v| {
                return v.getSlice();
            }
        },
        ?bool => {
            if (val.bool_value) |v| return v;
            return null;
        },
        ?brunnel => {
            if (val.string_value) |v| {
                const brstr = v.getSlice();
                if (std.mem.eql(u8, "bridge", brstr)) return .bridge;
                if (std.mem.eql(u8, "tunnel", brstr)) return .tunnel;
                if (std.mem.eql(u8, "ford", brstr)) return .ford;
                return null;
            }
        },
        ?i64 => {
            if (val.uint_value) |v| return std.math.cast(i64, v);
            if (val.int_value) |v| return v;
            if (val.sint_value) |v| return v;
            return null;
        },
        else => {},
    }
    unreachable;
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

pub const ParseMeta = struct {
    fn label_to_enum(T: type, val: Value) !T {
        const m = val.string_value orelse return error.FailedConversion;
        const name = m.getSlice();
        inline for (@typeInfo(T).@"enum".fields) |fields| {
            if (std.mem.eql(u8, fields.name, name)) {
                return @enumFromInt(fields.value);
            }
        }
        return error.FailedConversion;
    }
    pub const AeroClass = enum {
        runway,
        aerodrome,
        taxiway,
        helipad,
        apron,
        gate,
        heliport,
    };
    pub const aeroway = struct {
        class: ?AeroClass = null,
        ref: []const u8 = "",
        pub fn fclass(v: Value) !?AeroClass {
            return label_to_enum(AeroClass, v) catch null;
        }
    };
    pub const aerodrome_label = struct {
        class: ?AeroClass = null,
        name: []const u8 = "",
        icao: Value = Value{},
        ele: ?i64 = null, // elevation in meters
        pub fn fclass(v: Value) !?AeroClass {
            return label_to_enum(AeroClass, v) catch null;
        }
    };
    pub const boundary = struct {
        class: []const u8 = "",
        name: []const u8 = "",
        admin_level: ?i64 = null,
        maritime: ?i64 = null,
    };
    pub const building = struct {
        render_height: ?i64 = null,
        render_min_height: ?i64 = null,
        colour: []const u8 = "",
        hide_3d: ?bool = null,
    };
    pub const housenumber = struct {
        housenumber: []const u8 = "",
    };
    pub const LandcoverClass = enum {
        ice,
        rock,
        wood,
        grass,
        sand,
        farmland,
        wetland,
    };
    pub const landcover = struct {
        class: ?LandcoverClass = null,
        subclass: []const u8 = "",
        pub fn fclass(v: Value) !?LandcoverClass {
            return label_to_enum(LandcoverClass, v) catch null;
        }
    };
    pub const LanduseClass = enum {
        railway,
        cemetery,
        quarry,
        military,
        dam,
        residential,
        suburb,
        quarter,
        neighbourhood,
        commercial,
        industrial,
        retail,
        garages,
        pitch,
        track,
        stadium,
        playground,
        theme_park,
        zoo,
        hospital,
        kindergarten,
        school,
        university,
        college,
        library,
        bus_station,
    };
    pub const landuse = struct {
        class: ?LanduseClass = null,
        pub fn fclass(v: Value) !?LanduseClass {
            return label_to_enum(LanduseClass, v) catch null;
        }
    };
    pub const mountain_peak = struct {
        name: []const u8 = "",
        class: []const u8 = "",
        ele: ?i64 = null,
        rank: ?i64 = null,
    };
    pub const park = struct {
        class: []const u8 = "",
        name: []const u8 = "",
        rank: ?i64 = null,
    };

    pub const place = struct {
        name: []const u8 = "",
        class: []const u8 = "",
        rank: ?i64 = null,
    };
    pub const poi = struct {
        name: []const u8 = "",
        class: []const u8 = "",
        subclass: []const u8 = "",
        rank: ?i64 = null,
    };

    pub const TransportationClass = enum {
        motorway,
        trunk,
        motorway_construction,
        trunk_construction,
        primary,
        secondary,
        tertiary,
        primary_construction,
        secondary_construction,
        tertiary_construction,
        minor,
        service,
        minor_construction,
        service_construction,
        track,
        track_construction,
        path,
        path_construction,
        raceway,
        raceway_construction,
        bridge,
        pier,
        rail,
        ferry,
        busway,
        bus_guideway,
        transit,
    };
    pub const transportation = struct {
        class: ?TransportationClass = null,
        subclass: []const u8 = "",
        brunnel: ?brunnel = null,
        pub fn fclass(v: Value) !?TransportationClass {
            return label_to_enum(TransportationClass, v) catch null;
        }
    };
    pub const transportation_name = struct {
        class: ?TransportationClass = null,
        name: []const u8 = "",
        ref: []const u8 = "",
        subclass: []const u8 = "",
        brunnel: ?brunnel = null,
        pub fn fclass(v: Value) !?TransportationClass {
            return label_to_enum(TransportationClass, v) catch null;
        }
    };
    pub const WaterClass = enum {
        river,
        pond,
        dock,
        swimming_pool,
        lake,
        ocean,
        stream,
        canal,
        drain,
        ditch,
    };
    pub const water = struct {
        class: ?WaterClass = null,
        brunnel: ?brunnel = null,
        intermittent: ?bool = null,
        pub fn fclass(v: Value) !?WaterClass {
            return label_to_enum(WaterClass, v) catch null;
        }
    };
    pub const water_name = struct {
        name: []const u8 = "",
        intermittent: ?bool = null,
        class: ?WaterClass = null,
        pub fn fclass(v: Value) !?WaterClass {
            return label_to_enum(WaterClass, v) catch null;
        }
    };
    pub const waterway = struct {
        name: []const u8 = "",
        brunnel: ?brunnel = null,
        intermittent: ?bool = null,
        class: ?WaterClass = null,
        pub fn fclass(v: Value) !?WaterClass {
            return label_to_enum(WaterClass, v) catch null;
        }
    };
};
const brunnel = enum {
    bridge,
    tunnel,
    ford,
};

pub const DrawCmd = struct {
    points: []const struct { f32, f32 },
    type: []const DrawType,
    pub fn parse(alloc: Allocator, geom: []const u32, extent: f32) !@This() {
        var wr = WRender2{
            .extent = extent,
            .points = std.ArrayList(struct { f32, f32 }).init(alloc),
            .type = std.ArrayList(DrawType).init(alloc),
        };
        try wr.render_geometry(geom);
        return @This(){
            .points = wr.points.items,
            .type = wr.type.items,
        };
    }

    pub const DrawType = struct {
        pub const Action = enum {
            close_fill,
            stroke,
            close_stroke,
        };
        action: Action,
        start: usize,
        end: usize,
    };
    const WRender2 = struct {
        const Type = enum { Polygon, LineString };
        x: f32 = 0,
        y: f32 = 0,
        extent: f32,
        rtype: Type = .Polygon,
        last_point_idx: usize = 0,
        points: std.ArrayList(struct { f32, f32 }),
        type: std.ArrayList(DrawType),
        pub fn render_geometry(self: *@This(), cmd_buffer: []const u32) !void {
            Cmd.decode(cmd_buffer, self) catch |e| {
                std.log.err("cmd decode error: {}", .{e});
                return e;
            };
        }
        fn append(self: *@This(), action: DrawType.Action) !void {
            if (self.points.items.len > self.last_point_idx) {
                try self.type.append(DrawType{
                    .action = action,
                    .start = self.last_point_idx,
                    .end = self.points.items.len,
                });
                self.last_point_idx = self.points.items.len;
            }
        }
        fn close_path(self: *@This()) !void {
            switch (self.rtype) {
                .Polygon => {
                    try self.append(.close_fill);
                },
                .LineString => {
                    try self.append(.close_stroke);
                },
            }
        }
        fn move_to(self: *@This(), dx: i32, dy: i32) !void {
            try self.append(.stroke);
            self.add_xy(dx, dy);
            try self.points.append(self.get_normalized_vec());
        }
        fn line_to(self: *@This(), dx: i32, dy: i32) !void {
            self.add_xy(dx, dy);
            try self.points.append(self.get_normalized_vec());
        }
        fn get_normalized_vec(self: *@This()) Vec2 {
            if (self.extent <= 1) return .{ 0, 0 };
            return .{
                self.x / self.extent,
                self.y / self.extent,
            };
        }
        const Vec2 = struct { f32, f32 };
        inline fn add_xy(self: *@This(), x: i32, y: i32) void {
            self.x += @floatFromInt(x);
            self.y += @floatFromInt(y);
        }
    };
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
                    try user_data.close_path();
                },
                .MoveTo => {
                    const advance: usize = cmdint.count;
                    if (idx + advance * op_count > geometry.len) return error.InvalidEncoding;
                    for (0..advance) |i| {
                        const s = idx + i * op_count;
                        const xy = geometry[s .. s + op_count];
                        const x = param_integer(xy[0]);
                        const y = param_integer(xy[1]);
                        try user_data.move_to(x, y);
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
                        try user_data.line_to(x, y);
                    }
                    idx += op_count * advance;
                },
            }
            if (idx >= geometry.len) return;
        }
    }
};
