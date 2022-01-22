const std = @import("std");
const ogl = @import("ogl.zig");

const Math = @import("vector.zig");
const engine = @import("engine.zig");
const utils = @import("utils.zig");

const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

//const print = std.log.info;
const print = std.debug.print;
const panic = std.debug.panic;
const Pcg = std.rand.Pcg;


const vertexShaderSource = @embedFile("../data/shader/basic3d_odd.vert");
const fragmentShaderSource = @embedFile("../data/shader/basic3d.frag");
const computeShaderSource = @embedFile("../data/shader/compute_rasterizer.comp");

const MAX_VERTICES: u32 = 1_048_576 * 3;
var meshesVertices: [MAX_VERTICES]Vertex = undefined;
var meshesVerticesCount: u32 = 0;

var meshBuffer = ogl.ShaderBuffer{};
var ibo = ogl.ShaderBuffer{};
var program = ogl.Shader{};
var computeProgram = ogl.Shader{};

const Vertex = extern struct
{
    // Math.Vec3 uses 16 bytes
    pos: [3]f32 = .{0.0, 0.0, 0.0},
    col: u32 = 0,
};

pub fn init() bool
{
    program = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
    if(program.program == 0)
    {
        panic("Failed to initialize meshsystem program.\n", .{});
        return false;
    }
    computeProgram = ogl.Shader.createComputeProgram(computeShaderSource);
    if(computeProgram.program == 0)
    {
        panic("Failed to initialize meshsystem compute program.\n", .{});
        return false;
    }

    var rand = Pcg.init(0);

    var i: usize = 0;
    while(i < MAX_VERTICES) : (i += 1)
    {
        var randBytes: [16]u8 = undefined;
        rand.fill(&randBytes);

        var j: usize = 0;
        var v = Vertex{};
        //if(false)
        {
            while(j < 3) : (j += 1)
            {
                var f: f32 = 0;
                var p: u16 = 0;
                p =  randBytes[j * 2 + 0];
                p += @intCast(u16, randBytes[j * 2 + 1]) << 8;
                f = @intToFloat(f32, p) / 65535.0;
                if(j < 2)
                {
                    f = f * 2.0 - 1.0;
                    //f = f * 0.1;
                }
                v.pos[j] = f;
            }
        }
        if(true)
        {
            j = i / 3;
            const k: usize = j + 0; // breaks if on same x-line 2 points as in j + 0...
            const ki: usize = j + 5;
            if(i % 3 == 0)
            {
                // this for some reason breaks the compute...?
                v.pos[0] = (@intToFloat(f32, k % 1024) / 1024.0) * 2.0 - 1.0;
                v.pos[1] = (@intToFloat(f32, j / 1024) / 1024.0) * 2.0 - 1.0;
            }
            else if(i % 3 == 1)
            {
                v.pos[0] = (@intToFloat(f32, ki % 1024) / 1024.0) * 2.0 - 1.0;
                v.pos[1] = (@intToFloat(f32, j / 1024 + 0) / 1024.0) * 2.0 - 1.0;
            }
            else
            {
                v.pos[0] = (@intToFloat(f32, j % 1024) / 1024.0) * 2.0 - 1.0;
                v.pos[1] = (@intToFloat(f32, j / 1024 + 100) / 1024.0) * 2.0 - 1.0;
            }
        }
        v.col = utils.getColor256(randBytes[12], randBytes[13], randBytes[14], 255);
        //if(i % 3 != 0)
        //    v.col = meshesVertices[i - i%3].col;
        meshesVertices[i] = v;
    }

    var kk: u32 = 100;

    meshesVertices[kk * 3 + 0].pos[0] = 0.0;
    meshesVertices[kk * 3 + 0].pos[1] = 0.0;
    meshesVertices[kk * 3 + 1].pos[0] = 1.0;
    meshesVertices[kk * 3 + 2].pos[0] = -1.0;
    meshesVertices[kk * 3 + 2].pos[1] = 1.0;
    kk *= 3;
    kk += 9;
    while(kk < MAX_VERTICES / 128) : (kk += 1)
    {
        meshesVertices[kk].pos[0] = 0.0;

    }

    meshBuffer = ogl.ShaderBuffer.createBuffer(c.GL_SHADER_STORAGE_BUFFER, MAX_VERTICES * @sizeOf(Vertex), &meshesVertices, c.GL_STATIC_DRAW);//GL_DYNAMIC_COPY);
    if(!meshBuffer.isValid())
    {
        panic("Failed to create meshBuffer\n", .{});
        return false;
    }

    return true;
}

pub fn deinit() void
{
    ibo.deleteBuffer();
    meshBuffer.deleteBuffer();
    program.deleteProgram();
}


pub fn draw(texture: ogl.Texture) void
{
    _ = texture;
    program.useShader();

    meshBuffer.bind(2);
    c.glEnable(c.GL_CULL_FACE);
    c.glCullFace(c.GL_BACK);
    //c.glFrontFace(c.GL_CW);
    c.glFrontFace(c.GL_CCW);
    c.glDisable(c.GL_BLEND);
    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_LESS);
    c.glDrawArrays( c.GL_TRIANGLES, 0, @intCast(c_int, MAX_VERTICES / 64));
    //c.glDrawArrays( c.GL_TRIANGLES, 0, @intCast(c_int, 15 * 3));

    c.glDisable(c.GL_CULL_FACE);
//

//    computeProgram.useShader();
//    meshBuffer.bind(2);
//    c.glBindImageTexture(0, texture.handle, 0, c.GL_FALSE, 0, c.GL_WRITE_ONLY, c.GL_RGBA8);
//    const width: c_uint = @intCast(c_uint, texture.width + 7);
//    const height: c_uint = @intCast(c_uint, texture.height + 7);
//    c.glDispatchCompute(width / 8, height / 8, 1);
//    c.glMemoryBarrier(c.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
}

const COMPUTE_X_GROUP_SIZE: u32 = 4 * 8 * 1;
const COMPUTE_Y_GROUP_SIZE: u32 = 64 * 1 * 1;

pub fn draw2(texture: ogl.Texture) void
{
    computeProgram.useShader();
    meshBuffer.bind(2);
    c.glBindImageTexture(0, texture.handle, 0, c.GL_FALSE, 0, c.GL_WRITE_ONLY, c.GL_RGBA8);
    const width: c_uint = @intCast(c_uint, texture.width + COMPUTE_X_GROUP_SIZE - 1);
    const height: c_uint = @intCast(c_uint, texture.height + COMPUTE_Y_GROUP_SIZE - 1);
    c.glDispatchCompute(width / COMPUTE_X_GROUP_SIZE, height / COMPUTE_Y_GROUP_SIZE, 1);
    c.glMemoryBarrier(c.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
}

