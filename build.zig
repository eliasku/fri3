const std = @import("std");
const bridge = @import("zig/gain/_bridge.zig");

pub fn build(b: *std.Build) void {
    // enable -fwasmtime for running tests
    b.enable_wasmtime = true;

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = std.builtin.OptimizeMode.ReleaseSmall,
    });

    std.log.info("Optimize mode => {}", .{optimize});

    const exe = b.addExecutable(.{
        .name = "main",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("zig/main.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = optimize,
        .link_libc = false,
        .strip = optimize != .Debug,
        .single_threaded = true,
    });
    exe.initial_memory = 65536 * 256 * 4;
    exe.stack_size = 65536 * 16;
    exe.entry = .disabled;
    exe.root_module.export_symbol_names = &bridge.identifiers;
    // zig build-exe main.zig -target wasm32-freestanding --export=update -fno-entry -OReleaseSmall

    b.installArtifact(exe);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("zig/main.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
        }),
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.setEnvironmentVariable("WASMTIME_BACKTRACE_DETAILS", "1");
    run_unit_tests.setEnvironmentVariable("WASMTIME_NEW_CLI", "0");
    run_unit_tests.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const unit_tests_native = b.addTest(.{
        .root_source_file = b.path("zig/main.zig"),
        .optimize = optimize,
    });

    const run_unit_tests_native = b.addRunArtifact(unit_tests_native);
    run_unit_tests_native.has_side_effects = true;

    const test_native_step = b.step("test-native", "Run unit tests using native target");
    test_native_step.dependOn(&run_unit_tests_native.step);
}
