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
    color: ?Color = null,
    dotted: bool = false,
    line_width: f32 = 2,
    outline: ?Color = null,
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
    dont_fill: bool,
) !void {
    const w: f32 = scale;
    // std.log.warn("\n\n", .{});
    if (dotted) {
        // std.log.warn(
        //     \\ctx.setDashes(&.{{ 10, 7 }});
        // , .{});
        // ctx.setDashes(&.{ 10, 7 });
    } else ctx.setDashes(&.{});
    const r, const g, const b = col.to_rgb_tuple();
    ctx.setSourceToPixel(.{ .rgb = .{ .r = r, .g = g, .b = b } });
    ctx.setLineWidth(line_width);
    // std.log.warn(
    //     \\ctx.setLineWidth({d:.3});
    // , .{line_width});
    {
        const x, const y = clipped_data[0];
        const dx = x * w + offset_x;
        const dy = y * w + offset_y;
        try ctx.moveTo(dx, dy);
        // std.log.warn("try ctx.moveTo({d:.3},{d:.3});", .{ dx, dy });
    }
    for (clipped_data[1..]) |d| {
        const x, const y = d;
        const dx = x * w + offset_x;
        const dy = y * w + offset_y;
        try ctx.lineTo(dx, dy);
        // std.log.warn("try ctx.lineTo({d:.3},{d:.3});", .{ dx, dy });
    }
    switch (action) {
        .close_fill => {
            try ctx.closePath();
            if (dont_fill) {
                try ctx.stroke();
            } else {
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
