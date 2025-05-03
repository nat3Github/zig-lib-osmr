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
const Color = root.Color;
const Tailwind = @import("tailwind");

pub const RenderContext = struct {
    initial_px: struct { u8, u8, u8, u8 },
    scale: f32,
    dat: dec.LayerData,
    offsetx: f32,
    offsety: f32,
    render_fnc: *const fn (
        *z2d.Context,
        *const dec.LayerData,
        f32,
        f32,
        f32,
    ) anyerror!void,
};

fn render_part(
    gpa: Allocator,
    pixels: []z2d.pixel.RGBA,
    width: usize,
    rctx: RenderContext,
) void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    const r, const g, const b, const a = rctx.initial_px;
    var ssfc = z2d.Surface.initBuffer(
        .image_surface_rgba,
        z2d.pixel.RGBA{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        },
        pixels,
        @intCast(width),
        @intCast(pixels.len / width),
    );
    var ctx = z2d.Context.init(alloc, &ssfc);
    rctx.render_fnc(
        &ctx,
        &rctx.dat,
        rctx.scale,
        rctx.offsetx,
        rctx.offsety,
    ) catch |e| {
        std.log.err("{}", .{e});
    };
}

/// use a general purpose allocator and free the Surface yourself
pub fn render_tile_mt(
    alloc: Allocator,
    img_width: usize,
    img_height: usize,
    rctx: RenderContext,
) !z2d.Surface {
    const parts = 16;
    const pool: *std.Thread.Pool = try alloc.create(std.Thread.Pool);
    defer alloc.destroy(pool);
    try std.Thread.Pool.init(pool, .{ .allocator = alloc, .n_jobs = parts });
    const r, const g, const b, const a = rctx.initial_px;
    var sfc = try z2d.Surface.initPixel(.{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } }, alloc, @intCast(img_width), @intCast(img_height));
    try render_mtex(alloc, pool, &sfc, parts, rctx);
    pool.deinit();
    return sfc;
}

