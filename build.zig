const std = @import("std");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const step_test = b.step("test", "Run All Tests in src/test");

    const weather_module = b.addModule("osmr", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/lib.zig"),
    });

    const lib_test = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_module = weather_module,
    });
    const lib_test_run = b.addRunArtifact(lib_test);
    step_test.dependOn(&lib_test_run.step);
}
