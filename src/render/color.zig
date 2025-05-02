const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");

pub const RgbaCol = @This();
rgba_arr: [4]u8 = std.mem.zeroes([4]u8),
pub const red = RgbaCol{ .rgba_arr = .{ 255, 0, 0, 255 } };
pub const green = RgbaCol{ .rgba_arr = .{ 0, 255, 0, 255 } };
pub const yellow = RgbaCol{ .rgba_arr = .{ 255, 255, 0, 255 } };
pub const transparent = RgbaCol{ .rgba_arr = .{ 0, 0, 0, 0 } };
/// accepts "FF00FF" or "#FF00FF" or "#ff00ff"
pub fn from_hex(comptime hex: []const u8) RgbaCol {
    const xrgba = comptime hexToRgb(hex) catch {
        @compileError("failed to convert rgba from hex code");
    };
    return RgbaCol{ .rgba_arr = xrgba };
}
pub fn convert_hex(hex: []const u8) !RgbaCol {
    const xrgba = try hexToRgb(hex);
    return RgbaCol{ .rgba_arr = xrgba };
}
inline fn hexToRgb(hex: []const u8) ![4]u8 {
    var xrgba: [4]u8 = .{ 0, 0, 0, 255 };
    if (hex.len == 6) {
        for (xrgba[0..3], 0..) |_, i| {
            const start = i * 2;
            const slice = hex[start .. start + 2];
            const value = try std.fmt.parseInt(u8, slice, 16);
            xrgba[i] = value;
        }
        return xrgba;
    }
    if (hex.len == 7 and hex[0] == '#') {
        const hex1 = hex[1..];
        for (xrgba[0..3], 0..) |_, i| {
            const start = i * 2;
            const slice = hex1[start .. start + 2];
            const value = try std.fmt.parseInt(u8, slice, 16);
            xrgba[i] = value;
        }
        return xrgba;
    }
    return error.FailedToParseHexColor;
}
/// for easy tuple destructuring
pub fn rgb(self: *const RgbaCol) struct { u8, u8, u8 } {
    const arr = self.rgba_arr;
    return .{ arr[0], arr[1], arr[2] };
}
pub fn rgba(self: *const RgbaCol) struct { u8, u8, u8, u8 } {
    const arr = self.rgba_arr;
    return .{ arr[0], arr[1], arr[2], arr[3] };
}
pub fn eql(self: *const RgbaCol, other: RgbaCol) bool {
    return std.mem.eql(u8, &self.rgba_arr, &other.rgba_arr);
}

// nature-inspired https://www.color-hex.com/color-palette/1040990
pub const Nature = struct {
    pub const gray = "#d1dad6";
    pub const green = "#b9cc98";
    pub const dark_green = "#758d80";
    pub const ocker = "#d3bfa0";
    pub const brown = "#9e7d5a";
};
// aquatic-dunn-edwards https://www.color-hex.com/color-palette/1031772
pub const Aquatic = struct {
    pub const white = "#e5eff1";
    pub const light_gray = "#99c1c8";
    pub const light_blue = "#66a2ad";
    pub const blue = "#328392";
    pub const dark_blue = "#006477";
};
// street https://www.color-hex.com/color-palette/6270
pub const Gray = struct {
    pub const white_gray = "#c4c4c4";
    pub const light_gray = "#b3b3b3";
    pub const gray = "#828282";
    pub const dark_gray = "#5f5f5f";
    pub const black = "#343434";
};

// trees and nature https://www.color-hex.com/color-palette/89702
pub const TreesAndNature = struct {
    pub const light_white = "#ffffff";
    pub const white = "#f4f1e9";
    pub const light_green = "#b1d182";
    pub const olive_green = "#688f4e";
    pub const dark_green = "#2b463c";
};
// deep red https://www.color-hex.com/color-palette/9293
pub const DeepRed = struct {
    pub const red900 = "#960000";
    pub const red800 = "#ae0000";
    pub const red700 = "#c70000";
    pub const red600 = "#e10000";
    pub const red500 = "#ff0000";
};
// minimalist very dark purple https://www.color-hex.com/color-palette/97197
pub const DarkPurple = struct {
    pub const purple900 = "#300030";
    pub const purple800 = "#480838";
    pub const purple700 = "#580838";
    pub const purple600 = "#600840";
    pub const purple500 = "#680840";
};

// green pallete https://www.color-hex.com/color-palette/30573
pub const Green = struct {
    pub const ocker = "#ececa3";
    pub const grass = "#b5e550";
    pub const yellow_grass = "#abc32f";
    pub const olive = "#809c13";
    pub const dark_olive = "#607c3c";
};

/// decls of the definition struct must match any decls of colorpalette struct
/// type of the colorpallete decls is RgbaCol or a hex string
/// NOTE: the decls of definition must be set to pub! otherwise it matches nothing
pub fn color_attribute_mapper(definition: anytype, colorpalette: anytype, key: []const u8) ?RgbaCol {
    @setEvalBranchQuota(2000);
    switch (@typeInfo(definition)) {
        .@"struct" => |st| {
            const decls = st.decls;
            inline for (decls) |dcl| {
                const Tfield = @field(colorpalette, dcl.name);
                const T = @TypeOf(Tfield);
                const col: RgbaCol = comptime switch (T) {
                    RgbaCol => Tfield,
                    else => blk: {
                        const str = Tfield;
                        break :blk RgbaCol.from_hex(str);
                    },
                };
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

pub fn ColorMap(Def: type, Pal: type) type {
    return struct {
        const This = @This();
        const def = Def;
        const pallete = Pal;
        pub fn map(key: []const u8) ?RgbaCol {
            return color_attribute_mapper(This.def, This.pallete, key);
        }
    };
}

test "color attribute mapper" {
    const COl = struct {
        pub const dark_green = TreesAndNature.dark_green;
        pub const green = TreesAndNature.light_green; //Green.grass;
        pub const yellow = Nature.ocker;
        pub const brown = Nature.brown;
        pub const white = Aquatic.white;
        pub const gray = Gray.light_gray;
    };
    const KeyMap = struct {
        pub const white = &.{"ice"};
        pub const gray = &.{"rock"};
        pub const dark_green = &.{"wood"};
        pub const green = &.{"grass"};
        pub const yellow = &.{"sand"};
        pub const brown = &.{ "wetland", "farmland" };
    };
    const Col = ColorMap(KeyMap, COl);
    if (Col.map("farmland")) |col| {
        try expect(col.eql(from_hex(Nature.brown)));
    }
}
pub const LandCoverColors = struct {
    pub const dark_green = TreesAndNature.dark_green;
    pub const green = TreesAndNature.light_green; //Green.grass;
    pub const yellow = Nature.ocker;
    pub const brown = Nature.brown;
    pub const white = Aquatic.white;
    pub const gray = Gray.light_gray;
};
