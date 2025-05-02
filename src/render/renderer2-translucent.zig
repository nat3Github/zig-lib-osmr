const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const z2d = @import("z2d");
const root = @import("../root.zig");
const dec = root.decoder2;
const Tile = dec.Tile;
const Layer = dec.Layer;
const Feature = dec.Feature;

const This = @This();
const Traverser = dec.LayerTraverser(This);
const Cmd = dec.Cmd;
const Color = root.Color;

const Tailwind = @import("tailwind");
const Line = root.thickness;
const com = @import("common.zig");
const FeatureDrawProperties = com.FeatureDrawProperties;

const common_color = struct {
    fn aeroway_color(meta: dec.ParseMeta.aeroway) Color {
        const s = meta.class orelse
            return Color.from_hex(Tailwind.neutral400);
        const hex = switch (s) {
            .taxiway, .runway => Color.from_hex(Tailwind.neutral200),
            .aerodrome => Color.from_hex(Tailwind.sky100),
            .helipad, .heliport => Color.from_hex(Tailwind.amber200),
            .apron => Color.from_hex(Tailwind.yellow100),
            .gate => Color.from_hex(Tailwind.orange300),
        };
        return hex;
    }
    fn water_color(class: ?dec.ParseMeta.WaterClass) Color {
        const meta = class orelse
            return Color.from_hex(Tailwind.blue400);
        return switch (meta) {
            .river, .lake, .ocean, .stream, .pond => Color.from_hex(Tailwind.indigo950),
            .dock, .swimming_pool, .canal, .drain, .ditch => Color.from_hex(Tailwind.teal800),
        };
    }
    fn landcover_color(meta: dec.ParseMeta.landcover) Color {
        const s = meta.class orelse
            return Color.from_hex(Tailwind.green50);
        const hex = switch (s) {
            .ice => Color.from_hex(Tailwind.cyan50),
            .rock => Color.from_hex(Tailwind.zinc200),
            .wood => Color.from_hex(Tailwind.green100),
            .grass => Color.from_hex(Tailwind.lime50),
            .sand => Color.from_hex(Tailwind.yellow50),
            .farmland => Color.from_hex(Tailwind.green100),
            .wetland => Color.from_hex(Tailwind.orange100),
        };
        return hex;
    }
    fn landuse_color(meta: dec.ParseMeta.landuse) Color {
        const s = meta.class orelse
            return Color.from_hex(Tailwind.green500);
        const hex = switch (s) {
            .railway => Color.from_hex(Tailwind.red500),

            .cemetery, .quarry => Color.from_hex(Tailwind.slate500),

            .dam, .military => Color.from_hex(Tailwind.emerald500),

            .residential, .neighbourhood, .quarter, .suburb => Color.from_hex(Tailwind.amber500),

            .commercial, .retail, .industrial => Color.from_hex(Tailwind.yellow50),

            .track, .garages, .pitch => Color.from_hex(Tailwind.zinc500),

            .stadium, .zoo, .playground, .theme_park => Color.from_hex(Tailwind.fuchsia500),

            .hospital => Color.from_hex(Tailwind.pink500),

            .library, .kindergarten, .school, .university, .college => Color.from_hex(Tailwind.green500),

            .bus_station => Color.from_hex(Tailwind.orange500),
        };
        return hex;
    }
    fn transport(class: ?dec.ParseMeta.TransportationClass) FeatureDrawProperties {
        if (class == null) return FeatureDrawProperties{
            .color = Color.from_hex(Tailwind.neutral300),
        };
        const tw_hex = switch (class.?) {
            .motorway, .trunk, .motorway_construction, .trunk_construction, .primary, .secondary, .tertiary, .primary_construction, .secondary_construction, .tertiary_construction => Color.from_hex(Tailwind.slate300),

            .minor, .service, .minor_construction, .service_construction => Color.from_hex(Tailwind.gray300),

            .track, .track_construction, .path, .path_construction => Color.from_hex(Tailwind.stone400),

            .raceway, .raceway_construction => Color.from_hex(Tailwind.red800),

            .bridge, .pier => Color.from_hex(Tailwind.neutral700),

            .rail => Color.from_hex(Tailwind.red900),

            .ferry => Color.from_hex(Tailwind.sky500),

            .busway, .bus_guideway => Color.from_hex(Tailwind.orange800),

            .transit => Color.from_hex(Tailwind.rose900),
        };

        const lw: f32 = switch (class.?) {
            .motorway, .trunk, .motorway_construction, .trunk_construction, .primary, .primary_construction, .secondary, .secondary_construction, .bridge, .pier, .rail, .ferry, .transit, .busway, .bus_guideway, .tertiary, .tertiary_construction, .minor, .service, .minor_construction, .service_construction => Line.StandardSizes.L,

            .path, .path_construction, .track, .track_construction, .raceway, .raceway_construction => Line.StandardSizes.M,
        };
        return FeatureDrawProperties{
            .color = tw_hex,
            .line_width = lw,
        };
    }
};
pub const rend2config = struct {
    // pub fn aeroway(meta: dec.ParseMeta.aeroway) FeatureDrawProperties {
    //     return FeatureDrawProperties{
    //         .color = common_color.aeroway_color(meta),
    //     };
    // }

    pub fn boundary(meta: dec.ParseMeta.boundary) FeatureDrawProperties {
        var col = Color.from_hex(Tailwind.yellow700);
        const line_width: f64 = Line.StandardSizes.XL;
        var dashed = false;
        if (meta.admin_level) |admin_level| {
            if (meta.maritime) |m| {
                if (m == 1) {
                    dashed = true;
                    if (admin_level <= 2) {
                        col = Color.from_hex(Tailwind.indigo700);
                    } else if (admin_level <= 4) {
                        col = Color.from_hex(Tailwind.blue800);
                    }
                } else {
                    if (admin_level <= 2) {
                        col = Color.from_hex(Tailwind.stone700);
                    } else if (admin_level <= 4) {
                        col = Color.from_hex(Tailwind.orange900);
                    }
                }
            }
        }
        return FeatureDrawProperties{
            .color = col,
            .dotted = dashed,
            .line_width = line_width,
        };
    }
    pub fn building(meta: dec.ParseMeta.building) FeatureDrawProperties {
        const default_col = Color.from_hex(Tailwind.stone300);
        const col = Color.convert_hex(meta.colour) catch default_col;
        return FeatureDrawProperties{
            .outline = col,
            .dotted = true,
        };
    }
    // pub fn landcover(meta: dec.ParseMeta.landcover) FeatureDrawProperties {
    //     return FeatureDrawProperties{
    //         .color = common_color.landcover_color(meta),
    //     };
    // }
    pub fn landuse(meta: dec.ParseMeta.landuse) FeatureDrawProperties {
        const col = common_color.landuse_color(meta);
        return FeatureDrawProperties{
            .outline = col,
            // .dotted = true,
            .line_width = 1,
        };
    }
    // pub fn park(_: dec.ParseMeta.park) FeatureDrawProperties {
    //     return FeatureDrawProperties{
    //         .color = .from_hex(Tailwind.green200),
    //     };
    // }

    pub fn transportation(meta: dec.ParseMeta.transportation) FeatureDrawProperties {
        return common_color.transport(meta.class);
    }
    pub fn transportation_name(meta: dec.ParseMeta.transportation_name) FeatureDrawProperties {
        return common_color.transport(meta.class);
    }
    pub fn water(meta: dec.ParseMeta.water) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.water_color(meta.class),
            .outline = .from_hex(Tailwind.neutral300),
        };
    }
    pub fn water_name(meta: dec.ParseMeta.water_name) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.water_color(meta.class),
            .outline = .from_hex(Tailwind.neutral300),
        };
    }
    pub fn waterway(meta: dec.ParseMeta.waterway) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.water_color(meta.class),
            .outline = .from_hex(Tailwind.neutral300),
            .dotted = true,
            .line_width = Line.StandardSizes.M,
        };
    }
};

