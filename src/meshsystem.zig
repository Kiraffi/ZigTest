const std = @import("std");
const ogl = @import("ogl.zig");

pub const Math = struct {
    usingnamespace @import("vector.zig");
};
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


const MAX_MESHES: u32 = 512;
var meshes: [MAX_MESHES]Mesh = undefined;
var meshCount: u32 = 0;

const MAX_INDICES: u32 = 1_048_576 * 32;
var meshesIndices: [MAX_INDICES]u32 = undefined;
var meshesIndicesCount: u32 = 0;

const MAX_VERTICES: u32 = 1_048_576 * 8;
var meshesVertices: [MAX_VERTICES]Vertex = undefined;
var meshesVerticesCount: u32 = 0;

var meshBuffer = ogl.ShaderBuffer{};
var ibo = ogl.ShaderBuffer{};
var program = ogl.Shader{};

const Vertex = extern struct
{
    pos: Math.Vec3,
    col: u32,
    norm: Math.Vec3,
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
    addCube();

    ibo = ogl.ShaderBuffer.createBuffer(c.GL_ELEMENT_ARRAY_BUFFER, meshesIndicesCount * @sizeOf(c.GLuint), &meshesIndices, c.GL_STATIC_DRAW);
    if(!ibo.isValid())
    {
        panic("Failed to create ibo\n", .{});
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




fn addCube() void
{
    var i = meshesVerticesCount;
    const col = utils.getColor256(255, 255, 255, 255);

    // Front
    meshesVertices[i + 0] = Vertex{ .pos = Math.Vec3{-0.5,  0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0, -1.0}, .tmp = 0 };
    meshesVertices[i + 1] = Vertex{ .pos = Math.Vec3{ 0.5,  0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0, -1.0}, .tmp = 0 };
    meshesVertices[i + 2] = Vertex{ .pos = Math.Vec3{ 0.5, -0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0, -1.0}, .tmp = 0 };
    meshesVertices[i + 3] = Vertex{ .pos = Math.Vec3{-0.5, -0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0, -1.0}, .tmp = 0 };

    // Back
    meshesVertices[i + 4] = Vertex{ .pos = Math.Vec3{ 0.5,  0.5, 0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0,  1.0}, .tmp = 0 };
    meshesVertices[i + 5] = Vertex{ .pos = Math.Vec3{-0.5,  0.5, 0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0,  1.0}, .tmp = 0 };
    meshesVertices[i + 6] = Vertex{ .pos = Math.Vec3{-0.5, -0.5, 0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0,  1.0}, .tmp = 0 };
    meshesVertices[i + 7] = Vertex{ .pos = Math.Vec3{ 0.5, -0.5, 0.5 }, .col = col, .norm = Math.Vec3 {0.0, 0.0,  1.0}, .tmp = 0 };

    // Left
    meshesVertices[i +  8] = Vertex{ .pos = Math.Vec3{-0.5,  0.5,  0.5 }, .col = col, .norm = Math.Vec3 {-1.0, 0.0, 0.0}, .tmp = 0 };
    meshesVertices[i +  9] = Vertex{ .pos = Math.Vec3{-0.5,  0.5, -0.5 }, .col = col, .norm = Math.Vec3 {-1.0, 0.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 10] = Vertex{ .pos = Math.Vec3{-0.5, -0.5, -0.5 }, .col = col, .norm = Math.Vec3 {-1.0, 0.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 11] = Vertex{ .pos = Math.Vec3{-0.5, -0.5,  0.5 }, .col = col, .norm = Math.Vec3 {-1.0, 0.0, 0.0}, .tmp = 0 };

    // Right
    meshesVertices[i + 12] = Vertex{ .pos = Math.Vec3{0.5,  0.5, -0.5 }, .col = col, .norm = Math.Vec3 {1.0, 0.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 13] = Vertex{ .pos = Math.Vec3{0.5,  0.5,  0.5 }, .col = col, .norm = Math.Vec3 {1.0, 0.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 14] = Vertex{ .pos = Math.Vec3{0.5, -0.5,  0.5 }, .col = col, .norm = Math.Vec3 {1.0, 0.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 15] = Vertex{ .pos = Math.Vec3{0.5, -0.5, -0.5 }, .col = col, .norm = Math.Vec3 {1.0, 0.0, 0.0}, .tmp = 0 };

    // Top
    meshesVertices[i + 16] = Vertex{ .pos = Math.Vec3{-0.5,  0.5,  0.5 }, .col = col, .norm = Math.Vec3 {0.0, 1.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 17] = Vertex{ .pos = Math.Vec3{ 0.5,  0.5,  0.5 }, .col = col, .norm = Math.Vec3 {0.0, 1.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 18] = Vertex{ .pos = Math.Vec3{ 0.5,  0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, 1.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 19] = Vertex{ .pos = Math.Vec3{-0.5,  0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, 1.0, 0.0}, .tmp = 0 };

    // Bot
    meshesVertices[i + 20] = Vertex{ .pos = Math.Vec3{-0.5, -0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, -1.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 21] = Vertex{ .pos = Math.Vec3{ 0.5, -0.5, -0.5 }, .col = col, .norm = Math.Vec3 {0.0, -1.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 22] = Vertex{ .pos = Math.Vec3{ 0.5, -0.5,  0.5 }, .col = col, .norm = Math.Vec3 {0.0, -1.0, 0.0}, .tmp = 0 };
    meshesVertices[i + 23] = Vertex{ .pos = Math.Vec3{-0.5, -0.5,  0.5 }, .col = col, .norm = Math.Vec3 {0.0, -1.0, 0.0}, .tmp = 0 };


    var ind = meshesIndicesCount;
    var j: u32 = 0;
    while(j < 6) : (j += 1)
    {
        meshesIndices[ind + 0] = i + 0 + j * 4;
        meshesIndices[ind + 1] = i + 1 + j * 4;
        meshesIndices[ind + 2] = i + 2 + j * 4;
        meshesIndices[ind + 3] = i + 0 + j * 4;
        meshesIndices[ind + 4] = i + 2 + j * 4;
        meshesIndices[ind + 5] = i + 3 + j * 4;
        ind += 6;
    }
    meshes[meshCount] = Mesh { .vertices = 36, .indices = 24,
        .indexBufferStartIndex = indexBufferStartIndex, .vertexBufferOffset = vertexBufferOffset,
        .vertexByteSize = @intCast(u32, @sizeOf(Vertex)) };
    meshCount += 1;
    meshesVerticesCount += 24;
    meshesIndicesCount += 36;
    indexBufferStartIndex += 36;
    vertexBufferOffset += 24 * @sizeOf(Vertex);
}