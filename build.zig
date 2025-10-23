const std = @import("std");
const rlz = @import("raylib_zig");
const fs = std.fs;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const exe = b.addExecutable(.{
        .name = "zigbeat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe_check = b.addExecutable(.{
        .name = "zigbeat-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    if (target.query.os_tag == .emscripten) {
        const wasm = b.addLibrary(.{
            // because we want index.html
            .name = "index",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        wasm.root_module.addImport("raylib", raylib);
        wasm.linkLibrary(raylib_artifact);

        const emcc_flags = rlz.emsdk.emccDefaultFlags(b.allocator, .{
            .optimize = optimize,
        });
        const emcc_settings = rlz.emsdk.emccDefaultSettings(b.allocator, .{
            .optimize = optimize,
        });

        const emcc_step = rlz.emsdk.emccStep(b, raylib_artifact, wasm, .{ .optimize = optimize, .flags = emcc_flags, .settings = emcc_settings, .shell_file_path = b.path("shell.html"), .install_dir = .{ .custom = "web" } });

        b.getInstallStep().dependOn(emcc_step);
        const run_step = b.step("run", "Run zigbeat");
        run_step.dependOn(emcc_step);
        return;
    }

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    exe_check.linkLibrary(raylib_artifact);
    exe_check.root_module.addImport("raylib", raylib);

    b.installArtifact(exe);

    const check_step = b.step("check", "Check if the code compiles");
    check_step.dependOn(&exe_check.step);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
