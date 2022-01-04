const std = @import("std");
const ogl = @import("ogl.zig");

const Math = @import("vector.zig");
const transform = @import("transform.zig");
const engine = @import("engine.zig");

const utils = @import("utils.zig");

const FontSystem = @import("fontsystem.zig");
const MeshSystem = @import("meshsystem.zig");

const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

//const print = std.log.info;
const print = std.debug.print;
const panic = std.debug.panic;

const vertexShaderSource = @embedFile("../data/shader/triangle.vert");
const fragmentShaderSource = @embedFile("../data/shader/triangle.frag");

const FrameData = extern struct
{
    width: f32,
    height: f32,
    pad1: u32,
    pad2: u32,
};



pub fn main() anyerror!void
{
    var eng = try engine.Engine.init(640, 480, "Test sdl ogl");
    defer eng.deinit();

    var frameDataBuffer = ogl.ShaderBuffer{};
    {
        const frame = FrameData {.width = @intToFloat(f32, eng.width), .height = @intToFloat(f32, eng.height), .pad1 = 0, .pad2 = 0};
        frameDataBuffer = ogl.ShaderBuffer.createBuffer(c.GL_UNIFORM_BUFFER, @sizeOf(FrameData), &frame, c.GL_DYNAMIC_COPY);
        if(!frameDataBuffer.isValid())
        {
            panic("Failed to create framebuffer\n", .{});
            return;
        }
    }
    defer frameDataBuffer.deleteBuffer();

    const CameraFrameBuffer = extern struct
    {
        camMat: Math.Mat44 = Math.Mat44{},
        viewProj: Math.Mat44 = Math.Mat44{},
        mvp: Math.Mat44 = Math.Mat44{},
        padding: Math.Mat44 = Math.Mat44{},
    };
    var cameraDataBuffer = ogl.ShaderBuffer{};
    {
        cameraDataBuffer = ogl.ShaderBuffer.createBuffer(c.GL_UNIFORM_BUFFER, @sizeOf(CameraFrameBuffer), null, c.GL_DYNAMIC_COPY);
        if(!cameraDataBuffer.isValid())
        {
            panic("Failed to create camera framebuffer\n", .{});
            return;
        }

    }
    defer cameraDataBuffer.deleteBuffer();

    const fontInit = try FontSystem.init();
    defer FontSystem.deinit();
    if(!fontInit)
        return;

    const meshInit = MeshSystem.init();
    defer MeshSystem.deinit();
    if(!meshInit)
        return;


    var camera = transform.Transform{};
    camera.pos[2] = 5.0;
    //camera.rot = Math.getQuaternionFromAxisAngle(Math.Vec3{0, 1, 0}, Math.toRadians(180));

    var b = CameraFrameBuffer{};
    c.glClearColor(0.0, 0.2, 0.4, 1.0);

    while (eng.running)
    {
        try eng.update();

        if(eng.wasPressed(c.SDLK_ESCAPE))
        {
            eng.running = false;
        }
        const camMat = camera.getTransformAsCameraMatrix();
        b.camMat = camMat;

        const aspect = @intToFloat(f32, eng.width) / @intToFloat(f32, eng.height);
        const fovY: f32 = Math.toRadians(90.0);
        const zFar: f32 = 2000.0;
        const zNear: f32 = 0.125;
        const projMat = Math.createPerspectiveMatrixRH( fovY, aspect, zNear, zFar );
        b.viewProj = projMat;
        b.mvp = Math.mul(camMat, projMat);
        b.padding = Math.Mat44Identity;



        const frame = FrameData {.width = @intToFloat(f32, eng.width), .height = @intToFloat(f32, eng.height), .pad1 = 0, .pad2 = 0};

        frameDataBuffer.writeData(@sizeOf(FrameData), 0, &frame);
        cameraDataBuffer.writeData(@sizeOf(CameraFrameBuffer), 0, &b);

        {
            var printBuffer = std.mem.zeroes([32]u8);
            const buf = try std.fmt.bufPrint(&printBuffer, "Something5", .{});
            FontSystem.drawString(buf, Math.Vec2{400.0, 10.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
        }

        c.glClear( c.GL_COLOR_BUFFER_BIT );
        c.glViewport(0, 0, eng.width, eng.height);

        // Bind frame data
        frameDataBuffer.bind(0);
        cameraDataBuffer.bind(1);
        MeshSystem.draw();

        FontSystem.draw();
        //Unbind program
        c.glUseProgram( 0 );

        eng.swapBuffers();
        try eng.endFrame();

    }
}

