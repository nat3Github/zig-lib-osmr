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

pub fn get_pixel_rgba(self: *z2d.Surface, x: usize, y: usize) struct { u8, u8, u8, u8 } {
    const px = self.getPixel(@intCast(x), @intCast(y)).?.rgba;
    return .{ px.r, px.g, px.b, px.a };
}
