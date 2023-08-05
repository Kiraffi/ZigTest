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

const vertexShaderSource = @embedFile("data/shader/basic3d.vert");
const fragmentShaderSource = @embedFile("data/shader/basic3d.frag");
const computeShaderSource = @embedFile("data/shader/compute_rasterizer.comp");

const MAX_MESHES: u32 = 512;
var meshes: [MAX_MESHES]Mesh = undefined;
var meshCount: u32 = 0;

const MAX_INDICES: u32 = 1_048_576 * 8;
var meshesIndices: [MAX_INDICES]u32 = undefined;
var meshesIndicesCount: u32 = 0;

const MAX_VERTICES: u32 = 1_048_576 * 1;
var meshesVertices: [MAX_VERTICES]Vertex = undefined;
var meshesVerticesCount: u32 = 0;

var meshBuffer = ogl.ShaderBuffer{};
var ibo = ogl.ShaderBuffer{};
var iboCompute = ogl.ShaderBuffer{};
var program = ogl.Shader{};
var computeProgram = ogl.Shader{};

const Vertex = extern struct
{
    // Math.Vec3 uses 16 bytes
    posX: f32,
    posY: f32,
    posZ: f32,
    col: u32,
    normX: f32,
    normY: f32,
    normZ: f32,
    tmp: u32,
};
var vertexBufferOffset: u32 = 0;
var indexBufferStartIndex: u32 = 0;

pub const Mesh = struct
{
    vertices: u32 = 0,
    indices: u32 = 0,
    vertexBufferOffset: u32 = 0,
    indexBufferStartIndex: u32 = 0,
    vertexByteSize: u32 = 0,
};

pub fn getMesh(index: u32) Mesh
{
    if(index >= meshCount)
        return Mesh{};

    return meshes[index];
}

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

    addCube();

    ibo = ogl.ShaderBuffer.createBuffer(c.GL_ELEMENT_ARRAY_BUFFER, meshesIndicesCount * @sizeOf(c.GLuint), &meshesIndices, c.GL_STATIC_DRAW);
    if(!ibo.isValid())
    {
        panic("Failed to create ibo\n", .{});
        return false;
    }

    iboCompute = ogl.ShaderBuffer.createBuffer(c.GL_SHADER_STORAGE_BUFFER, meshesIndicesCount * @sizeOf(c.GLuint), &meshesIndices, c.GL_STATIC_DRAW);
    if(!iboCompute.isValid())
    {
        panic("Failed to create ibo for compute\n", .{});
        return false;
    }

    meshBuffer = ogl.ShaderBuffer.createBuffer(c.GL_SHADER_STORAGE_BUFFER, vertexBufferOffset, &meshesVertices, c.GL_STATIC_DRAW);//GL_DYNAMIC_COPY);
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
    iboCompute.deleteBuffer();
    meshBuffer.deleteBuffer();
    program.deleteProgram();
    computeProgram.deleteProgram();

}


pub fn draw(texture: ogl.Texture) void
{
    _ = texture;
    program.useShader();


    program.useShader();

    meshBuffer.bind(2);
    ibo.bind(0);

    c.glEnable(c.GL_CULL_FACE);
    c.glCullFace(c.GL_BACK);
    //c.glFrontFace(c.GL_CW);
    c.glFrontFace(c.GL_CCW);


    c.glDisable(c.GL_BLEND);
    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_GREATER);
    c.glDrawElements( c.GL_TRIANGLES, @intCast(indexBufferStartIndex), c.GL_UNSIGNED_INT, null );
}

const COMPUTE_X_GROUP_SIZE: u32 = 8; // 4 * 8 * 1;
const COMPUTE_Y_GROUP_SIZE: u32 = 8; //64 * 1 * 1;

