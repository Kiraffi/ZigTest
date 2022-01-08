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

const vertexShaderSource = @embedFile("../data/shader/triangle_temp.vert");
const fragmentShaderSource = @embedFile("../data/shader/triangle_temp.frag");

const vertexFullscreenShaderSource = @embedFile("../data/shader/textured_fullscreen.vert");
const fragmentTextureShaderSource = @embedFile("../data/shader/textured_triangle.frag");

pub var renderTarget = ogl.Texture{};
pub var renderTarget2 = ogl.Texture{};
var depthTarget = ogl.RenderTarget{};

var renderPass = ogl.RenderPass{};

var vao: c.GLuint = 0;
var program = ogl.Shader{};
var fullscreenProgram = ogl.Shader{};

const renderWidth: i32 = 1024;
const renderHeight: i32 = 768;

pub fn init() bool
{
    c.glCreateVertexArrays(1, &vao);
    program = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
    if(program.program == 0)
    {
        panic("Failed to initialize rendertotexture program.\n", .{});
        return false;
    }
    fullscreenProgram = ogl.Shader.createGraphicsProgram(vertexFullscreenShaderSource, fragmentTextureShaderSource);
    if(fullscreenProgram.program == 0)
    {
        panic("Failed to initialize rendertotexture fullscreen program.\n", .{});
        return false;
    }

    renderTarget = ogl.Texture.new(renderWidth, renderHeight, c.GL_TEXTURE_2D, c.GL_RGBA8);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    renderTarget2 = ogl.Texture.new(renderWidth, renderHeight, c.GL_TEXTURE_2D, c.GL_RGBA8);
    c.glTextureParameteri(renderTarget2.handle, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(renderTarget2.handle, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(renderTarget2.handle, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTextureParameteri(renderTarget2.handle, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    depthTarget = ogl.RenderTarget.new(renderWidth, renderHeight, c.GL_TEXTURE_2D, c.GL_DEPTH_COMPONENT);
    const rTargets = [_]ogl.Texture{renderTarget, renderTarget2};
    const dTargets = [_]ogl.RenderTarget{depthTarget};

    renderPass = ogl.RenderPass.createRenderPass(&rTargets, &dTargets);
    return true;
}

pub fn deinit() void
{
    program.deleteProgram();
    fullscreenProgram.deleteProgram();
    renderPass.deleteRenderPass();
    renderTarget.deleteTexture();
    depthTarget.deleteRenderTarget();
}

pub fn draw() void
{
    program.useShader();

    renderPass.bind();
    c.glBindVertexArray(vao);

    c.glClear( c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT );
    c.glViewport(0, 0, renderWidth, renderHeight);
    c.glDisable(c.GL_DEPTH_TEST);

    c.glDrawArrays(c.GL_TRIANGLES, 0, 6 * 4);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
}

pub fn renderTextureToBack() void
{
    c.glBindTexture(c.GL_TEXTURE_2D, renderTarget.handle);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glDisable(c.GL_DEPTH_TEST);

    fullscreenProgram.useShader();
    c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
}
