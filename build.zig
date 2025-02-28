const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const ResolvedTarget = Build.ResolvedTarget;
const Dependency = Build.Dependency;
const sokol = @import("sokol");

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .with_sokol_imgui = true,
    });
    const dep_cimgui = b.dependency("cimgui", .{
        .target = target,
        .optimize = optimize,
    });

    dep_sokol.artifact("sokol_clib").addIncludePath(dep_cimgui.path("src"));

    const mod_main = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "cimgui", .module = dep_cimgui.module("cimgui") },
        },
    });

    var compile_shader = b.addSystemCommand(&.{
        "tools/sokol-shdc",
        "-i",
        "src/shader/shader.glsl",
        "-o",
        "src/shader.zig",
        "-l",
        "metal_macos:glsl300es",
        "-f",
        "sokol_zig",
    });
    b.getInstallStep().dependOn(&compile_shader.step);

    if (target.result.cpu.arch.isWasm()) {
        try buildWasm(b, mod_main, dep_sokol, dep_cimgui);
    } else {
        try buildNative(b, mod_main);
    }
}

fn buildNative(b: *Build, mod: *Build.Module) !void {
    const exe = b.addExecutable(.{
        .name = "ngenes",
        .root_module = mod,
    });
    b.installArtifact(exe);
    b.step("run", "Run ngenes").dependOn(&b.addRunArtifact(exe).step);
}

fn buildWasm(b: *Build, mod: *Build.Module, dep_sokol: *Dependency, dep_cimgui: *Dependency) !void {
    const ngenes = b.addStaticLibrary(.{
        .name = "ngenes",
        .root_module = mod,
    });

    const dep_emsdk = dep_sokol.builder.dependency("emsdk", .{});

    const emsdk_incl_path = dep_emsdk.path("upstream/emscripten/cache/sysroot/include");
    dep_cimgui.artifact("cimgui_clib").addSystemIncludePath(emsdk_incl_path);

    dep_cimgui.artifact("cimgui_clib").step.dependOn(&dep_sokol.artifact("sokol_clib").step);

    const link_step = try sokol.emLinkStep(b, .{
        .lib_main = ngenes,
        .target = mod.resolved_target.?,
        .optimize = mod.optimize.?,
        .emsdk = dep_emsdk,
        .use_webgl2 = true,
        .use_emmalloc = true,
        .use_filesystem = false,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html"),
    });
    const run = sokol.emRunStep(b, .{ .name = "ngenes", .emsdk = dep_emsdk });
    run.step.dependOn(&link_step.step);
    b.step("run", "Run ngenes").dependOn(&run.step);
}
