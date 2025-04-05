const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const fmt = std.debug.print;
const io = std.io;
const print = std.debug.print;
const Request = std.http.Client.Request;

// returns allocated URI Request (caller owns memory!)
pub fn http_json_api_to_T_leaky(T: type, alc: Allocator, uri: std.Uri) !T {
    var client = std.http.Client{ .allocator = alc };
    const server_header_buffer: []u8 = try alc.alloc(u8, 1024 * 8);
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = server_header_buffer,
    });
    try req.send();
    try req.finish();
    try req.wait();

    const body = try req.reader().readAllAlloc(alc, 1024 * 64);
    return try std.json.parseFromSliceLeaky(T, alc, body, .{ .ignore_unknown_fields = true });
}

fn print_request_header_status_and_body(req: *Request) !void {
    print("Response status: {d}\n\n", .{req.response.status});
    // Print out the headers (iterate)
    var it = req.response.iterateHeaders();
    while (it.next()) |header| {
        print("{s}: {s}\n", .{ header.name, header.value });
    }

    // Read the entire response body, but only allow it to allocate 1024 * 8 of memory.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alc = gpa.allocator();
    defer _ = gpa.deinit();
    const body = try req.reader().readAllAlloc(alc, 1024 * 64);
    defer alc.free(body);

    // Print out the body.
    print("\nBODY \n\n{s}", .{body});
}

pub fn into_multi_array_list(T: type, allocator: Allocator, slice: []const T) !std.MultiArrayList(T) {
    var arrl = std.MultiArrayList(T){};
    try arrl.ensureTotalCapacity(allocator, slice.len);
    for (slice) |k| {
        arrl.appendAssumeCapacity(k);
    }
    return arrl;
}

const json = std.json;

pub fn write_serialized_T(T: type, allocator: Allocator, path_from_cwd: []const u8, data: T) !void {
    var list = std.ArrayList(u8).init(allocator);
    try std.json.stringify(data, .{}, list.writer());
    const path = std.fs.cwd();
    try path.writeFile(.{ .data = list.items[0..list.items.len], .sub_path = path_from_cwd });
}

pub fn debug_struct(value: anytype) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    // std.builtin.Type;
    if (info != .@"struct") {
        @compileError("Expected a struct type");
    }

    inline for (info.@"struct".fields) |field| {
        const v = @field(value, field.name);
        const vT = @TypeOf(v);
        const vTinfo: std.builtin.Type = @typeInfo(vT);
        // std.debug.print("{}", .{vTinfo});
        switch (vTinfo) {
            .pointer => {
                const d = vTinfo.pointer;
                if (d.is_const and d.child == u8) {
                    std.debug.print("{s}: {s}\n", .{ field.name, v });
                } else {
                    std.debug.print("{s}: *some pointer...\n", .{ field.name, v });
                }
            },
            else => {
                std.debug.print("{s}: {any}\n", .{ field.name, v });
            },
        }
    }
}
