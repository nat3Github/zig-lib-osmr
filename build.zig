const std = @import("std");
const Allocator = std.mem.Allocator;

const update = @import("update.zig");
const GitDependency = update.GitDependency;
fn update_step(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
    const deps = &.{
        GitDependency{
            // dotenv
            .url = "https://github.com/nat3Github/zig-lib-dotenv",
            .branch = "main",
        },
        GitDependency{
            // tailwind
            .url = "https://github.com/nat3Github/zig-lib-tailwind-colors",
            .branch = "master",
        },
        GitDependency{
            // image
            .url = "https://github.com/nat3Github/zig-lib-image",
            .branch = "main",
        },
        GitDependency{
            // z2d
            .url = "https://github.com/nat3Github/zig-lib-z2d-dev-fork",
            .branch = "main",
        },
        GitDependency{
            // protobuf
            .url = "https://github.com/nat3Github/zig-lib-protobuf-dev-fork",
            .branch = "master",
        },
    };
    try update.update_dependency(step.owner.allocator, deps);
}

pub fn build(b: *std.Build) !void {
    const step = b.step("update", "update git dependencies");
    step.makeFn = update_step;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // if (true) return;

    const image_module =
        b.dependency("image", .{
            .target = target,
            .optimize = optimize,
        }).module("image");

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

    const protobuf_module = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    }).module("protobuf");

    // const gen_proto_step = b.step("gen-proto", "generates zig files from protocol buffer definitions");

    // const protobuf = @import("protobuf");
    // const protoc_step = protobuf.RunProtocStep.create(b, protobuf_dep.builder, target, .{
    //     .destination_directory = b.path("src/decode/vector_tile-proto"),
    //     .source_files = &.{
    //         "src/decode/vector_tile.proto",
    //     },
    //     .include_directories = &.{},
    // });

    // gen_proto_step.dependOn(&protoc_step.step);

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
    osmr_module.addImport("image", image_module);

    const lib_test = b.addTest(.{
        .target = target,
        .optimize = optimize,
        .root_module = osmr_module,
    });

    const lib_test_run = b.addRunArtifact(lib_test);
    step_test.dependOn(&lib_test_run.step);
}
