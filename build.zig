const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable_tracy = b.option(bool, "tracy", "Tracy Profiler") orelse false;

    const exe = b.addExecutable(.{
        .name = "erato-gb",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    @import("system_sdk").addLibraryPathsTo(exe);

    const ztracy = b.dependency("ztracy", .{
        .enable_ztracy = enable_tracy,
        .enable_fibers = enable_tracy,
    });
    exe.root_module.addImport("ztracy", ztracy.module("root"));
    exe.linkLibrary(ztracy.artifact("tracy"));

    const zglfw = b.dependency("zglfw", .{ .target = target });
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));

    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .glfw_opengl3,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    @import("system_sdk").addLibraryPathsTo(exe);

    exe_unit_tests.root_module.addImport("zglfw", zglfw.module("root"));
    exe_unit_tests.linkLibrary(zglfw.artifact("glfw"));

    exe_unit_tests.root_module.addImport("zopengl", zopengl.module("root"));

    exe_unit_tests.root_module.addImport("zgui", zgui.module("root"));
    exe_unit_tests.linkLibrary(zgui.artifact("imgui"));

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
