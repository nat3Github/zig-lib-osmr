const std = @import("std");
pub const common = @import("render/common.zig");

pub const decoder2 = @import("decode/tile-decoder2.zig");
pub const maptiler = @import("decode/maptiler.zig");
pub const Renderer = @import("render/renderer2.zig");
pub const RendererTranslucent = @import("render/renderer2-translucent.zig");
pub const Color = @import("image").Pixel;
pub const thickness = @import("render/thickness.zig");
pub const Tailwind = @import("tailwind");
pub const z2d = @import("z2d");
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
