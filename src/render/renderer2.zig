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
const common = struct {
    fn aeroway_color(meta: dec.ParseMeta.aeroway) Color {
        const s = meta.class orelse
            return Color.from_hex(Tailwind.neutral400);
        const hex = switch (s) {
            .taxiway, .runway => Color.from_hex(Tailwind.neutral300),
            .aerodrome => Color.from_hex(Tailwind.sky100),
            .helipad, .heliport => Color.from_hex(Tailwind.amber300),
            .apron => Color.from_hex(Tailwind.yellow100),
            .gate => Color.from_hex(Tailwind.orange400),
        };
        return hex;
    }
    fn water_color(class: ?dec.ParseMeta.WaterClass) Color {
        const meta = class orelse
            return Color.from_hex(Tailwind.blue400);
        return switch (meta) {
            .river => Color.from_hex(Tailwind.sky300),
            .pond => Color.from_hex(Tailwind.teal300),
            .dock => Color.from_hex(Tailwind.cyan400),
            .swimming_pool => Color.from_hex(Tailwind.cyan400),
            .lake => Color.from_hex(Tailwind.blue300),
            .ocean => Color.from_hex(Tailwind.teal400),
            .stream => Color.from_hex(Tailwind.teal400),
            .canal => Color.from_hex(Tailwind.cyan700),
            .drain => Color.from_hex(Tailwind.teal800),
            .ditch => Color.from_hex(Tailwind.teal800),
        };
    }
    fn landcover_color(meta: dec.ParseMeta.landcover) Color {
        const s = meta.class orelse
            return Color.from_hex(Tailwind.green300);
        const hex = switch (s) {
            .ice => Color.from_hex(Tailwind.cyan100),
            .rock => Color.from_hex(Tailwind.zinc500),
            .wood => Color.from_hex(Tailwind.green300),
            .grass => Color.from_hex(Tailwind.lime200),
            .sand => Color.from_hex(Tailwind.yellow200),
            .farmland => Color.from_hex(Tailwind.green200),
            .wetland => Color.from_hex(Tailwind.orange200),
        };
        return hex;
    }
    fn landuse_color(meta: dec.ParseMeta.landuse) Color {
        const s = meta.class orelse
            return Color.from_hex(Tailwind.green300);
        const hex = switch (s) {
            .railway => Color.from_hex(Tailwind.red200),

            .cemetery => Color.from_hex(Tailwind.slate300),
            .quarry => Color.from_hex(Tailwind.slate300),

            .dam => Color.from_hex(Tailwind.emerald500),
            .military => Color.from_hex(Tailwind.emerald500),

            .residential => Color.from_hex(Tailwind.amber100),
            .neighbourhood => Color.from_hex(Tailwind.amber100),
            .quarter => Color.from_hex(Tailwind.amber100),
            .suburb => Color.from_hex(Tailwind.amber100),

            .commercial => Color.from_hex(Tailwind.yellow200),
            .retail => Color.from_hex(Tailwind.yellow200),
            .industrial => Color.from_hex(Tailwind.yellow200),

            .track => Color.from_hex(Tailwind.zinc200),
            .garages => Color.from_hex(Tailwind.zinc200),
            .pitch => Color.from_hex(Tailwind.zinc200),

            .stadium => Color.from_hex(Tailwind.fuchsia200),
            .zoo => Color.from_hex(Tailwind.fuchsia200),
            .playground => Color.from_hex(Tailwind.fuchsia200),
            .theme_park => Color.from_hex(Tailwind.fuchsia200),

            .hospital => Color.from_hex(Tailwind.pink200),

            .library => Color.from_hex(Tailwind.green200),
            .kindergarten => Color.from_hex(Tailwind.green200),
            .school => Color.from_hex(Tailwind.green200),
            .university => Color.from_hex(Tailwind.green200),
            .college => Color.from_hex(Tailwind.green200),

            .bus_station => Color.from_hex(Tailwind.orange300),
        };
        return hex;
    }
    fn transport(class: ?dec.ParseMeta.TransportationClass) FeatureDrawProperties {
        if (class == null) return FeatureDrawProperties{
            .color = Color.from_hex(Tailwind.neutral300),
        };
        const tw_hex = switch (class.?) {
            .motorway => Color.from_hex(Tailwind.purple300),
            .trunk => Color.from_hex(Tailwind.purple300),
            .motorway_construction => Color.from_hex(Tailwind.purple300),
            .trunk_construction => Color.from_hex(Tailwind.purple300),

            .primary => Color.from_hex(Tailwind.slate400),
            .secondary => Color.from_hex(Tailwind.slate400),
            .tertiary => Color.from_hex(Tailwind.slate400),
            .primary_construction => Color.from_hex(Tailwind.slate400),
            .secondary_construction => Color.from_hex(Tailwind.slate400),
            .tertiary_construction => Color.from_hex(Tailwind.slate400),

            .minor => Color.from_hex(Tailwind.gray400),
            .service => Color.from_hex(Tailwind.gray400),
            .minor_construction => Color.from_hex(Tailwind.gray400),
            .service_construction => Color.from_hex(Tailwind.gray400),

            .track => Color.from_hex(Tailwind.stone400),
            .track_construction => Color.from_hex(Tailwind.stone400),
            .path => Color.from_hex(Tailwind.stone400),
            .path_construction => Color.from_hex(Tailwind.stone400),

            .raceway => Color.from_hex(Tailwind.red300),
            .raceway_construction => Color.from_hex(Tailwind.red300),

            .bridge => Color.from_hex(Tailwind.neutral500),
            .pier => Color.from_hex(Tailwind.neutral500),

            .rail => Color.from_hex(Tailwind.rose400),

            .ferry => Color.from_hex(Tailwind.sky300),

            .busway => Color.from_hex(Tailwind.orange300),
            .bus_guideway => Color.from_hex(Tailwind.orange300),

            .transit => Color.from_hex(Tailwind.rose300),
        };

        const lw: f32 = switch (class.?) {
            .motorway => Line.StandardSizes.M,
            .trunk => Line.StandardSizes.M,
            .motorway_construction => Line.StandardSizes.M,
            .trunk_construction => Line.StandardSizes.M,

            .primary => Line.StandardSizes.M,
            .primary_construction => Line.StandardSizes.M,

            .secondary => Line.StandardSizes.M,
            .secondary_construction => Line.StandardSizes.M,

            .bridge => Line.StandardSizes.M,
            .pier => Line.StandardSizes.M,
            .rail => Line.StandardSizes.M,
            .ferry => Line.StandardSizes.M,
            .transit => Line.StandardSizes.M,
            .busway => Line.StandardSizes.M,
            .bus_guideway => Line.StandardSizes.M,

            .tertiary => Line.StandardSizes.M,
            .tertiary_construction => Line.StandardSizes.M,
            .minor => Line.StandardSizes.M,
            .service => Line.StandardSizes.M,
            .minor_construction => Line.StandardSizes.M,
            .service_construction => Line.StandardSizes.M,

            .path => Line.StandardSizes.S,
            .path_construction => Line.StandardSizes.S,
            .track => Line.StandardSizes.S,
            .track_construction => Line.StandardSizes.S,
            .raceway => Line.StandardSizes.S,
            .raceway_construction => Line.StandardSizes.S,
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
            .color = common.aeroway_color(meta),
        };
    }

    pub fn boundary(meta: dec.ParseMeta.boundary) FeatureDrawProperties {
        var col = Color.from_hex(Tailwind.zinc300);
        const line_width: f64 = Line.StandardSizes.M;
        var dashed = false;
        if (meta.admin_level) |admin_level| {
            if (meta.maritime) |m| {
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
            .color = col,
        };
    }
    pub fn landcover(meta: dec.ParseMeta.landcover) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common.landcover_color(meta),
        };
    }

    pub fn landuse(meta: dec.ParseMeta.landuse) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common.landuse_color(meta),
        };
    }
    pub fn park(_: dec.ParseMeta.park) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = .from_hex(Tailwind.green300),
        };
    }

    pub fn transportation(meta: dec.ParseMeta.transportation) FeatureDrawProperties {
        return common.transport(meta.class);
    }
    pub fn transportation_name(meta: dec.ParseMeta.transportation_name) FeatureDrawProperties {
        return common.transport(meta.class);
    }
    pub fn water(meta: dec.ParseMeta.water) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common.water_color(meta.class),
        };
    }
    pub fn water_name(meta: dec.ParseMeta.water_name) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common.water_color(meta.class),
        };
    }
    pub fn waterway(meta: dec.ParseMeta.waterway) FeatureDrawProperties {
        return FeatureDrawProperties{
            .color = common.water_color(meta.class),
        };
    }
};