pub fn render_mtex(
    alloc: Allocator,
    pool: *std.Thread.Pool,
    sfc: *z2d.Surface,
    parts: usize,
    rctx: RenderContext,
) !void {
    const wg: *std.Thread.WaitGroup = try alloc.create(std.Thread.WaitGroup);
    defer alloc.destroy(wg);
    wg.* = std.Thread.WaitGroup{};
    wg.reset();
    for (0..parts) |xi| {
        var rctx2 = rctx;
        var pixels: []z2d.pixel.RGBA = undefined;
        const img_height: usize = @intCast(sfc.getHeight());
        const img_width: usize = @intCast(sfc.getWidth());
        const y_delta = (img_height / parts) * img_width;
        if (xi == parts - 1) {
            pixels = sfc.image_surface_rgba.buf[xi * y_delta ..];
        } else {
            pixels = sfc.image_surface_rgba.buf[xi * y_delta .. (xi + 1) * y_delta];
        }
        const yoff: f32 = @floatFromInt(xi * (img_height / parts));
        rctx2.offsety += -yoff;
        pool.spawnWg(wg, render_part, .{
            alloc,
            pixels,
            img_width,
            rctx2,
        });
    }
    pool.waitAndWork(wg);
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
            const coldef = Color.Transparent;
            const rctx = RenderContext{
                .dat = try dec.parse_tile(alloc, &tile),
                .initial_px = coldef.to_rgba_tuple(),
                .offsetx = 0,
                .offsety = 0,
                .render_fnc = root.RendererTranslucent.render_all,
                .scale = @floatFromInt(width_height),
            };
            var sfc = try render_tile_mt(arena.child_allocator, width_height, width_height, rctx);
            defer sfc.deinit(arena.child_allocator);

            // const sfc = try render_tile_leaky(alloc, width_height, width_height, 0, -500, &tile);
            std.log.warn("time rendering: {d:.3} ms", .{time.lap() / 1_000_000});
            try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
            _ = arena.reset(.retain_capacity);
            // std.log.warn("time png: {d:.3} ms", .{time.lap() / 1_000_000});
        }
    }
}
test "single threaded" {
    // if (true) return;
    var timer = std.time.Timer.start() catch unreachable;
    try leipzig_new_york_rendering(.{ 10, 11 });
    std.debug.print("\n\n\nrenderer 2 time: {} ms", .{timer.read() / 1_000_000});
}
test "bug?" {
    if (true) return;
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var sfc = try z2d.Surface.init(.image_surface_rgba, alloc, 1024, 1024);
    var ctx = z2d.Context.init(alloc, &sfc);

    ctx.setDashes(&.{ 10, 7 });
    ctx.setLineWidth(2);
    try ctx.moveTo(155.156, 86.250);
    try ctx.lineTo(154.688, 84.375);
    try ctx.lineTo(154.688, 83.438);
    try ctx.lineTo(162.188, 82.500);
    try ctx.lineTo(163.594, 89.063);
    try ctx.lineTo(160.313, 88.125);
    try ctx.lineTo(159.844, 89.531);
    try ctx.lineTo(154.219, 89.063);
    try ctx.lineTo(154.219, 90.000);
    try ctx.lineTo(148.594, 87.656);
    try ctx.closePath();
    try ctx.stroke();
}
test "bug ?" {
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var sfc = try z2d.Surface.init(.image_surface_rgba, alloc, 1920, 1920);
    var ctx = z2d.Context.init(alloc, &sfc);
    ctx.setSourceToPixel(.{ .rgba = .{ .r = 214, .g = 214, .b = 214, .a = 180 } });
    ctx.setLineWidth(1.000);
    try ctx.moveTo(329.531, 644.063);
    try ctx.lineTo(328.594, 650.156);
    try ctx.lineTo(325.781, 662.813);
    try ctx.lineTo(321.094, 667.969);
    try ctx.lineTo(308.438, 673.125);
    try ctx.lineTo(302.813, 673.125);
    try ctx.lineTo(298.125, 671.250);
    try ctx.lineTo(294.844, 668.438);
    try ctx.lineTo(292.969, 663.750);
    try ctx.lineTo(291.563, 637.500);
    try ctx.lineTo(293.906, 629.531);
    try ctx.lineTo(297.656, 625.781);
    try ctx.lineTo(303.750, 622.969);
    try ctx.lineTo(309.375, 622.969);
    try ctx.lineTo(314.531, 625.313);
    try ctx.lineTo(328.594, 640.781);
    try ctx.closePath();
    try ctx.fill();
}

test "kkkjll" {
    if (true) return;
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const width_height = 1920;
    const render_list: []const []const u8 = &.{
        "leipzig",
    };
    var time = std.time.Timer.start() catch unreachable;
    inline for (render_list) |city| {
        const alloc = arena.allocator();
        const zoom_str = city ++ std.fmt.comptimePrint("_z{}", .{10});
        const tile_subpath = "./testdata/" ++ zoom_str;
        const output_subpath = "./output/kkkk" ++ zoom_str ++ ".png";
        std.log.warn("render: {s} to {s}", .{ tile_subpath, output_subpath });
        var file = try std.fs.cwd().openFile(tile_subpath, .{});
        const input = try file.reader().readAllAlloc(alloc, 10 * 1024 * 1024);
        time.reset();
        const tile: dec.Tile = try dec.decode(input, alloc);
        // std.log.warn("time decoding: {d:.3} ms", .{time.lap() / 1_000_000});
        time.reset();
        const coldef = Color.Transparent;
        const rctx = RenderContext{
            .dat = try dec.parse_tile(alloc, &tile),
            .initial_px = coldef.to_rgba_tuple(),
            .offsetx = 0,
            .offsety = 0,
            .render_fnc = root.RendererTranslucent.render_all,
            .scale = @floatFromInt(width_height),
        };
        var sfc = try render_tile_mt(arena.child_allocator, width_height, width_height, rctx);
        defer sfc.deinit(arena.child_allocator);

        // const sfc = try render_tile_leaky(alloc, width_height, width_height, 0, -500, &tile);
        std.log.warn("time rendering: {d:.3} ms", .{time.lap() / 1_000_000});
        try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
        _ = arena.reset(.retain_capacity);
        // std.log.warn("time png: {d:.3} ms", .{time.lap() / 1_000_000});
    }
}
