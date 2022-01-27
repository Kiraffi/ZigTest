const std = @import("std");



fn buildTarget(sdkPath: []const u8, b: *std.build.Builder, name: []const u8, zigFile: []const u8,
    target: std.zig.CrossTarget, mode: std.builtin.Mode, runnable: bool, testable: bool) void
{
    // to keep this debuggale from vscode without having to figure out some way to push the launch.json
    // to read the outputfile.
    const sglOutput: []const u8 = "sdl_ogl";
    const outputFile = if(runnable) sglOutput else name;
    const exe = b.addExecutable(outputFile, zigFile);
    // Includes
    exe.addIncludeDir("deps/include");

    // Sources
    exe.addCSourceFile("deps/src/glad.c", &[_][]const u8{"-std=c99"});

    exe.setTarget(target);
    exe.setBuildMode(mode);
    if (exe.target.isWindows())
    {
        var sdkIncludePath = std.mem.zeroes([1024]u8);
        std.mem.copy(u8, &sdkIncludePath, sdkPath);
        const inc = "/Include";
        std.mem.copy(u8, sdkIncludePath[sdkPath.len..], inc);

        exe.addIncludeDir(sdkIncludePath[0..sdkPath.len + inc.len]);
        exe.addIncludeDir("deps/include/SDL");
        exe.addLibPath("libs");
        b.installBinFile("libs/SDL2.dll", "SDL2.dll");
        exe.linkSystemLibrary("vulkan-1");
    }
    else
    {
        exe.linkSystemLibrary("vulkan");
    }
    exe.linkSystemLibrary("sdl2");
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    if(runnable)
    {
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
    if(testable)
    {
        const exe_tests = b.addTest(zigFile);
        exe_tests.setBuildMode(mode);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&exe_tests.step);
    }
}



pub fn build(b: *std.build.Builder) !void
{
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const sdkPath = try std.process.getEnvVarOwned(allocator, "VULKAN_SDK");
    std.debug.print("Vulkan path: {s}\n", .{sdkPath});

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    //const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .gnu } });

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();


    //buildTarget(sdkPath, b, "zigmain", "src/main.zig", target, mode, false, false);
    //buildTarget(sdkPath, b, "zigtetris", "src/tetris.zig", target, mode, false, false);


    //buildTarget(sdkPath, b, "zigtetris", "src/tetris.zig", target, mode, true, false);
    //buildTarget(sdkPath, b, "zigcomprast", "src/main_compute_rasterizer.zig", target, mode, false, false);
    //buildTarget(sdkPath, b, "zigmain", "src/main.zig", target, mode, true, false);

    buildTarget(sdkPath, b, "zigmain", "src/main_vulkan_test.zig", target, mode, true, false);

}