pub fn draw2(texture: ogl.Texture) void
{
    computeProgram.useShader();
    meshBuffer.bind(2);
    iboCompute.bind(3);
    c.glBindImageTexture(0, texture.handle, 0, c.GL_FALSE, 0, c.GL_WRITE_ONLY, c.GL_RGBA8);
    const width: c_uint = @intCast(texture.width + COMPUTE_X_GROUP_SIZE - 1);
    const height: c_uint = @intCast(texture.height + COMPUTE_Y_GROUP_SIZE - 1);
    c.glDispatchCompute(width / COMPUTE_X_GROUP_SIZE, height / COMPUTE_Y_GROUP_SIZE, 1);
    c.glMemoryBarrier(c.GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
}



// Helper since Math.Vec3 uses 128bits
fn getVertex(pos: Math.Vec3, col: u32, norm: Math.Vec3) Vertex
{
    return Vertex{.posX = pos[0], .posY = pos[1], .posZ = pos[2], .col = col,
        .normX = norm[0], .normY = norm[1], .normZ = norm[2], .tmp = 0};
}

fn addCube() void
{
    var i = meshesVerticesCount;
    const front = utils.getColor256(  0,   0, 255, 255);
    const back =  utils.getColor256(  0,   0,  63, 255);
    const left =  utils.getColor256( 63,   0,   0, 255);
    const right = utils.getColor256(255,   0,   0, 255);
    const top =   utils.getColor256(  0, 255,   0, 255);
    const bot =   utils.getColor256(  0,  63,   0, 255);

    // Front
    meshesVertices[i + 0] = getVertex(Math.Vec3{-0.5,  0.5, 0.5 }, front, Math.Vec3 {0.0, 0.0,  1.0});
    meshesVertices[i + 1] = getVertex(Math.Vec3{ 0.5,  0.5, 0.5 }, front, Math.Vec3 {0.0, 0.0,  1.0});
    meshesVertices[i + 2] = getVertex(Math.Vec3{-0.5, -0.5, 0.5 }, front, Math.Vec3 {0.0, 0.0,  1.0});
    meshesVertices[i + 3] = getVertex(Math.Vec3{ 0.5, -0.5, 0.5 }, front, Math.Vec3 {0.0, 0.0,  1.0});

    // Back
    meshesVertices[i + 4] = getVertex(Math.Vec3{ 0.5,  0.5, -0.5 }, back, Math.Vec3 {0.0, 0.0, -1.0});
    meshesVertices[i + 5] = getVertex(Math.Vec3{-0.5,  0.5, -0.5 }, back, Math.Vec3 {0.0, 0.0, -1.0});
    meshesVertices[i + 6] = getVertex(Math.Vec3{ 0.5, -0.5, -0.5 }, back, Math.Vec3 {0.0, 0.0, -1.0});
    meshesVertices[i + 7] = getVertex(Math.Vec3{-0.5, -0.5, -0.5 }, back, Math.Vec3 {0.0, 0.0, -1.0});

    // Left
    meshesVertices[i +  8] = getVertex(Math.Vec3{-0.5,  0.5, -0.5 }, left, Math.Vec3 {-1.0, 0.0, 0.0});
    meshesVertices[i +  9] = getVertex(Math.Vec3{-0.5,  0.5,  0.5 }, left, Math.Vec3 {-1.0, 0.0, 0.0});
    meshesVertices[i + 10] = getVertex(Math.Vec3{-0.5, -0.5, -0.5 }, left, Math.Vec3 {-1.0, 0.0, 0.0});
    meshesVertices[i + 11] = getVertex(Math.Vec3{-0.5, -0.5,  0.5 }, left, Math.Vec3 {-1.0, 0.0, 0.0});

    // Right
    meshesVertices[i + 12] = getVertex(Math.Vec3{0.5,  0.5,  0.5 }, right, Math.Vec3 {1.0, 0.0, 0.0});
    meshesVertices[i + 13] = getVertex(Math.Vec3{0.5,  0.5, -0.5 }, right, Math.Vec3 {1.0, 0.0, 0.0});
    meshesVertices[i + 14] = getVertex(Math.Vec3{0.5, -0.5,  0.5 }, right, Math.Vec3 {1.0, 0.0, 0.0});
    meshesVertices[i + 15] = getVertex(Math.Vec3{0.5, -0.5, -0.5 }, right, Math.Vec3 {1.0, 0.0, 0.0});

    // Top
    meshesVertices[i + 16] = getVertex(Math.Vec3{ 0.5,  0.5,  0.5 }, top, Math.Vec3 {0.0, 1.0, 0.0});
    meshesVertices[i + 17] = getVertex(Math.Vec3{-0.5,  0.5,  0.5 }, top, Math.Vec3 {0.0, 1.0, 0.0});
    meshesVertices[i + 18] = getVertex(Math.Vec3{ 0.5,  0.5, -0.5 }, top, Math.Vec3 {0.0, 1.0, 0.0});
    meshesVertices[i + 19] = getVertex(Math.Vec3{-0.5,  0.5, -0.5 }, top, Math.Vec3 {0.0, 1.0, 0.0});

    // Bot
    meshesVertices[i + 20] = getVertex(Math.Vec3{ 0.5, -0.5, -0.5 }, bot, Math.Vec3 {0.0, -1.0, 0.0});
    meshesVertices[i + 21] = getVertex(Math.Vec3{-0.5, -0.5, -0.5 }, bot, Math.Vec3 {0.0, -1.0, 0.0});
    meshesVertices[i + 22] = getVertex(Math.Vec3{ 0.5, -0.5,  0.5 }, bot, Math.Vec3 {0.0, -1.0, 0.0});
    meshesVertices[i + 23] = getVertex(Math.Vec3{-0.5, -0.5,  0.5 }, bot, Math.Vec3 {0.0, -1.0, 0.0});


    var ind = meshesIndicesCount;
    var j: u32 = 0;
    while(j < 6) : (j += 1)
    {
        meshesIndices[ind + 0] = i + 0 + j * 4;
        meshesIndices[ind + 1] = i + 1 + j * 4;
        meshesIndices[ind + 2] = i + 2 + j * 4;
        meshesIndices[ind + 3] = i + 2 + j * 4;
        meshesIndices[ind + 4] = i + 1 + j * 4;
        meshesIndices[ind + 5] = i + 3 + j * 4;
        ind += 6;
    }
    meshes[meshCount] = Mesh { .vertices = 36, .indices = 24,
        .indexBufferStartIndex = indexBufferStartIndex, .vertexBufferOffset = vertexBufferOffset,
        .vertexByteSize = @intCast(@sizeOf(Vertex)) };
    meshCount += 1;
    meshesVerticesCount += 24;
    meshesIndicesCount += 36;
    indexBufferStartIndex += 36;
    vertexBufferOffset += 24 * @sizeOf(Vertex);
}