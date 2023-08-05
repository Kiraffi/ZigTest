const std = @import("std");
const ogl = @import("ogl.zig");

const Math = @import("vector.zig");
const transform = @import("transform.zig");

const utils = @import("utils.zig");

const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

//const print = std.log.info;
const print = std.debug.print;
const panic = std.debug.panic;

const computeSource = @embedFile("data/shader/compute.comp");

var program = ogl.Shader{};

pub fn init() bool
{
    program = ogl.Shader.createComputeProgram(computeSource);
    if(program.program == 0)
    {
        panic("Failed to initialize rendertotexture program.\n", .{});
        return false;
    }
    return true;
}

pub fn deinit() void
{
    program.deleteProgram();
}

pub fn draw(texture: ogl.Texture) void
{
    program.useShader();
    c.glBindImageTexture(0, texture.handle, 0, c.GL_FALSE, 0, c.GL_WRITE_ONLY, c.GL_RGBA8);
    const width: c_uint = @intCast(texture.width + 7);
    const height: c_uint = @intCast(texture.height + 7);
    c.glDispatchCompute(width / 8, height / 8, 1);
    c.glMemoryBarrier(c.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
}

