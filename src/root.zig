const std = @import("std");

pub const Image = @import("common/img2d.zig");
pub const decoder = @import("decode/tile-decoder.zig");
pub const maptiler = @import("decode/maptiler.zig");
pub const Renderer = @import("render/renderer1.zig");
pub const Color = @import("render/color.zig");
pub const thickness = @import("render/thickness.zig");
pub const Tailwind = @import("tailwind");

test "all" {
    _ = .{Renderer};
}
