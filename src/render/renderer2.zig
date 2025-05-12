const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const z2d = @import("z2d");
const root = @import("../root.zig");
const dec = root.decoder2;
const com = root.common;

const This = @This();
const Traverser = dec.LayerTraverser(This);
const Cmd = dec.Cmd;
const from_hex = com.from_hex;
const z2dRGBA = com.z2dRGBA;

const Tailwind = @import("tailwind");
const Line = root.thickness;
const FeatureDrawProperties = com.FeatureDrawProperties;
const Color = root.Color;

const common_color = struct {
    fn aeroway_color(meta: dec.ParseMeta.aeroway) z2dRGBA {
        const s = meta.class orelse
            return from_hex(Tailwind.neutral400);
        const hex = switch (s) {
            .taxiway, .runway => from_hex(Tailwind.neutral300),
            .aerodrome => from_hex(Tailwind.sky100),
            .helipad, .heliport => from_hex(Tailwind.amber300),
            .apron => from_hex(Tailwind.yellow100),
            .gate => from_hex(Tailwind.orange400),
        };
        return hex;
    }
    fn water_color(class: ?dec.ParseMeta.WaterClass) z2dRGBA {
        const meta = class orelse
            return from_hex(Tailwind.blue400);
        return switch (meta) {
            .river => from_hex(Tailwind.sky300),
            .pond => from_hex(Tailwind.teal300),
            .dock => from_hex(Tailwind.cyan400),
            .swimming_pool => from_hex(Tailwind.cyan400),
            .lake => from_hex(Tailwind.blue300),
            .ocean => from_hex(Tailwind.teal400),
            .stream => from_hex(Tailwind.teal400),
            .canal => from_hex(Tailwind.cyan700),
            .drain => from_hex(Tailwind.teal800),
            .ditch => from_hex(Tailwind.teal800),
        };
    }
    fn landcover_color(meta: dec.ParseMeta.landcover) z2dRGBA {
        const s = meta.class orelse
            return from_hex(Tailwind.green300);
        const hex = switch (s) {
            .ice => from_hex(Tailwind.cyan100),
            .rock => from_hex(Tailwind.zinc500),
            .wood => from_hex(Tailwind.green300),
            .grass => from_hex(Tailwind.lime200),
            .sand => from_hex(Tailwind.yellow200),
            .farmland => from_hex(Tailwind.green200),
            .wetland => from_hex(Tailwind.orange200),
        };
        return hex;
    }
    fn landuse_color(meta: dec.ParseMeta.landuse) z2dRGBA {
        const s = meta.class orelse
            return from_hex(Tailwind.green300);
        const hex = switch (s) {
            .railway => from_hex(Tailwind.red200),

            .cemetery, .quarry => from_hex(Tailwind.slate300),

            .dam, .military => from_hex(Tailwind.emerald500),

            .residential, .neighbourhood, .quarter, .suburb => from_hex(Tailwind.amber100),

            .commercial, .retail, .industrial => from_hex(Tailwind.yellow200),

            .track, .garages, .pitch => from_hex(Tailwind.zinc200),

            .stadium, .zoo, .playground, .theme_park => from_hex(Tailwind.fuchsia200),

            .hospital => from_hex(Tailwind.pink200),

            .library, .kindergarten, .school, .university, .college => from_hex(Tailwind.green200),

            .bus_station => from_hex(Tailwind.orange300),
        };
        return hex;
    }
    fn transport(class: ?dec.ParseMeta.TransportationClass) FeatureDrawProperties {
        if (class == null) return FeatureDrawProperties{
            .color = from_hex(Tailwind.neutral300),
        };
        const tw_hex = switch (class.?) {
            .motorway, .trunk, .motorway_construction, .trunk_construction => from_hex(Tailwind.purple300),

            .primary, .secondary, .tertiary, .primary_construction, .secondary_construction, .tertiary_construction => from_hex(Tailwind.slate400),

            .minor, .service, .minor_construction, .service_construction => from_hex(Tailwind.gray400),

            .track, .track_construction, .path, .path_construction => from_hex(Tailwind.stone400),

            .raceway, .raceway_construction => from_hex(Tailwind.red300),

            .bridge, .pier => from_hex(Tailwind.neutral500),

            .rail => from_hex(Tailwind.rose400),

            .ferry => from_hex(Tailwind.sky300),

            .busway, .bus_guideway => from_hex(Tailwind.orange300),

            .transit => from_hex(Tailwind.rose300),
        };

        const lw: f32 = switch (class.?) {
            .motorway, .trunk, .motorway_construction, .trunk_construction, .primary, .primary_construction, .secondary, .secondary_construction, .bridge, .pier, .rail, .ferry, .transit, .busway, .bus_guideway, .tertiary, .tertiary_construction, .minor, .service, .minor_construction, .service_construction => Line.StandardSizes.M,

            .path, .path_construction, .track, .track_construction, .raceway, .raceway_construction => Line.StandardSizes.S,
        };
        return FeatureDrawProperties{
            .color = tw_hex,
            .line_width = lw,
        };
    }
};
pub const rend2config = struct {
    pub fn aeroway(meta: dec.ParseMeta.aeroway) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.aeroway_color(meta),
        };
    }

    pub fn boundary(meta: dec.ParseMeta.boundary) FeatureDrawProperties {
        var col = from_hex(Tailwind.zinc300);
        const line_width: f64 = Line.StandardSizes.M;
        var dashed = false;
        if (meta.admin_level) |admin_level| {
            if (meta.maritime) |m| {
                if (m == 1) {
                    dashed = true;
                    if (admin_level <= 2) {
                        col = from_hex(Tailwind.indigo300);
                    } else if (admin_level <= 4) {
                        col = from_hex(Tailwind.blue300);
                    }
                } else {
                    if (admin_level <= 2) {
                        col = from_hex(Tailwind.stone400);
                    } else if (admin_level <= 4) {
                        col = from_hex(Tailwind.orange200);
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
        const col = com.col_to_z2d_pixel_rgb(Color.convert_hex(meta.colour) catch Color.from_hex(Tailwind.stone300));
        return FeatureDrawProperties{
            .color = col,
        };
    }
    pub fn landcover(meta: dec.ParseMeta.landcover) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.landcover_color(meta),
        };
    }

    pub fn landuse(meta: dec.ParseMeta.landuse) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.landuse_color(meta),
        };
    }
    pub fn park(_: dec.ParseMeta.park) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = from_hex(Tailwind.green300),
        };
    }

    pub fn transportation(meta: dec.ParseMeta.transportation) FeatureDrawProperties {
        return common_color.transport(meta.class);
    }
    pub fn transportation_name(meta: dec.ParseMeta.transportation_name) FeatureDrawProperties {
        return common_color.transport(meta.class);
    }
    pub fn water(meta: dec.ParseMeta.water) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.water_color(meta.class),
        };
    }
    pub fn water_name(meta: dec.ParseMeta.water_name) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.water_color(meta.class),
        };
    }
    pub fn waterway(meta: dec.ParseMeta.waterway) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common_color.water_color(meta.class),
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
pub const DefaultColor = from_hex(Tailwind.lime200);

