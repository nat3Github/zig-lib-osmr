const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

pub fn latLonToTile(lat_deg: f64, lon_deg: f64, zoom: u32) struct { x: u32, y: u32 } {
    const lat_rad = lat_deg * math.pi / 180.0;
    const n = math.pow(f64, 2, @floatFromInt(zoom));
    const x = math.floor((lon_deg + 180.0) / 360.0 * n);
    const y = math.floor((1.0 - math.log(f64, math.e, math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n);
    return .{ .x = @intFromFloat(x), .y = @intFromFloat(y) };
}

pub fn downloadTile(
    allocator: Allocator,
    x: u32,
    y: u32,
    zoom: u32,
    api_key: []const u8,
) ![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var url_buffer: [256]u8 = undefined;
    const url_str = try std.fmt.bufPrint(
        &url_buffer,
        "https://api.maptiler.com/tiles/v3/{d}/{d}/{d}.pbf?key={s}",
        .{ zoom, x, y, api_key },
    );
    var server_header_buffer: [1024]u8 = undefined;
    const url = try std.Uri.parse(url_str);
    var req = try client.open(.GET, url, .{
        .server_header_buffer = &server_header_buffer,
    });
    defer req.deinit();
    try req.send();
    try req.wait();
    const body = try req.reader().readAllAlloc(allocator, 10 * 1024 * 1024); // 10 MB limit

    return body;
}

fn debug_write_tile(
    lat: comptime_float,
    lon: comptime_float,
    zoom: comptime_int,
    api_key: []const u8,
    dir: *std.fs.Dir,
    sub_path: []const u8,
) !void {
    const balloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(balloc);
    defer arena.deinit();
    const alloc = arena.allocator();
    const xy = latLonToTile(lat, lon, zoom);
    const data = try downloadTile(alloc, xy.x, xy.y, zoom, api_key);
    var file = try dir.createFile(sub_path, .{});
    try file.writeAll(data);
    defer file.close();
}


test "download tile" {
    // const balloc = std.testing.allocator;
    // var arena = std.heap.ArenaAllocator.init(balloc);
    // defer arena.deinit();
    // const alloc = arena.allocator();
    // const lat = 51.34;
    // const lon = 12.36;
    // const zoom = 14;
    // const xy = latLonToTile(lat, lon, zoom);
    // const api_key = "kNlMrTKeak26oPcu5Upx";
    // const data = try downloadTile(alloc, xy.x, xy.y, zoom, api_key);
    // const cwd = std.fs.cwd();
    // var file = try cwd.createFile("./testdata/leipzig_tile", .{});
    // try file.writeAll(data);
    // defer file.close();
}
