const std = @import("std");
const ogl = @import("ogl.zig");

const Math = @import("vector.zig");
const transform = @import("transform.zig");
const engine = @import("engine.zig");

const utils = @import("utils.zig");

const FontSystem = @import("fontsystem.zig");
const MeshSystem = @import("meshsystem.zig");
const FlipY = @import("flipy.zig");

const rendertotexture = @import("rendertotexture.zig");
const compute = @import("compute.zig");

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
    var eng = try engine.Engine.init(1600, 900, "Test sdl ogl1", true);
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

    const rendertotextureInit = rendertotexture.init();
    defer rendertotexture.deinit();
    if(!rendertotextureInit)
        return;

    const computeInit = compute.init();
    defer compute.deinit();
    if(!computeInit)
        return;

    const flipYInit = try FlipY.init();
    defer FlipY.deinit();
    if(!flipYInit)
        return;

    var renderPass = ogl.RenderPass{};
    var renderTargetTexture = ogl.Texture{};
    var depthTarget = ogl.RenderTarget{};
    {
        const width = eng.width;
        const height = eng.height;
        renderTargetTexture = ogl.Texture.new(width, height, c.GL_TEXTURE_2D, c.GL_RGBA8);
        c.glTextureParameteri(renderTargetTexture.handle, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTextureParameteri(renderTargetTexture.handle, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTextureParameteri(renderTargetTexture.handle, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTextureParameteri(renderTargetTexture.handle, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

        depthTarget = ogl.RenderTarget.new(width, height, c.GL_TEXTURE_2D, c.GL_DEPTH_COMPONENT);
        const rTargets = [_]ogl.Texture{renderTargetTexture};
        const dTargets = [_]ogl.RenderTarget{depthTarget};

        renderPass = ogl.RenderPass.createRenderPass(&rTargets, &dTargets);
    }

    defer renderTargetTexture.deleteTexture();
    defer depthTarget.deleteRenderTarget();
    defer renderPass.deleteRenderPass();

    var vao: c.GLuint = 0;
    c.glCreateVertexArrays(1, &vao);
    defer c.glDeleteVertexArrays(1, &vao);

    var camera = transform.Transform{};
    camera.pos[2] = 10.0;
    //camera.rot = Math.getQuaternionFromAxisAngle(Math.Vec3{0, 1, 0}, Math.toRadians(180));

    var b = CameraFrameBuffer{};
    c.glClearColor(0.0, 0.2, 0.4, 1.0);

    c.glClearDepth(0.0);

    var trans = transform.Transform{};
    trans.pos = Math.Vec3{5.0, -2.0, 2.0};
    trans.scale = Math.Vec3{2.0, 2.0, 2.0};
    //trans.rot = Math.getQuaternionFromAxisAngle(Math.Vec3{1, 1, 0}, Math.toRadians(30));

    c.glBindVertexArray(vao);

    var showCompute = false;

    while (eng.running)
    {
        try eng.update();
        const moveSpeed = @floatCast(f32, 5.0 * eng.dt);
        const rotSpeed = @floatCast(f32, 1.0 * eng.dt);
        if(eng.wasPressed(c.SDLK_ESCAPE))
        {
            eng.running = false;
        }
        if(eng.isDown(c.SDLK_j))
        {
            const camUp = Math.rotateVector(Math.Vec3{0, 1, 0}, camera.rot);
            const q = Math.getQuaternionFromAxisAngle(camUp, rotSpeed);
            camera.rot = Math.mul(camera.rot, q);
        }
        if(eng.isDown(c.SDLK_l))
        {
            const camUp = Math.rotateVector(Math.Vec3{0, 1, 0}, camera.rot);
            const q = Math.getQuaternionFromAxisAngle(camUp, -rotSpeed);
            camera.rot = Math.mul(camera.rot, q);
        }
        if(eng.isDown(c.SDLK_i))
        {
            const camRight = Math.rotateVector(Math.Vec3{1, 0, 0}, camera.rot);
            const q = Math.getQuaternionFromAxisAngle(camRight, rotSpeed);
            camera.rot = Math.mul(camera.rot, q);
        }
        if(eng.isDown(c.SDLK_k))
        {
            const camRight = Math.rotateVector(Math.Vec3{1, 0, 0}, camera.rot);
            const q = Math.getQuaternionFromAxisAngle(camRight, -rotSpeed);
            camera.rot = Math.mul(camera.rot, q);
        }

        const camRight = Math.rotateVector(Math.Vec3{1, 0, 0}, camera.rot);
        const camUp = Math.rotateVector(Math.Vec3{0, 1, 0}, camera.rot);
        const camForward = Math.rotateVector(Math.Vec3{0, 0, 1}, camera.rot);
        if(eng.isDown(c.SDLK_w))
        {
            camera.pos += Math.mul(camForward, -moveSpeed);
        }
        if(eng.isDown(c.SDLK_s))
        {
            camera.pos += Math.mul(camForward, moveSpeed);
        }
        if(eng.isDown(c.SDLK_a))
        {
            camera.pos += Math.mul(camRight, -moveSpeed);
        }
        if(eng.isDown(c.SDLK_d))
        {
            camera.pos += Math.mul(camRight, moveSpeed);
        }
        if(eng.isDown(c.SDLK_q))
        {
            camera.pos += Math.mul(camUp, -moveSpeed);
        }
        if(eng.isDown(c.SDLK_e))
        {
            camera.pos += Math.mul(camUp, moveSpeed);
        }
        if(eng.wasPressed(c.SDLK_c))
        {
            showCompute = !showCompute;
        }
        const camMat = camera.getTransformAsCameraMatrix();
        b.camMat = camMat;

        const aspect = @intToFloat(f32, eng.width) / @intToFloat(f32, eng.height);
        const fovY: f32 = Math.toRadians(90.0);
        //const zFar: f32 = 2000.0;
        const zNear: f32 = 0.125;


        //const projMat = Math.createPerspectiveMatrixRH( fovY, aspect, zNear, zFar );
        const projMat = Math.createPerspectiveReverseInfiniteMatrixRH( fovY, aspect, zNear );
        b.viewProj = projMat;
        b.mvp = Math.mul(projMat, camMat);



        //trans.rot = Math.normalize(Math.mul(Math.getQuaternionFromAxisAngle(Math.Vec3{0, 1, 0}, rotSpeed * 1.0), trans.rot));
        b.padding = trans.getModelMatrix();



        const frame = FrameData {.width = @intToFloat(f32, eng.width), .height = @intToFloat(f32, eng.height), .pad1 = 0, .pad2 = 0};

        frameDataBuffer.writeData(@sizeOf(FrameData), 0, &frame);
        cameraDataBuffer.writeData(@sizeOf(CameraFrameBuffer), 0, &b);

        {
            var printBuffer = std.mem.zeroes([32]u8);
            const buf = try std.fmt.bufPrint(&printBuffer, "Pos: {d:5.2}, {d:5.2}, {d:5.2}", .{ camera.pos[0],  camera.pos[1], camera.pos[2] });
            FontSystem.drawString(buf, Math.Vec2{400.0, 10.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            const buf2 = try std.fmt.bufPrint(&printBuffer, "CamR: {d:5.2}, {d:5.2}, {d:5.2}", .{ camRight[0],  camRight[1], camRight[2] });
            FontSystem.drawString(buf2, Math.Vec2{400.0, 22.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            const buf3 = try std.fmt.bufPrint(&printBuffer, "CamU: {d:5.2}, {d:5.2}, {d:5.2}", .{ camUp[0],  camUp[1], camUp[2] });
            FontSystem.drawString(buf3, Math.Vec2{400.0, 34.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            const buf4 = try std.fmt.bufPrint(&printBuffer, "CamF: {d:5.2}, {d:5.2}, {d:5.2}", .{ camForward[0],  camForward[1], camForward[2] });
            FontSystem.drawString(buf4, Math.Vec2{400.0, 46.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            if(showCompute)
            {
                const buf5 =  try std.fmt.bufPrint(&printBuffer, "Compute", .{});
                FontSystem.drawString(buf5, Math.Vec2{400.0, 68.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            }
            else
            {
                const buf5 =  try std.fmt.bufPrint(&printBuffer, "Graphics", .{});
                FontSystem.drawString(buf5, Math.Vec2{400.0, 68.0}, Math.Vec2{ 8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            }
        }

        if(renderTargetTexture.width != eng.width or renderTargetTexture.height != eng.height)
        {
            renderTargetTexture.resize(eng.width, eng.height);
            depthTarget.resize(eng.width, eng.height);

            const rTargets = [_]ogl.Texture{renderTargetTexture};
            const dTargets = [_]ogl.RenderTarget{depthTarget};
            renderPass.resize(&rTargets, &dTargets);
        }

        rendertotexture.draw();


        renderPass.bind();

        c.glClear( c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT );
        c.glViewport(0, 0, eng.width, eng.height);

        // Bind frame data
        frameDataBuffer.bind(0);
        cameraDataBuffer.bind(1);
        rendertotexture.renderTextureToBack();

        if(showCompute)
        {
            MeshSystem.draw2(renderTargetTexture);
        }
        else
        {
            MeshSystem.draw(renderTargetTexture);
        }
        FontSystem.draw();

        compute.draw(renderTargetTexture);
        FlipY.draw(renderTargetTexture);

        //Unbind program
        c.glUseProgram( 0 );
        eng.swapBuffers();
        try eng.endFrame();
    }

}

