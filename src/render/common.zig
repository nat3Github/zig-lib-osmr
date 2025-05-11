const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const z2d = root.z2d;
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
pub fn from_hex(comptime hex: []const u8) z2d.pixel.RGBA {
    const c = Color.from_hex(hex);
    return col_to_z2d_pixel_rgb(c);
}
pub const z2dRGBA = z2d.pixel.RGBA;

pub const FeatureDrawProperties = struct {
    color: ?z2dRGBA = null,
    dotted: bool = false,
    line_width: f32 = 2,
    outline: ?z2dRGBA = null,
};
fn log(comptime fmt: []const u8, args: anytype) void {
    if (false) {
        std.log.warn(fmt, args);
    }
}
pub fn col_to_z2d_pixel_rgb(col: Color) z2dRGBA {
    const r, const g, const b, const a = col.to_rgba_tuple();
    const rf: f32 = @as(f32, @floatFromInt(r)) / 255.0;
    const gf: f32 = @as(f32, @floatFromInt(g)) / 255.0;
    const bf: f32 = @as(f32, @floatFromInt(b)) / 255.0;
    const af: f32 = @as(f32, @floatFromInt(a)) / 255.0;
    return z2d.Pixel.fromColor(.{ .rgba = .{ rf, gf, bf, af } }).rgba;
}

inline fn context_draw(
    ctx: *z2d.Context,
    offset_x: f32,
    offset_y: f32,
    scale: f32,
    clipped_data: []const struct { f32, f32 },
    action: dec.DrawCmd.DrawType.Action,
    pixel: z2d.pixel.RGBA,
    line_width: f64,
    dotted: bool,
    dont_fill: bool,
) !void {
    const w: f32 = scale;
    log("\n\n", .{});
    if (dotted) {
        log(
            \\ctx.setDashes(&.{{ 10, 7 }});
        , .{});
        ctx.setDashes(&.{ 10, 7 });
    } else ctx.setDashes(&.{});
    log(
        \\ctx.setSourceToPixel({any});
    , .{pixel});
    ctx.setSourceToPixel(.{ .rgba = pixel });
    log(
        \\ctx.setLineWidth({d:.3});
    , .{line_width});
    ctx.setLineWidth(line_width);
    {
        const x, const y = clipped_data[0];
        const dx = x * w + offset_x;
        const dy = y * w + offset_y;
        log("try ctx.moveTo({d:.3},{d:.3});", .{ dx, dy });
        try ctx.moveTo(dx + 0.1, dy); // workaround for not correctly drawing closed paths with matching start and endpoint
    }
    for (clipped_data[1..]) |d| {
        const x, const y = d;
        const dx = x * w + offset_x;
        const dy = y * w + offset_y;
        log("try ctx.lineTo({d:.3},{d:.3});", .{ dx, dy });
        try ctx.lineTo(dx, dy);
    }
    switch (action) {
        .close_fill => {
            log(
                \\try ctx.closePath();
            , .{});
            try ctx.closePath();
            if (dont_fill) {
                log(
                    \\try ctx.stroke();
                , .{});
                try ctx.stroke();
            } else {
                log(
                    \\try ctx.fill();
                , .{});
                try ctx.fill();
            }
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

                    switch (daction) {
                        .close_fill => {
                            if (prop.color) |col| {
                                try context_draw(ctx, offset_x, offset_y, scale, dd, daction, col, prop.line_width, prop.dotted, false);
                            }
                            if (prop.outline) |col| {
                                try context_draw(ctx, offset_x, offset_y, scale, dd, daction, col, prop.line_width, prop.dotted, true);
                            }
                        },
                        else => {
                            if (prop.color) |col| {
                                try context_draw(ctx, offset_x, offset_y, scale, dd, daction, col, prop.line_width, prop.dotted, false);
                            }
                        },
                    }
                }
            }
        }
    }
}

pub fn get_pixel_rgba(self: *z2d.Surface, x: usize, y: usize) struct { u8, u8, u8, u8 } {
    const px = self.getPixel(@intCast(x), @intCast(y)).?.rgba;
    return .{ px.r, px.g, px.b, px.a };
}