pub fn render_all(
    ctx: *z2d.Context,
    data: *const dec.LayerData,
    scale: f32,
    offset_x: f32,
    offset_y: f32,
) !void {
    return com.render_all(ctx, data, rend2config, scale, offset_x, offset_y);
}
pub const DefaultColor = Color.from_hex(Tailwind.lime200);

test "single threaded" {
    if (true) return;
    var timer = std.time.Timer.start() catch unreachable;
    try leipzig_new_york_rendering(.{ 10, 11 });
    std.debug.print("\n\n\nrenderer 2 time: {} ms", .{timer.read() / 1_000_000});
}

fn leipzig_new_york_rendering(comptime zoom_level: struct { comptime_int, comptime_int }) !void {
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const width_height = 1920;
    const render_list: []const []const u8 = &.{
        "leipzig",
    };
    var time = std.time.Timer.start() catch unreachable;
    inline for (render_list) |city| {
        inline for (zoom_level[0]..zoom_level[1]) |zoom| {
            const alloc = arena.allocator();
            const zoom_str = city ++ std.fmt.comptimePrint("_z{}", .{zoom});
            const tile_subpath = "./testdata/" ++ zoom_str;
            const output_subpath = "./output/k" ++ zoom_str ++ ".png";
            std.log.warn("render: {s} to {s}", .{ tile_subpath, output_subpath });
            var file = try std.fs.cwd().openFile(tile_subpath, .{});
            const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
            time.reset();
            const tile: dec.Tile = try dec.decode(input, alloc);
            // std.log.warn("time decoding: {d:.3} ms", .{time.lap() / 1_000_000});
            time.reset();
            var sfc = try z2d.Surface.initPixel(.{ .rgba = .{
                .r = 255,
                .g = 255,
                .b = 255,
                .a = 255,
            } }, alloc, @intCast(width_height), @intCast(width_height));
            var ctx = z2d.Context.init(alloc, &sfc);
            const data = try dec.parse_tile(alloc, &tile);
            try render_all(
                &ctx,
                &data,
                @floatCast(width_height),
                500,
                500,
            );
            // const sfc = try render_tile_leaky(alloc, width_height, width_height, 0, -500, &tile);
            std.log.warn("time rendering: {d:.3} ms", .{time.lap() / 1_000_000});
            try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
            _ = arena.reset(.retain_capacity);
            // std.log.warn("time png: {d:.3} ms", .{time.lap() / 1_000_000});
        }
    }
}
