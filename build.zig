const std = @import("std");
const rlz = @import("raylib_zig");
const fs = std.fs;

pub fn build(b: *std.Build) !void {
    // Configure build target and optimization level
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    // Configure WebAssembly target for browser deployment
    const web_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .emscripten,
    });

    // Import raylib for web build
    const raylib_dep_web = b.dependency("raylib_zig", .{
        .target = web_target,
        .optimize = optimize,
    });

    const raylib_web = raylib_dep_web.module("raylib");
    const raylib_artifact_web = raylib_dep_web.artifact("raylib");

    // Create WASM library (named "index" to generate index.html/js/wasm)
    const wasm = b.addLibrary(.{
        .name = "index",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = web_target,
            .optimize = optimize,
        }),
    });
    wasm.root_module.addImport("raylib", raylib_web);
    wasm.linkLibrary(raylib_artifact_web);

    // Configure Emscripten compiler flags and settings
    const emcc_flags = rlz.emsdk.emccDefaultFlags(b.allocator, .{
        .optimize = optimize,
    });
    const emcc_settings = rlz.emsdk.emccDefaultSettings(b.allocator, .{
        .optimize = optimize,
    });

    // Compile WASM with Emscripten using custom shell template
    const emcc_step = rlz.emsdk.emccStep(b, raylib_artifact_web, wasm, .{
        .optimize = optimize,
        .flags = emcc_flags,
        .settings = emcc_settings,
        .shell_file_path = b.path("shell.html"),
        .install_dir = .{ .custom = "web" }
    });

    const web_step = b.step("web", "Build web bundle");
    web_step.dependOn(emcc_step);

    // Import raylib for native build
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    // Create native executable
    const exe = b.addExecutable(.{
        .name = "zigbeat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    b.installArtifact(exe);

    // Setup run command with executable
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
