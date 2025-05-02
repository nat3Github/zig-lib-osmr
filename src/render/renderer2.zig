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
            .color = common_color.aeroway_color(meta),
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
            .color = .from_hex(Tailwind.green300),
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
    scale: f32,
    offset_x: f32,
    offset_y: f32,
) !void {
    return com.render_all(ctx, data, rend2config, scale, offset_x, offset_y);
}
pub const DefaultColor = Color.from_hex(Tailwind.lime200);

pub fn get_pixel_rgba(self: *z2d.Surface, x: usize, y: usize) struct { u8, u8, u8, u8 } {
    const px = self.getPixel(@intCast(x), @intCast(y)).?.rgba;
    return .{ px.r, px.g, px.b, px.a };
}
