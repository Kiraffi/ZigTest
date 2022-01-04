const std = @import("std");
const ogl = @import("ogl.zig");

pub const Math = struct {
    usingnamespace @import("vector.zig");
};

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

    const fontInit = try FontSystem.init();
    defer FontSystem.deinit();
    if(!fontInit)
        return;

    const meshInit = MeshSystem.init();
    defer MeshSystem.deinit();
    if(!meshInit)
        return;
    c.glClearColor(0.0, 0.2, 0.4, 1.0);

    {
        const v1 = Math.IVec3{1, 2, 3};
        const v2 = Math.IVec3{4, 1, 2};
        print("dot: {}\n", .{Math.dot(Math.IVec3, v1, v2)});
        var m = Math.Mat44{};
        var n = Math.Mat44{};
        n[1] = 4.0;
        n[2] = 4.0;
        n[3] = 4.0;
        n[4] = 4.0;
        n[5] = 4.0;

        m[2] = 3.0;
        m[5] = 3.0;
        m[7] = 3.0;
        m[9] = 3.0;
        m[12] = 3.0;
        m[14] = 3.0;
        m[10] = 3.0;
        m[11] = 3.0;

        const mm = Math.mul(m, n);
        const nn = Math.mul(n, m);

        var i: u32 = 0;
        while(i < 16) : (i += 1)
        {
            print("mm {}: {}\n", .{i, mm[i]});
            print("nn {}: {}\n", .{i, nn[i]});
        }

        const vv1 = Math.Vec2{1, 2};
        const vv2 = Math.Vec2{3, 4};
        const vv3 = vv1 * vv2;
        print("x: {}, y: {}\n", .{vv3[0], vv3[1]});
    }

    while (eng.running)
    {
        try eng.update();

        {
            if(eng.wasPressed(c.SDLK_ESCAPE))
            {
                eng.running = false;
            }
        }
        const frame = FrameData {.width = @intToFloat(f32, eng.width), .height = @intToFloat(f32, eng.height), .pad1 = 0, .pad2 = 0};
        frameDataBuffer.writeData(@sizeOf(FrameData), 0, &frame);

        {
            var printBuffer = std.mem.zeroes([32]u8);
            const buf = try std.fmt.bufPrint(&printBuffer, "Something5", .{});
            FontSystem.drawString(buf, Math.Vec2{400.0, 10.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
        }
        // Bind frame data
        frameDataBuffer.bind(0);


        FontSystem.draw();
        //Unbind program
        c.glUseProgram( 0 );

        eng.swapBuffers();
        try eng.endFrame();

    }
}

