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
const fragmentShaderSource = @embedFile("../data/shader/triangle.frag");

const vertexFullscreenShaderSource = @embedFile("../data/shader/textured_fullscreen.vert");
const fragmentTextureShaderSource = @embedFile("../data/shader/textured_triangle.frag");

var renderTarget = ogl.Texture{};
var depthTarget: c.GLuint = 0;
var fbo: c.GLuint = 0;
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



    // The framebuffer, which regroups 0, 1, or more textures, and 0 or 1 depth buffer.
    c.glCreateFramebuffers(1, &fbo);

    renderTarget = ogl.Texture.new(renderWidth, renderHeight, c.GL_TEXTURE_2D, c.GL_RGBA8);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTextureParameteri(renderTarget.handle, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

    c.glCreateRenderbuffers(1, &depthTarget);
    c.glNamedRenderbufferStorage(depthTarget, c.GL_DEPTH_COMPONENT, renderWidth, renderHeight);

    c.glNamedFramebufferRenderbuffer(fbo, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depthTarget);
    c.glNamedFramebufferTexture(fbo, c.GL_COLOR_ATTACHMENT0, renderTarget.handle, 0);

    const drawBuf: c.GLenum = c.GL_COLOR_ATTACHMENT0;
    c.glNamedFramebufferDrawBuffers(fbo, 1, &drawBuf);

    const status = c.glCheckNamedFramebufferStatus(fbo, c.GL_FRAMEBUFFER);
    if(status != c.GL_FRAMEBUFFER_COMPLETE)
    {
        print("failed to create framebuffer\n", .{});
        return false;
    }
    return true;
}

pub fn deinit() void
{
    program.deleteProgram();
    fullscreenProgram.deleteProgram();
    renderTarget.deleteTexture();
    c.glDeleteRenderbuffers(1, &depthTarget);
    c.glDeleteFramebuffers(1, &fbo);
}

pub fn draw() void
{
//    c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depthTarget);
//    c.glFramebufferTexture(c.GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, renderedTexture, 0);
//
//    const drawBuf: GLenum = c.GL_COLOR_ATTACHMENT0;
//    c.glDrawBuffers(1, &drawBuf);
    program.useShader();

    c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);
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
