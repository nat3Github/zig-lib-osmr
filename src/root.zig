const std = @import("std");

pub const decoder2 = @import("decode/tile-decoder2.zig");
pub const maptiler = @import("decode/maptiler.zig");
pub const Renderer = @import("render/renderer2.zig");
pub const Color = @import("render/color.zig");
pub const thickness = @import("render/thickness.zig");
pub const Tailwind = @import("tailwind");
pub const runtime = @import("render/runtime.zig");

test "all" {
    _ = .{
        // decoder2,
        Renderer,
        runtime,
        // RendererBW,
        // maptiler,
    };
}
