const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
pub const Env = @import("dotenv");

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

    var url_buffer: [1024]u8 = undefined;
    const url_str = try std.fmt.bufPrint(
        &url_buffer,
        "https://api.maptiler.com/tiles/v3/{}/{}/{}.pbf?key={s}",
        .{ zoom, x, y, api_key },
    );
    // std.log.warn("url req: {s}", .{url_str});
    var server_header_buffer: [1024]u8 = undefined;
    const url = try std.Uri.parse(url_str);
    var req = try client.open(.GET, url, .{
        .server_header_buffer = &server_header_buffer,
    });
    defer req.deinit();
    try req.send();
    try req.wait();
    std.log.warn("{}", .{req.response.status});
    const body = try req.reader().readAllAlloc(allocator, 10 * 1024 * 1024); // 10 MB limit
    return body;
}

fn debug_write_tile(
    lat: comptime_float,
    lon: comptime_float,
    zoom: comptime_int,
    api_key: []const u8,
    dir: std.fs.Dir,
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

// NOTE: zoom level on maptiler is ok from 0 to 15
test "download tile 2" {
    if (true) return;
    const alloc = std.testing.allocator;
    var env_file = try std.fs.cwd().openFile("src/decode/.env", .{});
    defer env_file.close();
    const env_content = try env_file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(env_content);
    var env = try Env.init(alloc, env_content);
    defer env.deinit();
    const api_key = env.get("maptiler_api_key");

    if (api_key) |key| {
        {
            // leipzig
            const city = "leipzig";
            const lat = 51.34;
            const lon = 12.36;
            inline for (0..16) |zoom| {
                const name = std.fmt.comptimePrint(city ++ "_z{}", .{zoom});
                try debug_write_tile(lat, lon, zoom, key, std.fs.cwd(), "testdata/" ++ name);
            }
        }
        {
            // new york jfk airport
            const city = "new_york";
            const lat = 40.64;
            const lon = -73.79;
            inline for (0..16) |zoom| {
                const name = std.fmt.comptimePrint(city ++ "_z{}", .{zoom});
                try debug_write_tile(lat, lon, zoom, key, std.fs.cwd(), "testdata/" ++ name);
            }
        }
    }
}
test "download tile" {
    // const lat = 51.34;
    // const lon = 12.36;
    try download_failing_tile();
}

fn download_failing_tile() !void {
    if (true) return;
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    var env_file = try std.fs.cwd().openFile("src/decode/.env", .{});
    defer env_file.close();
    const env_content = try env_file.readToEndAlloc(alloc, 1024 * 1024);
    var env = try Env.init(alloc, env_content);
    const api_key = env.get("maptiler_api_key").?;
    // warning: x: 136, y: 84, z: 8 from cache
    // warning: x: 136, y: 85, z: 8 from cache
    // warning: x: 137, y: 84, z: 8 from cache
    // warning: x: 137, y: 85, z: 8 from cache
    const x = 136;
    const y = 85;
    const z = 8;
    var file = try std.fs.cwd().createFile("testdata/failing_x136_y85_z8", .{});
    defer file.close();
    const dat = try downloadTile(alloc, x, y, z, api_key);
    try file.writeAll(dat);
}
