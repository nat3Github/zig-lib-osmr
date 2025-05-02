const std = @import("std");

pub const decoder = @import("decode/tile-decoder.zig");
pub const decoder2 = @import("decode/tile-decoder2.zig");
pub const maptiler = @import("decode/maptiler.zig");
pub const Renderer = @import("render/renderer1.zig");
pub const Renderer2 = @import("render/renderer2.zig");
pub const RendererBW = @import("render/renderer-bw.zig");
pub const Color = @import("render/color.zig");
pub const thickness = @import("render/thickness.zig");
pub const Tailwind = @import("tailwind");

test "all" {
    _ = .{
        // decoder2,
        Renderer,
        Renderer2,
        // RendererBW,
        // maptiler,
    };
}
