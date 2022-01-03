const std = @import("std");
const ogl = @import("ogl.zig");

const vec = @import("vector.zig");
const engine = @import("engine.zig");

const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

//const print = std.log.info;
const print = std.debug.print;
const panic = std.debug.panic;

const Vec2 = vec.Vec2;
const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;

const IVec2 = vec.IVec2;
const IVec3 = vec.IVec3;
const IVec4 = vec.IVec4;

const UVec2 = vec.UVec2;
const UVec3 = vec.UVec3;
const UVec4 = vec.UVec4;

const MAX_LETTERS: usize = 256;

const vertexShaderSource = @embedFile("../data/shader/textured_triangle.vert");
const fragmentShaderSource = @embedFile("../data/shader/textured_triangle.frag");

const fontSrc = @embedFile("../data/font/new_font.dat");

pub const LetterData = extern struct
{
    pos: Vec2,
    size: Vec2,

    uv: Vec2,

    col: u32,
    tmp: f32,
};
var letterDatas: [MAX_LETTERS]LetterData = undefined;


pub const FontSystem = struct
{
    letterBuffer: ogl.ShaderBuffer,
    ibo: ogl.ShaderBuffer,
    fontTexture: ogl.Texture,
    program: ogl.Shader,

    vao: c.GLuint,

    writternLetters: u32,
    canvasWidth: f32,
    canvasHeight: f32,

    pub fn deinit(self: *FontSystem) void
    {
        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        self.fontTexture.deleteTexture();
        self.letterBuffer.deleteBuffer();
        self.ibo.deleteBuffer();
        c.glDeleteVertexArrays(1, &self.vao);

        self.program.deleteProgram();
    }

    pub fn init() anyerror!FontSystem
    {
        var program = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
        if(program.program == 0)
        {
            panic("Failed to initialize font render program.\n", .{});
        }

        var fontTexture: ogl.Texture = undefined;
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

        var buf = ogl.ShaderBuffer.createBuffer( c.GL_SHADER_STORAGE_BUFFER,
            MAX_LETTERS * @sizeOf(LetterData), null, c.GL_DYNAMIC_COPY
        );

        var vao: c.GLuint = 0;
        c.glGenBuffers(1, &vao);
        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);
        var ibo: ogl.ShaderBuffer = undefined;
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
                return;
            }
        }

        var fontSystem = FontSystem {.letterBuffer = buf, .fontTexture = fontTexture, .program = program, .ibo = ibo,
            .vao = vao, .canvasWidth = 0.0, .canvasHeight = 0.0, .writternLetters = 0 };

        return fontSystem;
    }


    pub fn drawString(self: *FontSystem, str: []const u8, pos: Vec2, letterSize: Vec2, col: u32) void
    {
        var p = letterSize;
        p.x *= 0.5;
        p.y *= 0.5;
        p = vec.add2(Vec2, &pos, &p);

        var uv = Vec2{.x = 0.0, .y = 0.5};
        for(str) |letter|
        {
            if(self.writternLetters >= MAX_LETTERS)
                return;
            if(letter < 32)
                continue;
            const l: u8 = @intCast(u8, letter) - 32;

            uv.x = @intToFloat(f32, l);

            letterDatas[self.writternLetters] =
                LetterData{ .pos = p, .size = letterSize, .uv = uv, .col = col, .tmp = 0.0};
            p.x += letterSize.x + 1.0;
            self.writternLetters += 1;
        }
    }


    pub fn draw(self: *FontSystem, canvasWidth: f32, canvasHeight: f32) void
    {
        if(self.writternLetters == 0)
            return;

        self.canvasWidth = canvasWidth;
        self.canvasHeight = canvasHeight;

        self.letterBuffer.writeData(self.writternLetters * @sizeOf(LetterData), 0, &letterDatas);

        self.program.useShader();
        c.glBindVertexArray(self.vao);
        self.ibo.bind(0);
        self.letterBuffer.bind(1);

        c.glBindTexture(c.GL_TEXTURE_2D, self.fontTexture.handle);
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);


        c.glDrawArrays(
            c.GL_TRIANGLES, // mode
            0, // starting index in the enabled arrays
            6 * @intCast(i32, self.writternLetters)// number of indices to be rendered
        );
        self.writternLetters = 0;
    }
};