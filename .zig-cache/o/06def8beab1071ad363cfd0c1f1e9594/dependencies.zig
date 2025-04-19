pub const packages = struct {
    pub const @"../dotenv" = struct {
        pub const build_root = "/Users/nat3/programming/zig/lib/osmr/../dotenv";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"protobuf-2.0.0-0e82agyhGwCidRG1ktCRXulks9P5ZawrK_9OctDfUDe8" = struct {
        pub const build_root = "/Users/nat3/.cache/zig/p/protobuf-2.0.0-0e82agyhGwCidRG1ktCRXulks9P5ZawrK_9OctDfUDe8";
        pub const build_zig = @import("protobuf-2.0.0-0e82agyhGwCidRG1ktCRXulks9P5ZawrK_9OctDfUDe8");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"tailwind-0.0.0-j7vJMbwvAABrLuQOMwqvryXZdWfcNu3TPPcZxzEFjct8" = struct {
        pub const build_root = "/Users/nat3/.cache/zig/p/tailwind-0.0.0-j7vJMbwvAABrLuQOMwqvryXZdWfcNu3TPPcZxzEFjct8";
        pub const build_zig = @import("tailwind-0.0.0-j7vJMbwvAABrLuQOMwqvryXZdWfcNu3TPPcZxzEFjct8");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"z2d-0.6.1-j5P_HsWoCgBnsWk-xjDII0nRpDo_rsdj5tDVpXQLe5sz" = struct {
        pub const build_root = "/Users/nat3/.cache/zig/p/z2d-0.6.1-j5P_HsWoCgBnsWk-xjDII0nRpDo_rsdj5tDVpXQLe5sz";
        pub const build_zig = @import("z2d-0.6.1-j5P_HsWoCgBnsWk-xjDII0nRpDo_rsdj5tDVpXQLe5sz");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "dotenv", "../dotenv" },
    .{ "z2d", "z2d-0.6.1-j5P_HsWoCgBnsWk-xjDII0nRpDo_rsdj5tDVpXQLe5sz" },
    .{ "tailwind", "tailwind-0.0.0-j7vJMbwvAABrLuQOMwqvryXZdWfcNu3TPPcZxzEFjct8" },
    .{ "protobuf", "protobuf-2.0.0-0e82agyhGwCidRG1ktCRXulks9P5ZawrK_9OctDfUDe8" },
};
