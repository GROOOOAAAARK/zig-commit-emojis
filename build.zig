const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const cli_dep = b.dependency("cli", .{});

    // Queries for targeting all OS in the build process
    const target_queries = [_]std.Target.Query{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
        // Current implementation of terminal.zig is POSIX only, to fix for Windows build to work
        //.{ .cpu_arch = .aarch64, .os_tag = .macos },
    };

    const host_target = b.resolveTargetQuery(.{});
    var host_run_step: ?*std.Build.Step = null;
    var host_test_step: ?*std.Build.Step = null;

    for (target_queries) |tq| {
        const resolved_target = b.resolveTargetQuery(tq);
        const is_host = resolved_target.result.os.tag == host_target.result.os.tag and
            resolved_target.result.cpu.arch == host_target.result.cpu.arch;

        const run_step_name: []const u8 = switch (tq.os_tag.?) {
            .linux => "run-linux",
            .windows => "run-windows",
            .macos => "run-macos",
            else => "run",
        };
        const test_step_name: []const u8 = switch (tq.os_tag.?) {
            .linux => "test-linux",
            .windows => "test-windows",
            .macos => "test-macos",
            else => "test",
        };
        const run_step_desc: []const u8 = switch (tq.os_tag.?) {
            .linux => "Run the app (linux-musl)",
            .windows => "Run the app (windows-gnu)",
            .macos => "Run the app (macos)",
            else => "Run the app",
        };
        const test_step_desc: []const u8 = switch (tq.os_tag.?) {
            .linux => "Run unit tests (linux-musl)",
            .windows => "Run unit tests (windows-gnu)",
            .macos => "Run unit tests (macos)",
            else => "Run unit tests",
        };

        const exe = b.addExecutable(.{
            .name = "zig-commit-emoji",
            .root_module = b.createModule(.{
                .root_source_file = b.path("./src/main.zig"),
                .target = resolved_target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.root_module.addImport("cli", cli_dep.module("cli"));

        // Only the host executable is installed. Cross-target executables keep
        // the same name and would overwrite each other in the install prefix.
        if (is_host) {
            // This declares intent for the executable to be installed into the
            // standard location when the user invokes the "install" step (the default
            // step when running `zig build`).
            b.installArtifact(exe);
        }

        // This *creates* a Run step in the build graph, to be executed when another
        // step is evaluated that depends on it. The next line below will establish
        // such a dependency.
        var run_cmd = b.addRunArtifact(exe);

        // By making the run step depend on the install step, it will be run from the
        // installation directory rather than directly from within the cache directory.
        // This is not necessary, however, if the application depends on other installed
        // files, this ensures they will be present and in the expected location.
        if (is_host) run_cmd.step.dependOn(b.getInstallStep());

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build run-macos -- arg1 arg2 etc`
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        // This creates a build step. It will be visible in the `zig build --help` menu,
        // and can be selected like this: `zig build run-macos`
        // This will evaluate the `run` step rather than the default, which is "install".
        const run_step = b.step(run_step_name, run_step_desc);
        run_step.dependOn(&run_cmd.step);
        if (is_host) host_run_step = run_step;

        // Creates a step for unit testing. This only builds the test executable
        // but does not run it.
        const lib_unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/root.zig"),
                .target = resolved_target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

        const exe_unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = resolved_target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        // Similar to creating the run step earlier, this exposes a `test` step to
        // the `zig build --help` menu, providing a way for the user to request
        // running the unit tests.
        const test_step = b.step(test_step_name, test_step_desc);
        test_step.dependOn(&run_lib_unit_tests.step);
        test_step.dependOn(&run_exe_unit_tests.step);
        if (is_host) host_test_step = test_step;
    }

    // Plain `zig build run` / `zig build test` target the host OS.
    const run_step = b.step("run", "Run the app (host)");
    run_step.dependOn(host_run_step.?);
    const test_step = b.step("test", "Run unit tests (host)");
    test_step.dependOn(host_test_step.?);
}
