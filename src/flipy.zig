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

const vertexShaderSource = @embedFile("../data/shader/flip_y_texture.vert");
const fragmentShaderSource = @embedFile("../data/shader/textured_triangle.frag");

var vao: c.GLuint = 0;
var flipYProgram = ogl.Shader{};

pub fn init() anyerror!bool
{
    c.glCreateVertexArrays(1, &vao);
    flipYProgram = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
    if(flipYProgram.program == 0)
    {
        panic("Failed to initialize rendertotexture program.\n", .{});
        return false;
    }

    return true;
}

pub fn deinit() void
{
    flipYProgram.deleteProgram();
}

pub fn draw(flipYTexture: ogl.Texture) void
{
    flipYProgram.useShader();

    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    c.glBindVertexArray(vao);

    c.glViewport(0, 0, flipYTexture.width, flipYTexture.height);

    c.glBindTexture(c.GL_TEXTURE_2D, flipYTexture.handle);
    c.glDisable(c.GL_BLEND);
    c.glDisable(c.GL_DEPTH_TEST);

    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
}

