const std = @import("std");
const ogl = @import("ogl.zig");

const vec = @import("vector.zig");

const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

//const print = std.log.info;
const print = std.debug.print;
const panic = std.debug.panic;

var flipHappened = false;
var previousTime: u64 = 0;
pub const Engine = struct
{
    width: c_int = 640,
    height: c_int = 480,

    timer: std.time.Timer,

    dt: f64,
    lastDtNanos: u64,
    frameIndex: u64,
    totalNanos: u64,
    running: bool,

    vsync: bool,

    buttons: [512]u8,
    halfPresses: [512]u8,

    context: c.SDL_GLContext = null,
    window: ?*c.SDL_Window = null,

    pub fn deinit(self: *Engine) void
    {
        //_ = self;
        if(self.context != null)
            c.SDL_GL_DeleteContext(self.context);
        if(self.window != null)
            c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn setTitle(self: *Engine, title: []const u8) void
    {
        //_ = self;
        if(self.window != null)
            c.SDL_SetWindowTitle(self.window, title.ptr);
    }

    pub fn isDown(self: *Engine, button: i32) bool
    {
        var b = button;
        if(b & 0x4000_0000 != 0)
            b = (b & 0xff) + 0x100;
        const key = @intCast(usize, b);

        if(key >= 512)
            return false;
        return self.buttons[key] == 1;
    }
    pub fn wasPressed(self: *Engine, button: i32) bool
    {
        var b = button;
        if(b & 0x4000_0000 != 0)
            b = (b & 0xff) + 0x100;
        const key = @intCast(usize, b);

        if(key >= 512)
            return false;
        return (self.buttons[key] == 1 and self.halfPresses[key] > 0) or (self.halfPresses[key] > 1);
    }

    pub fn setVSync(self: *Engine, vsync: bool) anyerror!void
    {
        const value: c_int = if(vsync) 1 else 0;
        if(c.SDL_GL_SetSwapInterval( value ) < 0)
        {
            panic("Failed to set vsync on. SDL_error: {s}\n", .{ c.SDL_GetError() });
        }
        else
        {
            self.vsync = vsync;
        }
    }
    pub fn swapBuffers(self: *Engine) void
    {
        c.SDL_GL_SwapWindow( self.window );
        flipHappened = true;
    }

    pub fn endFrame(self: *Engine) anyerror!void
    {
        self.lastDtNanos = self.timer.lap();
        self.totalNanos += self.lastDtNanos;
        self.dt = @intToFloat(f32, self.lastDtNanos) / 1_000_000_000.0;
        const frameUpdate: u32 = 10;
        if(self.frameIndex % frameUpdate == 0)
        {
            const deltaTime = @intToFloat(f64, self.totalNanos - previousTime) / (@intToFloat(f64, frameUpdate) * 1_000_000_000.0);
            const fps = if(deltaTime > 0.0) 1.0 / deltaTime else 1000.0;
            var printBuffer = std.mem.zeroes([128]u8);
            const res = try std.fmt.bufPrint(&printBuffer, "Time: {d:3.3}ms, Fps: {d:3.2}", .{deltaTime * 1000.0, fps});
            self.setTitle(res);
            previousTime = self.totalNanos;
        }

        if(!flipHappened)// or !self.vsync)
        {
            // windows timeBeginPeriod?
            c.SDL_Delay(1);
        }
        flipHappened = false;
        self.frameIndex += 1;

    }


    pub fn init(width: c_int, height: c_int, title: []const u8, useDebug: bool) anyerror!Engine
    {
        if(c.SDL_Init(c.SDL_INIT_VIDEO) < 0)
        {
            panic("Failed to initialize SDL\n", .{});
        }

        //Use OpenGL 4.6 core
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_CONTEXT_MAJOR_VERSION, 4 );
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_CONTEXT_MINOR_VERSION, 6 );
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE );

        _ = c.SDL_GL_SetAttribute( c.SDL_GL_DOUBLEBUFFER, 1 );
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_RED_SIZE, 8 );
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_GREEN_SIZE, 8 );
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_BLUE_SIZE, 8 );
        _ = c.SDL_GL_SetAttribute( c.SDL_GL_DEPTH_SIZE, 0 );

        if(useDebug)
            _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_DEBUG_FLAG);

        var window = c.SDL_CreateWindow(title.ptr, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, width, height,
            c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_SHOWN); // | c.SDL_WINDOW_BORDERLESS );
        if( window == null)
        {
            panic("SDL window cannot be created. SDL_error: {s}\n", .{ c.SDL_GetError() });
        }

        var context = c.SDL_GL_CreateContext(window);
        if(context == null)
        {
            panic("Failed to create sdl gl context.  SDL_error: {s}\n", .{ c.SDL_GetError() });
        }

        // glad: load all OpenGL function pointers
        if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, &c.SDL_GL_GetProcAddress)) == 0)
        {
            panic("Failed to initialise GLAD\n", .{});
        }

        print("Vendor:   {s}\n", .{c.glGetString(c.GL_VENDOR)});
        print("Renderer: {s}\n", .{c.glGetString(c.GL_RENDERER)});
        print("Version:  {s}\n", .{c.glGetString(c.GL_VERSION)});
        var subGroups: c.GLint = 0;
        c.glGetIntegerv(c.GL_SUBGROUP_SIZE_KHR, &subGroups);
        print("Subgroupsize: {}\n", .{subGroups});
        c.glGetIntegerv(c.GL_SUBGROUP_SUPPORTED_FEATURES_KHR, &subGroups);
        print("Subgroup supported features: {}\n", .{subGroups});
        if(useDebug)
        {
            c.glEnable(c.GL_DEBUG_OUTPUT);
            c.glEnable(c.GL_DEBUG_OUTPUT_SYNCHRONOUS);
            c.glDebugMessageCallback(ogl.openglCallbackFunction, null);
            c.glDebugMessageControl(c.GL_DONT_CARE, c.GL_DONT_CARE, c.GL_DONT_CARE, 0, null, 1);
        }


        // Make top left corner 0,0, requires ogl4.5
        //c.glClipControl(c.GL_UPPER_LEFT, c.GL_ZERO_TO_ONE);
        c.glClipControl(c.GL_LOWER_LEFT, c.GL_ZERO_TO_ONE);

        var engine = Engine{.width = width, .height = height,
            .timer = try std.time.Timer.start(), .dt = 0.0, .lastDtNanos = 0, .totalNanos = 0,
            .buttons = std.mem.zeroes([512]u8), .halfPresses = std.mem.zeroes([512]u8),
            .running = true, .frameIndex = 0,
            .window = window, .context = context, .vsync = false };
        try engine.setVSync(false);

        return engine;
    }


    pub fn update(self: *Engine) anyerror!void
    {
        self.halfPresses = std.mem.zeroes([512]u8);

        var ev: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&ev) != 0)
        {
            switch (ev.type)
            {
                c.SDL_QUIT => self.running = false,
                c.SDL_KEYDOWN => {
                    var p = ev.key.keysym.sym;
                    if(p & 0x4000_0000 != 0)
                        p = (p & 0xff) + 0x100;
                    const key = @intCast(usize, p);
                    if(key < 512)
                    {
                        self.halfPresses[key] += 1;
                        self.buttons[key] = 1;
                    }

                },
                c.SDL_KEYUP => {
                    var p = ev.key.keysym.sym;
                    if(p & 0x4000_0000 != 0)
                        p = (p & 0xff) + 0x100;
                    const key = @intCast(usize, p);

                    if(key < 512)
                    {
                        self.halfPresses[key] += 1;
                        self.buttons[key] = 0;
                    }

                },
                c.SDL_WINDOWEVENT => {
                    if(ev.window.event == c.SDL_WINDOWEVENT_RESIZED)
                    {
                        self.width = ev.window.data1; self.height = ev.window.data2;
                    }
                },
                else => {},
            }
        }
    }

};