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
fn render_part(
    gpa: Allocator,
    pixels: []z2d.pixel.RGBA,
    width: usize,
    initial_px: z2d.pixel.RGBA,
    scale: f32,
    dat: *const dec.LayerData,
    offsetx: f32,
    offsety: f32,
    render_fnc: *const fn (
        *z2d.Context,
        *const dec.LayerData,
        f32,
        f32,
        f32,
    ) anyerror!void,
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
    render_fnc(
        &ctx,
        dat,
        scale,
        offsetx,
        offsety,
    ) catch {};
}
pub fn render_tile_leaky_mt(
    alloc: Allocator,
    img_width: usize,
    img_height: usize,
    tile: *const Tile,
    default_color: struct { u8, u8, u8, u8 },
    render_fnc: *const fn (
        *z2d.Context,
        *const dec.LayerData,
        f32,
        f32,
        f32,
    ) anyerror!void,
) !z2d.Surface {
    const pool: *std.Thread.Pool = try alloc.create(std.Thread.Pool);
    try std.Thread.Pool.init(pool, .{ .allocator = alloc, .n_jobs = 16 });
    const dat = try dec.parse_tile(alloc, tile);
    const r, const g, const b, const a = default_color;
    var sfc = try z2d.Surface.initPixel(.{ .rgba = .{ .r = r, .g = g, .b = b, .a = a } }, alloc, @intCast(img_width), @intCast(img_height));
    try render_mtex(
        alloc,
        pool,
        &sfc,
        16,
        img_width,
        img_height,
        &dat,
        default_color,
        render_fnc,
    );
    std.log.warn("hello", .{});
    pool.deinit();
    return sfc;
}

pub fn render_mtex(
    alloc: Allocator,
    pool: *std.Thread.Pool,
    sfc: *z2d.Surface,
    parts: usize,
    img_width: usize,
    img_height: usize,
    dat: *const dec.LayerData,
    default_color: struct { u8, u8, u8, u8 },
    render_fnc: *const fn (
        *z2d.Context,
        *const dec.LayerData,
        f32,
        f32,
        f32,
    ) anyerror!void,
) !void {
    const wg: *std.Thread.WaitGroup = try alloc.create(std.Thread.WaitGroup);
    defer alloc.destroy(wg);
    wg.* = std.Thread.WaitGroup{};
    wg.reset();
    const r, const g, const b, const a = default_color;
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
            render_fnc,
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
            const coldef = Color.from_hex(Tailwind.lime200);
            const sfc = try render_tile_leaky_mt(alloc, width_height, width_height, &tile, coldef.rgba(), root.Renderer.render_all);
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
