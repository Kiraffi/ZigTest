const std = @import("std");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("SDL_opengl.h");
});

const print = std.debug.print;
const panic = std.debug.panic;

pub fn openglCallbackFunction( source: c.GLenum, sourceType: c.GLenum,
    id: c.GLuint, severity: c.GLenum, length: c.GLsizei,
    message: [*c]const c.GLchar, userParam: ?*const anyopaque) callconv(.C) void
{
    _ = source;
    _ = sourceType;
    _ = id;
    _ = severity;
    _ = length;
    _ = userParam;

    if (severity == c.GL_DEBUG_SEVERITY_HIGH)
    {
        panic("Sever error: {s}\n", .{message});
    }

    const msgType: []const u8 = switch(severity)
    {
        c.GL_DEBUG_SEVERITY_HIGH => "High:",
        c.GL_DEBUG_SEVERITY_MEDIUM => "Med:",
        c.GL_DEBUG_SEVERITY_LOW => "Low:",

        c.GL_DEBUG_SEVERITY_NOTIFICATION => "Info:",
        else => "",

    };

    print("{s}, msg: {s}\n", .{msgType, message});
}


pub const Shader = struct
{
    program: c.GLuint = 0,

    pub fn createGraphicsProgram(vertText: []const u8, fragText: []const u8) Shader
    {
        var shader = Shader {.program = 0};
        const vertexShader = compileShader(vertText, c.GL_VERTEX_SHADER);
        if(vertexShader == 0)
        {
            print("Failed to compile vertex shader.\n", .{});
            return shader;
        }
        defer c.glDeleteShader(vertexShader);

        const fragShader = compileShader(fragText, c.GL_FRAGMENT_SHADER);
        if(fragShader == 0)
        {
            print("Failed to compile fragment shader.\n", .{});
            return shader;
        }
        defer c.glDeleteShader(fragShader);

        var programID = c.glCreateProgram();
        if(programID == 0)
        {
            panic("Failed to create shader program.\n", .{});
            return shader;
        }

        //Attach vertex and fragment shader to program
        c.glAttachShader( programID, vertexShader );
        c.glAttachShader( programID, fragShader );
        c.glLinkProgram( programID );
        shader.program = programID;
        var programSuccess = c.GL_TRUE;
        c.glGetProgramiv(programID, c.GL_LINK_STATUS, &programSuccess);
        if(programSuccess != c.GL_TRUE)
        {
            panic("Error linking program\n", .{});
            return shader;
        }

        return shader;
    }
    pub fn createComputeProgram(computeText: []const u8) Shader
    {
        var shader = Shader {.program = 0};
        const computeShader = compileShader(computeText, c.GL_COMPUTE_SHADER);
        if(computeShader == 0)
        {
            print("Failed to compile compute shader.\n", .{});
            return shader;
        }
        defer c.glDeleteShader(computeShader);

        var programID = c.glCreateProgram();
        if(programID == 0)
        {
            panic("Failed to create shader program.\n", .{});
            return shader;
        }

        //Attach vertex and fragment shader to program
        c.glAttachShader( programID, computeShader );
        c.glLinkProgram( programID );
        shader.program = programID;
        var programSuccess = c.GL_TRUE;
        c.glGetProgramiv(programID, c.GL_LINK_STATUS, &programSuccess);
        if(programSuccess != c.GL_TRUE)
        {
            panic("Error linking program\n", .{});
            return shader;
        }

        return shader;
    }
    pub fn isValid(self: *const Shader) bool
    {
        return self.program != 0;
    }
    pub fn deleteProgram(self: *Shader) void
    {
        if(self.program != 0)
            c.glDeleteProgram(self.program);
        self.program = 0;
    }
    pub fn useShader(self: *Shader) void
    {
        c.glUseProgram( self.program );
    }

};


fn compileShader(shaderText: []const u8, shaderType: c.GLuint) c.GLuint
{
    var shaderTextPtr = shaderText.ptr;
    const shader = c.glCreateShader( shaderType );
    c.glShaderSource( shader, 1, &shaderTextPtr, 0 );

    c.glCompileShader( shader );

    var shaderCompiled = c.GL_FALSE;
    c.glGetShaderiv( shader, c.GL_COMPILE_STATUS, &shaderCompiled );
    if( shaderCompiled != c.GL_TRUE )
    {
        panic("Failed to compile shader\n", .{});
        return 0;
    }
    return shader;
}

