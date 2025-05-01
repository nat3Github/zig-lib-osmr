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
            // std.log.warn("handle transportation", .{});
            _ = .{ layer, feat, d, self };
        }
        const order = struct {
            transportation: *const fn (*This, *const Layer, *const Feature, *const Transportation) void = handle_transportation,
        };
    };
    var xx = XX{
        .alloc = alloc,
    };
    try traverse_tile(XX, &xx, &tile, XX.order{});
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
const LayerNames = &.{
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

const performance_measuring = true;
pub fn traverse_tile(T: type, t: *T, tile: *const Tile, comptime order: anytype) !void {
    const layer_items = tile.layers.items;
    const order_fields = comptime @typeInfo(@TypeOf(order)).@"struct".fields;

    const layer_names: []const []const u8 = LayerNames;
    if (layer_items.len > layer_names.len) {
        std.log.warn("unexpected layer len {}", .{layer_items.len});
    }

    inline for (order_fields) |field| {
        const field_name: []const u8 = field.name;
        for (layer_items) |layer| {
            const layer_name = layer.name.getSlice();
            if (std.mem.eql(u8, field_name, layer_name)) {
                _ = @hasDecl(LayerSchema, field.name);
                const f = @field(order, field.name);
                const ptr = @typeInfo(@TypeOf(f)).pointer.child;
                const p4 = @typeInfo(ptr).@"fn".params[3].type.?;
                const DataT = @typeInfo(p4).pointer.child;
                comptime_parse_struct(DataT, t, &layer, f);
            }
        }
    }
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

pub inline fn comptime_parse_struct(T: type, tpointer: anytype, layer: *const Layer, callback: *const fn (@TypeOf(tpointer), *const Layer, *const Feature, *const T) void) void {
    // var timer = std.time.Timer.start() catch unreachable;
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
        // const xt = @as(f64, @floatFromInt(timer.lap())) / 1e6;
        // if (xt > 15) {
        //     std.log.warn("layer: {s} time: {d:.3} ms", .{
        //         layer.name.getSlice(),
        //         xt,
        //     });
        // }
    }
}

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
