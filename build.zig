const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const daemon_mod = b.createModule(.{
        .root_source_file = b.path("src/daemon.zig"),
        .target = target,
        .optimize = optimize,
    });
    const daemon = b.addExecutable(.{
        .name = "sparrowd",
        .root_module = daemon_mod,
    });
    daemon.linkLibC();
    b.installArtifact(daemon);
    const daemon_cmd = b.addRunArtifact(daemon);
    daemon_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| daemon_cmd.addArgs(args);
    const daemon_step = b.step("daemon", "Run the daemon");
    daemon_step.dependOn(&daemon_cmd.step);

    const sparrow_mod = b.createModule(.{
        .root_source_file = b.path("src/sparrow.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sparrow = b.addExecutable(.{
        .name = "sparrow",
        .root_module = sparrow_mod,
    });
    sparrow.linkLibC();
    b.installArtifact(sparrow);
    const sparrow_cmd = b.addRunArtifact(sparrow);
    sparrow_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| sparrow_cmd.addArgs(args);
    const sparrow_step = b.step("sparrow", "Run sparrow");
    sparrow_step.dependOn(&sparrow_cmd.step);

    const daemon_unit_tests = b.addTest(.{
        .root_module = daemon_mod,
    });

    const run_unit_tests = b.addRunArtifact(daemon_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
