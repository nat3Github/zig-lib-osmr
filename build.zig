const std = @import("std");
const protobuf = @import("protobuf");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dotenv_dep = b.dependency("dotenv", .{
        .target = target,
        .optimize = optimize,
    });
    const dotenv_module = dotenv_dep.module("dotenv");
    const tailwind_dep = b.dependency("tailwind", .{
        .target = target,
        .optimize = optimize,
    });
    const tailwind_module = tailwind_dep.module("tailwind");
    const z2d_dep = b.dependency("z2d", .{
        .target = target,
        .optimize = optimize,
    });
    const z2d_module = z2d_dep.module("z2d");

    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });
    const protobuf_module = protobuf_dep.module("protobuf");
    const gen_proto_step = b.step("gen-proto", "generates zig files from protocol buffer definitions");
    const protoc_step = protobuf.RunProtocStep.create(b, protobuf_dep.builder, target, .{
        .destination_directory = b.path("src/decode/vector_tile-proto"),
        .source_files = &.{
            "src/decode/vector_tile.proto",
        },
        .include_directories = &.{},
    });

    gen_proto_step.dependOn(&protoc_step.step);

    const step_test = b.step("test", "Run All Tests in src/test");

    const osmr_module = b.addModule("osmr", .{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("src/root.zig"),
    });
    osmr_module.addImport("protobuf", protobuf_module);
    osmr_module.addImport("z2d", z2d_module);
    osmr_module.addImport("tailwind", tailwind_module);
    osmr_module.addImport("dotenv", dotenv_module);

    const lib_test = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_module = osmr_module,
    });
    const lib_test_run = b.addRunArtifact(lib_test);
    step_test.dependOn(&lib_test_run.step);
}
