const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");

pub const RgbaCol = struct {
    rgba: [4]u8 = std.mem.zeroes([4]u8),
    pub const red = RgbaCol{ .rgba = .{ 255, 0, 0, 0 } };
    pub const green = RgbaCol{ .rgba = .{ 0, 255, 0, 0 } };
    pub const yellow = RgbaCol{ .rgba = .{ 255, 255, 0, 0 } };
    pub fn from_hex(comptime hex: []const u8) RgbaCol {
        const rgba = comptime hexToRgb(hex) catch {
            @compileError("failed to convert rgba from hex code");
        };
        return RgbaCol{ .rgba = rgba };
    }
    fn hexToRgb(hex: []const u8) ![4]u8 {
        if (hex.len != 6) return error.HexColorCodeWrongLen;
        var rgba: [4]u8 = undefined;
        for (rgba[0..3], 0..) |_, i| {
            const start = i * 2;
            const slice = hex[start .. start + 2];
            const value = try std.fmt.parseInt(u8, slice, 16);
            rgba[i] = value;
        }
        rgba[3] = 255;
        return rgba;
    }
};
// nature-inspired https://www.color-hex.com/color-palette/1040990
const NatureHex = struct {
    const gray = "d1dad6";
    const green = "b9cc98";
    const dark_green = "758d80";
    const ocker = "d3bfa0";
    const brown = "9e7d5a";
};
// aquatic-dunn-edwards https://www.color-hex.com/color-palette/1031772
const AquaticHex = struct {
    const white = "e5eff1";
    const light_gray = "99c1c8";
    const light_blue = "66a2ad";
    const blue = "328392";
    const dark_blue = "006477";
};
// street https://www.color-hex.com/color-palette/6270
const GrayHex = struct {
    const white_gray = "c4c4c4";
    const light_gray = "b3b3b3";
    const gray = "828282";
    const dark_gray = "5f5f5f";
    const black = "343434";
};

const ColorPalette = struct {
    const green: RgbaCol = .green;
    const yellow: RgbaCol = .yellow;
    const red: RgbaCol = .red;
};

pub const LandCoverColorDef = struct {
    pub const green: []const []const u8 = &.{
        "farmland",
        "ice",
        "wood",
        "rock",
        "grass",
        "wetland",
        "sand",
    };
    pub const red: []const []const u8 = &.{};
};

pub fn color_attribute_mapper(definition: anytype, colorpalette: anytype, key: []const u8) ?RgbaCol {
    switch (@typeInfo(definition)) {
        .@"struct" => |st| {
            const decls = st.decls;
            inline for (decls) |dcl| {
                const col: RgbaCol = @field(colorpalette, dcl.name);
                const keys: []const []const u8 = comptime @field(definition, dcl.name);
                inline for (keys) |keystr| {
                    if (std.mem.eql(u8, keystr, key)) {
                        return col;
                    }
                }
            }
            return null;
        },
        else => @compileError("definition must be of struct form"),
    }
}

test "color attribute mapper" {
    if (color_attribute_mapper(LandCoverColorDef, ColorPalette, "farmland")) |col| {
        std.log.warn("rgb {any}", .{col});
    }
}
