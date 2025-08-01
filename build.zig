const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/enet.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "enet",
        .root_module = lib_mod,
    });

    lib.want_lto = false;
    lib.linkLibC();

    if (target.result.os.tag == .windows) {
        lib.linkSystemLibrary("ws2_32");
        lib.linkSystemLibrary("winmm");
    }

    lib.addIncludePath(b.path("src/enet/include/"));

    lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "callbacks.c",
            "compress.c",
            "host.c",
            "list.c",
            "packet.c",
            "peer.c",
            "protocol.c",
            "unix.c",
            "win32.c",
        },
        .flags = &[_][]const u8{
            "-DHAS_FCNTL=1",
            "-DHAS_POLL=1",
            "-DHAS_GETNAMEINFO=1",
            "-DHAS_GETADDRINFO=1",
            "-DHAS_GETHOSTBYNAME_R=1",
            "-DHAS_GETHOSTBYADDR_R=1",
            "-DHAS_INET_PTON=1",
            "-DHAS_INET_NTOP=1",
            "-DHAS_MSGHDR_FLAGS=1",
            "-DHAS_SOCKLEN_T=1",
            "-fno-sanitize=undefined",
        },
        .root = b.path("src/enet"),
    });

    b.installArtifact(lib);

    add_example(b, lib_mod, target, optimize, "client");
    add_example(b, lib_mod, target, optimize, "server");

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn add_example(
    b: *std.Build,
    m: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    comptime name: []const u8,
) void {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/examples/" ++ name ++ ".zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("enet", m);

    const exe = b.addExecutable(.{
        .name = "demo-" ++ name,
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("demo-" ++ name, "Run '" ++ name ++ "' demo");
    run_step.dependOn(&run_cmd.step);
}