pub const Texture = struct
{
    handle: c.GLuint = 0,
    width: i32 = 0,
    height: i32 = 0,
    textureType: c.GLenum = 0,
    pixelType: c.GLenum = 0,

    pub fn new(width: i32, height: i32, textureType: c.GLenum, pixelType: c.GLenum) Texture
    {
        const handle = generateTextureHandle(width, height, textureType, pixelType);
        return Texture { .handle = handle, .width = width, .height = height, .textureType = textureType, .pixelType = pixelType };
    }

    pub fn resize(self: *Texture, width: i32, height: i32) void
    {
        self.deleteTexture();
        self.handle = generateTextureHandle(width, height, self.textureType, self.pixelType);
        self.width = width;
        self.height = height;
    }

    pub fn deleteTexture(self: *Texture) void
    {
        if(self.handle != 0)
        {
            c.glDeleteTextures(1, &self.handle);
            self.handle = 0;
        }
    }

    pub fn isValid(self: *const Texture) bool
    {
        return self.handle != 0;
    }
};

pub const RenderTarget = struct
{
    renderTarget: c.GLuint = 0,

    textureType: c.GLuint = 0,
    pixelType: c.GLuint = 0,

    width: i32 = 0,
    height: i32 = 0,

    pub fn new(width: i32, height: i32, textureType: c.GLenum, pixelType: c.GLenum) RenderTarget
    {
        const handle = generateRenderTargetHandle(width, height, textureType, pixelType);
        return RenderTarget { .renderTarget = handle, .width = width, .height = height, .textureType = textureType, .pixelType = pixelType };
    }

    pub fn resize(self: *RenderTarget, width: i32, height: i32) void
    {
        self.deleteRenderTarget();
        self.handle = generateRenderTargetHandle(width, height, self.textureType, self.pixelType);
        self.width = width;
        self.height = height;
    }

    pub fn deleteRenderTarget(self: *RenderTarget) void
    {
        if(self.renderTarget != 0)
        {
            c.glDeleteRenderbuffers(1, &self.renderTarget);
            self.renderTarget = 0;
        }
    }

    pub fn isValid(self: *const RenderTarget) bool
    {
        return self.handle != 0;
    }
};


fn generateTextureHandle(width: i32, height: i32, textureType: c.GLenum, pixelType: c.GLenum) c.GLuint
{
    var handle: c.GLuint = 0;
    c.glCreateTextures(textureType, 1, &handle);
    c.glTextureStorage2D(handle, 1, pixelType, width, height);
    return handle;
}

// not sure if this actually works anything else than depths
fn generateRenderTargetHandle(width: i32, height: i32, textureType: c.GLenum, pixelType: c.GLenum) c.GLuint
{
    _ = textureType;
    var handle: c.GLuint = 0;
    c.glCreateRenderbuffers(1, &handle);
    c.glNamedRenderbufferStorage(handle, pixelType, width, height);
    return handle;
}

pub const ShaderBuffer = struct
{
    bufferId: c.GLuint = 0,
    bufferType: c.GLenum = 0,
    size: c.GLsizeiptr = 0,
    flags: c.GLuint = 0,

    pub fn createBuffer(bufferType: c.GLenum, size: c.GLsizeiptr, data: ?*const anyopaque, flags: c.GLuint) ShaderBuffer
    {
        var buf = ShaderBuffer { .bufferId = 0, .flags = flags, .size = size, .bufferType = bufferType };
        c.glCreateBuffers(1, &buf.bufferId );
        c.glNamedBufferData(buf.bufferId, size, data, flags);
        return buf;
    }
    pub fn isValid(self: *const ShaderBuffer) bool
    {
        return self.bufferId != 0;
    }
    pub fn writeData(self: *ShaderBuffer, size: c.GLintptr, offset: c.GLintptr, data: *const anyopaque) void
    {
        if(size + offset > self.size)
        {
            panic("Trying to write outside buffer bounds: {} vs {}\n", .{self.size, size + offset});
            return;
        }
        c.glNamedBufferSubData(self.bufferId, offset, size, data);
    }

    pub fn bind(self: *ShaderBuffer, slot: c.GLuint) void
    {
        if(self.bufferType == c.GL_ELEMENT_ARRAY_BUFFER)
            c.glBindBuffer( c.GL_ELEMENT_ARRAY_BUFFER, self.bufferId )
        else
            c.glBindBufferBase(self.bufferType, slot, self.bufferId);
    }

    pub fn deleteBuffer(self: *ShaderBuffer) void
    {
        if(self.bufferId != 0)
            c.glDeleteBuffers(1, &self.bufferId);
        self.bufferId = 0;
    }

};