pub const FeatureDrawProperties = struct {
    color: Color,
    dotted: bool = false,
    line_width: f32 = 2,
};

inline fn context_draw(
    ctx: *z2d.Context,
    offset_x: f32,
    offset_y: f32,
    scale: f32,
    clipped_data: []const struct { f32, f32 },
    action: dec.DrawCmd.DrawType.Action,
    col: Color,
    line_width: f64,
    dotted: bool,
) !void {
    if (dotted) {
        ctx.setDashes(&.{ 10, 7 });
    } else ctx.setDashes(&.{});
    const r, const g, const b = col.rgb();
    ctx.setSourceToPixel(.{ .rgb = .{ .r = r, .g = g, .b = b } });
    ctx.setLineWidth(line_width);
    const w: f32 = scale;
    {
        const x, const y = clipped_data[0];
        try ctx.moveTo(
            x * w + offset_x,
            y * w + offset_y,
        );
    }
    for (clipped_data[1..]) |d| {
        const x, const y = d;
        try ctx.lineTo(
            x * w + offset_x,
            y * w + offset_y,
        );
    }
    switch (action) {
        .close_fill => {
            try ctx.closePath();
            try ctx.fill();
        },
        .close_stroke => {
            try ctx.closePath();
            try ctx.stroke();
        },
        .stroke => {
            try ctx.stroke();
        },
    }
    ctx.resetPath();
}
pub fn render_all(
    ctx: *z2d.Context,
    data: *const dec.LayerData,
    config: type,
    scale: f32,
    offset_x: f32,
    offset_y: f32,
) !void {
    const LayerOrder = &.{
        "landcover",
        "landuse",
        "park",
        "water",
        "water_name",
        "waterway",
        "aeroway",
        "aerodrome_label",
        "building",
        "boundary",
        "transportation",
        "transportation_name",

        "housenumber",
        "mountain_peak",
        "place",
        "poi",
    };
    inline for (LayerOrder) |layer_name| {
        if (comptime @hasDecl(config, layer_name)) {
            const dat = @field(data, layer_name);
            const fnc = @field(config, layer_name);
            for (dat) |layer_dat| {
                const meta = layer_dat.meta;
                const draw = layer_dat.draw;
                const prop: FeatureDrawProperties = @call(.auto, fnc, .{meta});
                for (draw.type) |t| {
                    const dd = draw.points[t.start..t.end];
                    const daction = t.action;
                    try context_draw(ctx, offset_x, offset_y, scale, dd, daction, prop.color, prop.line_width, prop.dotted);
                }
            }
        }
    }
}
const DefaultColor = Color.from_hex(Tailwind.lime200);
pub fn render_tile_leaky(alloc: Allocator, img_width: usize, img_height: usize, offset_x: f32, offset_y: f32, tile: *const Tile) !z2d.Surface {
    const dat = try dec.parse_tile(alloc, tile);
    const r, const g, const b, const a = DefaultColor.rgba();
    var sfc = try z2d.Surface.initPixel(.{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } }, alloc, @intCast(img_width), @intCast(img_height));
    var ctx = z2d.Context.init(alloc, &sfc);
    try render_all(
        &ctx,
        dat,
        rend2config,
        @floatFromInt(img_width),
        offset_x,
        offset_y,
    );
    return sfc;
}
fn render_part(
    gpa: Allocator,
    pixels: []z2d.pixel.RGBA,
    width: usize,
    initial_px: z2d.pixel.RGBA,
    scale: f32,
    dat: *const dec.LayerData,
    offsetx: f32,
    offsety: f32,
) void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    var ssfc = z2d.Surface.initBuffer(
        .image_surface_rgba,
        initial_px,
        pixels,
        @intCast(width),
        @intCast(pixels.len / width),
    );
    var ctx = z2d.Context.init(alloc, &ssfc);
    render_all(
        &ctx,
        dat,
        rend2config,
        scale,
        offsetx,
        offsety,
    ) catch {};
}
pub fn render_tile_leaky_mt(alloc: Allocator, img_width: usize, img_height: usize, tile: *const Tile) !z2d.Surface {
    const pool: *std.Thread.Pool = try alloc.create(std.Thread.Pool);
    try std.Thread.Pool.init(pool, .{ .allocator = alloc, .n_jobs = 16 });
    const dat = try dec.parse_tile(alloc, tile);
    const sfc = try render_mtex(alloc, pool, 16, img_width, img_height, &dat);
    std.log.warn("hello", .{});
    pool.deinit();
    return sfc;
}