test "single threaded" {
    // if (true) return;
    var timer = std.time.Timer.start() catch unreachable;
    try leipzig_new_york_rendering(.{ 10, 11 });
    std.debug.print("\n\n\nrenderer 2 time: {} ms", .{timer.read() / 1_000_000});
}

fn leipzig_new_york_rendering(comptime zoom_level: struct { comptime_int, comptime_int }) !void {
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const width_height = 720;
    const render_list: []const []const u8 = &.{
        "leipzig",
        "new_york",
    };
    var time = std.time.Timer.start() catch unreachable;
    inline for (render_list) |city| {
        inline for (zoom_level[0]..zoom_level[1]) |zoom| {
            const alloc = arena.allocator();
            const zoom_str = city ++ std.fmt.comptimePrint("_z{}", .{zoom});
            const tile_subpath = "./testdata/" ++ zoom_str;
            const output_subpath = "./output/normal" ++ zoom_str ++ ".png";
            std.log.warn("render: {s} to {s}", .{ tile_subpath, output_subpath });
            var file = try std.fs.cwd().openFile(tile_subpath, .{});
            const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
            time.reset();
            const tile: dec.Tile = try dec.decode(input, alloc);
            // std.log.warn("time decoding: {d:.3} ms", .{time.lap() / 1_000_000});
            time.reset();
            const bascol = from_hex(Tailwind.lime100);
            var sfc = try z2d.Surface.initPixel(.{ .rgba = bascol }, alloc, @intCast(width_height), @intCast(width_height));
            var ctx = z2d.Context.init(alloc, &sfc);
            const data = try dec.parse_tile(alloc, &tile);
            try render_all(
                &ctx,
                &data,
                @floatCast(width_height),
                0,
                0,
            );
            // const sfc = try render_tile_leaky(alloc, width_height, width_height, 0, -500, &tile);
            std.log.warn("time rendering: {d:.3} ms", .{time.lap() / 1_000_000});
            try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
            _ = arena.reset(.retain_capacity);
            // std.log.warn("time png: {d:.3} ms", .{time.lap() / 1_000_000});
        }
    }
}
