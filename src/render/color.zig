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
    /// accepts "FF00FF" or "#FF00FF" or "#ff00ff"
    pub fn from_hex(comptime hex: []const u8) RgbaCol {
        const rgba = comptime hexToRgb(hex) catch {
            @compileError("failed to convert rgba from hex code");
        };
        return RgbaCol{ .rgba = rgba };
    }
    /// for easy tuple destructuring
    pub fn rgb(self: *const RgbaCol) struct { u8, u8, u8 } {
        const arr = self.rgba;
        return .{ arr[0], arr[1], arr[2] };
    }
    fn hexToRgb(hex: []const u8) ![4]u8 {
        if (hex[0] == '#') return hexToRgb(hex[1..]);
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

pub const LandCoverPallete = struct {
    pub const dark_green = Nature.green;
    pub const green = Nature.dark_green;
    pub const yellow = Nature.ocker;
    pub const brown = Nature.brown;
    pub const white = Aquatic.white;
    pub const gray = Gray.light_gray;
};

pub const LandCoverColorMap = struct {
    pub const white = &.{
        "ice",
    };
    pub const gray = &.{
        "rock",
    };
    pub const dark_green = &.{
        "wood",
    };
    pub const green = &.{
        "grass",
    };
    pub const yellow = &.{
        "sand",
    };
    pub const brown = &.{
        "wetland",
        "farmland",
    };
};

/// decls of the definition struct must match any decls of colorpalette struct
/// type of the colorpallete decls is RgbaCol or a hex string
/// NOTE: not sure if the decls must be pub but that could be
pub fn color_attribute_mapper(definition: anytype, colorpalette: anytype, key: []const u8) ?RgbaCol {
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

test "color attribute mapper" {
    if (color_attribute_mapper(LandCoverColorMap, LandCoverPallete, "farmland")) |col| {
        std.log.warn("rgb {any}", .{col});
    }
}
