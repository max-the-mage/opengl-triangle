const std = @import("std");
const pkgs = @import("deps.zig").pkgs;

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("gyro-testing", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    if (exe.target.isWindows()) {
        exe.addVcpkgPaths(.Dynamic) catch @panic("vcpkg not installed");
        if (exe.vcpkg_bin_path) |bin_path| {
            for (&[_][]const u8{"SDL2.dll", "epoxy-0.dll"}) |dll| 
                b.installBinFile((try std.fs.path.join(b.allocator, &.{ bin_path, dll })), dll);
        }
        exe.subsystem = .Windows;
    }

    pkgs.addAllTo(exe);

    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("glfw3dll");
    exe.linkSystemLibrary("c");

    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
