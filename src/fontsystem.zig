const std = @import("std");
const ogl = @import("ogl.zig");

const Math = @import("vector.zig");
const engine = @import("engine.zig");

const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

//const print = std.log.info;
const print = std.debug.print;
const panic = std.debug.panic;

const MAX_LETTERS: usize = 256;

const vertexShaderSource = @embedFile("../data/shader/textured_font.vert");
const fragmentShaderSource = @embedFile("../data/shader/textured_font.frag");

const fontSrc = @embedFile("../data/font/new_font.dat");

//pub const FontSystem = @This();

const LetterData = extern struct
{
    pos: Math.Vec2,
    size: Math.Vec2,

    uv: Math.Vec2,

    col: u32,
    tmp: f32,
};

var letterDatas: [MAX_LETTERS]LetterData = undefined;

var letterBuffer = ogl.ShaderBuffer{};
var ibo = ogl.ShaderBuffer{};
var program = ogl.Shader{};
var fontTexture = ogl.Texture{};

var vao: c.GLuint = 0;

var writternLetters: u32 = 0;

pub fn deinit() void
{
    c.glBindTexture(c.GL_TEXTURE_2D, 0);

    fontTexture.deleteTexture();
    letterBuffer.deleteBuffer();
    ibo.deleteBuffer();

    if(vao != 0)
        c.glDeleteVertexArrays(1, &vao);
    vao = 0;
    program.deleteProgram();
}

pub fn init() anyerror!bool
{
    program = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
    if(program.program == 0)
    {
        panic("Failed to initialize font render program.\n", .{});
        return false;
    }

    {
        var fontTexData: [8 * 12 * (128 - 32) * 4]u8 = undefined;
        var y: usize = 0;
        var ind: usize = 0;
        while(y < 12) : (y += 1)
        {
            var l: usize = 0;
            while(l < 128-32) : (l += 1)
            {
                const val:u8 = fontSrc[(11 - y) + l * 12];
                var x: usize = 0;
                while(x < 8) : (x += 1)
                {
                    const xi = @intCast(u3, x);
                    const v = ((val >> xi) & 1) * 255;
                    fontTexData[ind + 0] = v;
                    fontTexData[ind + 1] = v;
                    fontTexData[ind + 2] = v;
                    fontTexData[ind + 3] = v;
                    ind += 4;
                }
            }
        }

        const textureWidth: i32 = 8 * (128 - 32);
        const textureHeight: i32 = 12;

        const fd: []const u8 = &fontTexData;
        fontTexture = ogl.Texture.new(textureWidth, textureHeight, c.GL_TEXTURE_2D, c.GL_RGBA8);
        c.glTextureSubImage2D(fontTexture.handle, 0, 0, 0, textureWidth, textureHeight, c.GL_BGRA,
            c.GL_UNSIGNED_BYTE, fd.ptr);
    }

    letterBuffer = ogl.ShaderBuffer.createBuffer( c.GL_SHADER_STORAGE_BUFFER,
        MAX_LETTERS * @sizeOf(LetterData), null, c.GL_DYNAMIC_COPY
    );

    c.glGenBuffers(1, &vao);
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    {
        var iboData: [6 * MAX_LETTERS]c.GLuint = undefined;
        var i: c.GLuint = 0;
        while(i < iboData.len / 6) : (i += 1)
        {
            iboData[i * 6 + 0] = i * 4 + 0;
            iboData[i * 6 + 1] = i * 4 + 1;
            iboData[i * 6 + 2] = i * 4 + 3;
            iboData[i * 6 + 3] = i * 4 + 0;
            iboData[i * 6 + 4] = i * 4 + 3;
            iboData[i * 6 + 5] = i * 4 + 2;
        }

        ibo = ogl.ShaderBuffer.createBuffer(c.GL_ELEMENT_ARRAY_BUFFER, iboData.len * @sizeOf(c.GLuint), &iboData, c.GL_STATIC_DRAW);
        if(!ibo.isValid())
        {
            panic("Failed to create ibo\n", .{});
            return false;
        }
    }
    c.glBindVertexArray(0);

    return true;
}

pub fn drawString(str: []const u8, pos: Math.Vec2, letterSize: Math.Vec2, col: u32) void
{
    var p = letterSize;
    p[0] *= 0.5;
    p[1] *= 0.5;
    p = pos + p;

    var uv = Math.Vec2{0.0, 0.5};
    for(str) |letter|
    {
        if(writternLetters >= MAX_LETTERS)
            return;
        if(letter < 32)
            continue;
        const l: u8 = @intCast(u8, letter) - 32;

        uv[0] = @intToFloat(f32, l);

        letterDatas[writternLetters] =
            LetterData{ .pos = p, .size = letterSize, .uv = uv, .col = col, .tmp = 0.0};
        p[0] += letterSize[0] + 1.0;
        writternLetters += 1;
    }
}


pub fn draw() void
{
    if(writternLetters == 0)
        return;

    letterBuffer.writeData(writternLetters * @sizeOf(LetterData), 0, &letterDatas);

    program.useShader();
    c.glBindVertexArray(vao);
    ibo.bind(0);
    letterBuffer.bind(1);

    c.glBindTexture(c.GL_TEXTURE_2D, fontTexture.handle);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    c.glDisable(c.GL_DEPTH_TEST);


    c.glDrawArrays(
        c.GL_TRIANGLES, // mode
        0, // starting index in the enabled arrays
        6 * @intCast(i32, writternLetters)// number of indices to be rendered
    );
    writternLetters = 0;
}
