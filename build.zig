const std = @import("std");
const protobuf = @import("protobuf");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });
    const protobuf_module = protobuf_dep.module("protobuf");
    const gen_proto_step = b.step("gen-proto", "generates zig files from protocol buffer definitions");
    const protoc_step = protobuf.RunProtocStep.create(b, protobuf_dep.builder, target, .{
        // out directory for the generated zig files
        .destination_directory = b.path("src/decode/vector_tile-proto"),
        .source_files = &.{
            "src/decode/vector_tile.proto",
        },
        .include_directories = &.{},
    });

    gen_proto_step.dependOn(&protoc_step.step);

    const step_test = b.step("test", "Run All Tests in src/test");

    const weather_module = b.addModule("osmr", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/root.zig"),
    });
    weather_module.addImport("protobuf", protobuf_module);

    const lib_test = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_module = weather_module,
    });
    const lib_test_run = b.addRunArtifact(lib_test);
    step_test.dependOn(&lib_test_run.step);
}