pub fn render_mtex(alloc: Allocator, pool: *std.Thread.Pool, parts: usize, img_width: usize, img_height: usize, dat: *const dec.LayerData) !z2d.Surface {
    const wg: *std.Thread.WaitGroup = try alloc.create(std.Thread.WaitGroup);
    defer alloc.destroy(wg);
    wg.* = std.Thread.WaitGroup{};
    wg.reset();
    const r, const g, const b, const a = DefaultColor.rgba();
    const sfc = try z2d.Surface.initPixel(.{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } }, alloc, @intCast(img_width), @intCast(img_height));
    const scale: f32 = @floatFromInt(img_width);
    for (0..parts) |xi| {
        var pixels: []z2d.pixel.RGBA = undefined;
        const y_delta = (img_height / parts) * img_width;
        if (xi == parts - 1) {
            pixels = sfc.image_surface_rgba.buf[xi * y_delta ..];
        } else {
            pixels = sfc.image_surface_rgba.buf[xi * y_delta .. (xi + 1) * y_delta];
        }
        const yoff: f32 = @floatFromInt(xi * (img_height / parts));
        pool.spawnWg(wg, render_part, .{
            std.testing.allocator,
            pixels,
            img_width,
            z2d.pixel.RGBA{ .r = r, .g = g, .b = b, .a = a },
            scale,
            dat,
            0,
            -yoff,
        });
    }
    pool.waitAndWork(wg);
    return sfc;
}