pub const RenderPass = struct
{
    fbo: c.GLuint = 0,
    renderTargetCount: u32 = 0,
    depthTargetCount: u32 = 0,

    width: i32 = 0,
    height: i32 = 0,


    // Bit wrong since depths should sometimes be readable too, and textures could be rendertargets, but
    // trying to simplify stuff....
    pub fn createRenderPass(textures: []const Texture, depthTargets: []const RenderTarget) RenderPass
    {
        // If no texture nor depth target set width and height to 4.
        const width = if(textures.len > 0) textures[0].width else if(depthTargets.len > 0) depthTargets[0].width else 4;
        const height = if(textures.len > 0) textures[0].height else if(depthTargets.len > 0) depthTargets[0].height else 4;
        var renderPass = RenderPass{};
        if(width <= 0 or height <= 0)
        {
            panic("Trying to create invalid size render target.", .{});
            return renderPass;
        }
        if(textures.len > 8)
        {
            panic("Cannot have more than 8 teture write targets.", .{});
            return renderPass;
        }

        for(textures) |texture|
        {
            if(texture.width != width or texture.height != height)
            {
                panic("Mismatching texture sizes.", .{});
                return renderPass;
            }
        }
        for(depthTargets) | depthTarget |
        {
            if(depthTarget.width != width or depthTarget.height != height)
            {
                panic("Mismatching texture sizes.", .{});
                return renderPass;
            }
        }

        // The framebuffer, which regroups 0, 1, or more textures, and 0 or 1 depth buffer.
        c.glCreateFramebuffers(1, &renderPass.fbo);
        if(depthTargets.len == 1)
        {
            c.glNamedFramebufferRenderbuffer(renderPass.fbo, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depthTargets[0].renderTarget);

        }

        var drawBuf: [8]c.GLenum = .{
            c.GL_NONE, c.GL_NONE, c.GL_NONE, c.GL_NONE,
            c.GL_NONE, c.GL_NONE, c.GL_NONE, c.GL_NONE
        };

        for(textures) |texture, i|
        {
            const ii = @intCast(c_int, i);
            const colAtt = @intCast(c_uint, c.GL_COLOR_ATTACHMENT0 + ii);
            c.glNamedFramebufferTexture(renderPass.fbo, colAtt, texture.handle, 0);
            drawBuf[i] = colAtt;
        }
        c.glNamedFramebufferDrawBuffers(renderPass.fbo, @intCast(c_int, textures.len), &drawBuf);

        const status = c.glCheckNamedFramebufferStatus(renderPass.fbo, c.GL_FRAMEBUFFER);
        if(status != c.GL_FRAMEBUFFER_COMPLETE)
        {
            panic("failed to create render pass", .{});
            renderPass.deleteRenderPass();
            return renderPass;
        }

        renderPass.width = width;
        renderPass.height = height;
        renderPass.renderTargetCount = @intCast(u32, textures.len);
        renderPass.depthTargetCount = @intCast(u32, depthTargets.len);

        return renderPass;
    }
    pub fn bind(self: *RenderPass) void
    {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.fbo);
    }
    pub fn deleteRenderPass(self: *RenderPass) void
    {
        if(self.fbo != 0)
        {
            c.glDeleteFramebuffers(1, &self.fbo);
            self.fbo = 0;
        }
    }
};
