const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");

const correction_factor = 1.0;
pub const StandardSizes = struct {
    // pub const S = 1.0 * correction_factor;
    // pub const M = 1.5 * correction_factor;
    // pub const L = 2.0 * correction_factor;
    // pub const XL = 3.0 * correction_factor;
    // pub const XXL = 4.5 * correction_factor;
    pub const S = 1.0 * correction_factor;
    pub const M = 2.0 * correction_factor;
    pub const L = 3.5 * correction_factor;
    pub const XL = 5 * correction_factor;
    pub const XXL = 7.0 * correction_factor;
};

fn comptime_parse_float(comptime number: []const u8) f64 {
    return std.fmt.parseFloat(f64, number) catch |e| {
        @compileError(std.fmt.comptimePrint("{} form string {s}", .{
            e,
            number,
        }));
    };
}
pub fn num(comptime number: []const u8) f64 {
    var buf: [128]u8 = undefined;
    const upper = comptime std.ascii.upperString(&buf, number);
    const defsizes = @typeInfo(StandardSizes).@"struct".decls;
    inline for (defsizes) |dcl| {
        if (comptime std.mem.eql(u8, dcl.name, upper)) {
            return @field(StandardSizes, dcl.name);
        }
    }
    if (comptime std.ascii.isAlphabetic(number[0])) {
        return comptime_parse_float(number[1..]);
    } else return comptime_parse_float(number);
}

/// NOTE: the decls of definition must be set to pub! otherwise it matches nothing
pub fn line_width(comptime definition: anytype, key: []const u8) ?f64 {
    switch (@typeInfo(definition)) {
        .@"struct" => |st| {
            const decls = st.decls;
            inline for (decls) |dcl| {
                const col = comptime num(dcl.name);
                const keys: []const []const u8 = comptime @field(definition, dcl.name);
                inline for (keys) |s| {
                    if (std.mem.eql(u8, s, key)) {
                        return col;
                    }
                }
            }
            return null;
        },
        else => @compileError("definition must be of struct form"),
    }
}

test "thickness" {
    const TestDef = struct {
        pub const @"5" = &.{"ice"};
        pub const p15 = &.{"rock"};
        pub const xl = &.{"wood"};
    };
    try expect(line_width(TestDef, "no key") == null);
    try expect(line_width(TestDef, "ice").? == 5.0);
    try expect(line_width(TestDef, "rock").? == 15.0);
    try expect(line_width(TestDef, "wood").? == StandardSizes.XL);
}

fn slen(comptime a: []const []const u8, comptime b: []const []const u8) comptime_int {
    return a.len + b.len;
}
pub fn combine_list(comptime a: []const []const u8, comptime b: []const []const u8) [slen(a, b)][]const u8 {
    var buf: [slen(a, b)][]const u8 = undefined;
    inline for (a, 0..) |s, i| {
        buf[i] = s;
    }
    inline for (b, 0..) |s, i| {
        buf[i + a.len] = s;
    }
    return buf;
}
