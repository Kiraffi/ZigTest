const std = @import("std");



fn buildTarget(sdkPath: []const u8, b: *std.build.Builder, name: []const u8, zigFile: []const u8,
    target: std.zig.CrossTarget, mode: std.builtin.Mode, runnable: bool, testable: bool) anyerror !void
{
    // to keep this debuggale from vscode without having to figure out some way to push the launch.json
    // to read the outputfile.
    const sglOutput: []const u8 = "sdl_ogl";
    const outputFile = if(runnable) sglOutput else name;
    const exe = b.addExecutable(outputFile, zigFile);
    // Includes
    exe.addIncludeDir("deps/include");

    // Sources
    exe.addCSourceFile("deps/glad/src/glad.c", &[_][]const u8{"-std=c99"});
    exe.addCSourceFile("deps/VulkanMemoryAllocator/vma.cpp", &[_][]const u8{"-std=c++14"});

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addIncludeDir("deps/glad/include/");
    exe.addIncludeDir("deps/VulkanMemoryAllocator/include/");
    if (exe.target.isWindows())
    {
        var sdkIncludePath = std.mem.zeroes([1024]u8);
        std.mem.copy(u8, &sdkIncludePath, sdkPath);
        const inc = "/Include";
        std.mem.copy(u8, sdkIncludePath[sdkPath.len..], inc);

        exe.addIncludeDir(sdkIncludePath[0..sdkPath.len + inc.len]);
        exe.addIncludeDir("deps/SDL/include/");
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
    // For vma
    exe.linkLibCpp();
    exe.install();

    try addShader(b, exe, "shader.vert", "vert.spv");
    try addShader(b, exe, "shader.frag", "frag.spv");
    try addShader(b, exe, "compute_rasterizer.comp", "compute_rasterizer_comp.spv");

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



pub fn build(b: *std.build.Builder) anyerror!void
{
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var sdkPath: []const u8 = undefined;


    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    //const target = b.standardTargetOptions(.{ .default_target = .{ .abi = .gnu } });

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    if (target.isWindows())
    {
        sdkPath = try std.process.getEnvVarOwned(allocator, "VULKAN_SDK");
        std.debug.print("Vulkan path: {s}\n", .{sdkPath});
    }

    //try(buildTarget(sdkPath, b, "zigmain", "src/main.zig", target, mode, false, false));
    //try(buildTarget(sdkPath, b, "zigtetris", "src/tetris.zig", target, mode, false, false));


    //try(buildTarget(sdkPath, b, "zigtetris", "src/tetris.zig", target, mode, true, false));
    //try(buildTarget(sdkPath, b, "zigcomprast", "src/main_compute_rasterizer.zig", target, mode, false, false));
    //try(buildTarget(sdkPath, b, "zigmain", "src/main.zig", target, mode, true, false));

    try(buildTarget(sdkPath, b, "zigmain", "src/main_vulkan_test.zig", target, mode, true, false));

}


fn addShader(b: *std.build.Builder, exe: anytype, in_file: []const u8, out_file: []const u8) !void
{
    // example:
    // glslc -o shaders/vert.spv shaders/shader.vert
    const dirname = "data/shader";
    const full_in = try std.fs.path.join(b.allocator, &[_][]const u8{ dirname, in_file });
    const full_out = try std.fs.path.join(b.allocator, &[_][]const u8{ dirname, out_file });

    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "glslc",
        full_in,
        "--target-env=vulkan1.2",
        "-o",
        full_out,
    });
    exe.step.dependOn(&run_cmd.step);
}