pub fn get_pixel_rgba(self: *z2d.Surface, x: usize, y: usize) struct { u8, u8, u8, u8 } {
    const px = self.getPixel(@intCast(x), @intCast(y)).?.rgba;
    return .{ px.r, px.g, px.b, px.a };
}

fn leipzig_new_york_rendering(comptime zoom_level: struct { comptime_int, comptime_int }) !void {
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const width_height = 1920;
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
            const output_subpath = "./output/" ++ zoom_str ++ ".png";
            std.log.warn("render: {s} to {s}", .{ tile_subpath, output_subpath });
            var file = try std.fs.cwd().openFile(tile_subpath, .{});
            const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
            time.reset();
            const tile: dec.Tile = try dec.decode(input, alloc);
            // std.log.warn("time decoding: {d:.3} ms", .{time.lap() / 1_000_000});
            time.reset();
            const sfc = try render_tile_leaky_mt(alloc, width_height, width_height, &tile);
            // const sfc = try render_tile_leaky(alloc, width_height, width_height, 0, -500, &tile);
            std.log.warn("time rendering: {d:.3} ms", .{time.lap() / 1_000_000});
            try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
            _ = arena.reset(.retain_capacity);
            // std.log.warn("time png: {d:.3} ms", .{time.lap() / 1_000_000});
        }
    }
}

test "single threaded" {
    var timer = std.time.Timer.start() catch unreachable;
    try leipzig_new_york_rendering(.{ 10, 11 });
    std.debug.print("\n\n\nrenderer 2 time: {} ms", .{timer.read() / 1_000_000});
}

fn test_render_all_zoom() !void {
    if (false) return;
    const gpa = std.testing.allocator;
    std.fs.cwd().makeDir("output") catch {};

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
