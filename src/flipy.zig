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

const vertexShaderSource = @embedFile("data/shader/flip_y_texture.vert");
const fragmentShaderSource = @embedFile("data/shader/textured_triangle.frag");

var ibo = ogl.ShaderBuffer{};

var flipYProgram = ogl.Shader{};



pub fn init() anyerror!bool
{
    flipYProgram = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
    if(flipYProgram.program == 0)
    {
        panic("Failed to initialize rendertotexture program.\n", .{});
        return false;
    }

    {
        var iboData: [6]c.GLushort = undefined;
        iboData[0] = 0;
        iboData[1] = 1;
        iboData[2] = 2;
        iboData[3] = 0;
        iboData[4] = 2;
        iboData[5] = 3;

        ibo = ogl.ShaderBuffer.createBuffer(c.GL_ELEMENT_ARRAY_BUFFER, iboData.len * @sizeOf(c.GLushort), &iboData, c.GL_STATIC_DRAW);
        if(!ibo.isValid())
        {
            panic("Failed to create ibo\n", .{});
            return false;
        }
    }

    return true;
}

pub fn deinit() void
{
    ibo.deleteBuffer();
    flipYProgram.deleteProgram();
}

pub fn draw(flipYTexture: ogl.Texture) void
{
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    flipYProgram.useShader();

    //c.glClear( c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT );

    c.glViewport(0, 0, flipYTexture.width, flipYTexture.height);

    c.glBindTexture(c.GL_TEXTURE_2D, flipYTexture.handle);
    c.glDisable(c.GL_BLEND);
    c.glDisable(c.GL_DEPTH_TEST);

    //Set index data and render
    ibo.bind(0);
    c.glDrawElements( c.GL_TRIANGLES, 6, c.GL_UNSIGNED_SHORT, null );

    //c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
}

