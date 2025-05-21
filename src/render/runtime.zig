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
const common = root.common;

pub const RenderContext = struct {
    initial_px: common.z2dRGBA,
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
    var ssfc = z2d.Surface.initBuffer(
        .image_surface_rgba,
        rctx.initial_px,
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
    parts: comptime_int,
) !z2d.Surface {
    var time = std.time.Timer.start() catch unreachable;
    const pool: *std.Thread.Pool = try alloc.create(std.Thread.Pool);
    defer alloc.destroy(pool);
    try std.Thread.Pool.init(pool, .{ .allocator = alloc, .n_jobs = parts });
    var sfc = try z2d.Surface.initPixel(.{ .rgba = rctx.initial_px }, alloc, @intCast(img_width), @intCast(img_height));
    time.reset();
    try render_mtex(alloc, pool, &sfc, parts, rctx);
    std.debug.print("time rendering: {d:.3} ms", .{time.read() / 1_000_000});
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
    const width_height = 2600;
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
            const coldef = Color.from_hex(Tailwind.lime200);
            const rctx = RenderContext{
                .dat = try dec.parse_tile(alloc, &tile),
                .initial_px = common.col_to_z2d_pixel_rgb(coldef),
                .offsetx = 0,
                .offsety = 0,
                .render_fnc = root.Renderer.render_all,
                .scale = @floatFromInt(width_height),
            };
            var sfc = try render_tile_mt(arena.child_allocator, width_height, width_height, rctx, 1);
            defer sfc.deinit(arena.child_allocator);

            // std.debug.print("time rendering: {d:.3} ms", .{time.lap() / 1_000_000});
            try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
            _ = arena.reset(.retain_capacity);
        }
    }
}
test "single threaded" {
    // if (true) return;
    try leipzig_new_york_rendering(.{ 10, 11 });
}

test "kkkjll" {
    // if (true) return;
    std.log.warn("multi threaded:", .{});
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const width_height = 2600;
    const render_list: []const []const u8 = &.{
        "leipzig",
        "new_york",
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
        const coldef = Color.from_hex(Tailwind.lime200);
        const rctx = RenderContext{
            .dat = try dec.parse_tile(alloc, &tile),
            .initial_px = common.col_to_z2d_pixel_rgb(coldef),
            .offsetx = 0,
            .offsety = 0,
            .render_fnc = root.Renderer.render_all,
            .scale = @floatFromInt(width_height),
        };
        var sfc = try render_tile_mt(arena.child_allocator, width_height, width_height, rctx, 16);
        defer sfc.deinit(arena.child_allocator);

        // const sfc = try render_tile_leaky(alloc, width_height, width_height, 0, -500, &tile);
        std.debug.print("time rendering (mt): {d:.3} ms", .{time.lap() / 1_000_000});
        try z2d.png_exporter.writeToPNGFile(sfc, output_subpath, .{});
        _ = arena.reset(.retain_capacity);
        // std.log.warn("time png: {d:.3} ms", .{time.lap() / 1_000_000});
    }
}
