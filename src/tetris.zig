const std = @import("std");
const ogl = @import("ogl.zig");

pub const Math = struct {
    usingnamespace @import("vector.zig");
};

const engine = @import("engine.zig");
const utils = @import("utils.zig");
const FontSystem = @import("fontsystem.zig");

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

const Pcg = std.rand.Pcg;

const Vertex2D = extern struct
{
    topLeft: Math.Vec2,
    rightBottom: Math.Vec2,
    color: u32,
    rotAngle: f32,
    pad1: u32,
    pad2: u32,
};

const FrameData = extern struct
{
    width: f32,
    height: f32,
    pad1: u32,
    pad2: u32,
};

const Colors: [8]u32 = .{
    utils.getColor256(  0,   0,   0, 255), // Black background
    utils.getColor256(  0,   0, 255, 255), // Blue
    utils.getColor256(255, 255,   0, 255), // Yellow
    utils.getColor256(  0, 255, 255, 255), // Cyan
    utils.getColor256(255,   0, 255, 255), // Magneta
    utils.getColor256(  0, 255,   0, 255), // Green
    utils.getColor256(255, 160,   0, 255), // Orange
    utils.getColor256(255,   0,   0, 255), // Red
};

const GameState = struct
{
    pub const BoardWidth: u32 = 10;
    pub const BoardHeight: u32 = 24;
    pub const BoardSize = BoardWidth * BoardHeight;
    pub const VisibleBoardSize = BoardWidth * (BoardHeight - 4);
    board: [BoardSize]u8,

    score: u32,

    currentBlockIndex: u8,
    currentBlockRotation: u8,
    currentBlockPosition: Math.IVec2,

    nextBlockIndex: u8,

    lastMoveTime: u64,

    running: bool,
    rand: Pcg,

    pub fn new(seed: u64) GameState
    {
        var gameState = GameState{.board = std.mem.zeroes([BoardSize]u8), .score = 0,
            .currentBlockIndex = 0, .currentBlockRotation = 0, .currentBlockPosition = Math.IVec2{5, 5},
            .nextBlockIndex = 0, .lastMoveTime = 0, .rand = Pcg.init(seed), .running = true};


        gameState.getNextBlock();
        gameState.getNextBlock();
        return gameState;
    }
    pub fn reset(self: *GameState) void
    {
        self.score = 0;
        self.running = true;
        self.board = std.mem.zeroes([BoardSize]u8);
        self.getNextBlock();
        self.getNextBlock();
    }

    fn testCanMove(self: *const GameState, dir: Math.IVec2) bool
    {
        const bl = Blocks[self.currentBlockIndex];
        const b = switch(self.currentBlockRotation)
        {
            0 => bl.up,
            1 => bl.right,
            2 => bl.down,
            3 => bl.left,
            else => bl.up,
        };
        for(b) |block|
        {
            var pos = Math.add(block, self.currentBlockPosition);
            pos = Math.add(pos, dir);
            if(pos[1] < 0)
                return false;
            if(pos[0] < 0)
                return false;
            if(pos[0] >= GameState.BoardWidth)
                return false;
            if(pos[1] >= GameState.BoardHeight)
                return false;

            const ind = @intCast(u32, pos[0]) + @intCast(u32, pos[1]) * GameState.BoardWidth;
            if(self.board[ind] != 0)
                return false;

        }
        return true;
    }
    pub fn getNextBlock(self: *GameState) void
    {
        self.currentBlockIndex = self.nextBlockIndex;

        var randBytes: [8]u8 = undefined;
        self.rand.fill(&randBytes);

        self.currentBlockRotation = randBytes[3] % 4;
        self.nextBlockIndex = randBytes[7] % @intCast(u8, Blocks.len);

        self.currentBlockPosition[1] = 4;
        self.currentBlockPosition[0] = 5;
    }

    pub fn dropRow(self: *GameState, updateTime: u64) bool
    {

        self.lastMoveTime = updateTime;
        if(self.testCanMove(Math.IVec2{0, 1}))
        {
            self.currentBlockPosition[1] += 1;
            return false;
        }
        else
        {
            self.addBlock();
            self.getNextBlock();
            return true;
        }
        return true;
    }
    pub fn addBlock(self: *GameState) void
    {
        const bl = Blocks[self.currentBlockIndex];
        const b = switch(self.currentBlockRotation)
        {
            0 => bl.up,
            1 => bl.right,
            2 => bl.down,
            3 => bl.left,
            else => bl.up,
        };
        var rowsCleared: u8 = 0;
        for(b) |block|
        {
            var pos = Math.add(block, self.currentBlockPosition);
            if(pos[1] < 4)
            {
                self.running = false;
            }

            if(pos[1] < 0)
                continue;
            if(pos[0] < 0)
                continue;
            if(pos[0] >= GameState.BoardWidth)
                continue;
            if(pos[1] >= GameState.BoardHeight)
                continue;

            const ind = @intCast(u32, pos[0]) + @intCast(u32, pos[1]) * GameState.BoardWidth;
            self.board[ind] = self.currentBlockIndex + 1;


        }

        // Remove rows
        {
            var rowY: usize = GameState.BoardHeight;
            while(rowY > 0) : (rowY -= 1)
            {
                var i: usize = 0;
                while(i < GameState.BoardWidth) : (i += 1)
                {
                    const index = i + (rowY - 1) * GameState.BoardWidth;
                    if(self.board[index] == 0)
                        break;
                }
                if(i == GameState.BoardWidth)
                {
                    rowsCleared += 1;
                    var y = rowY - 1;
                    while(y > 0) : (y -= 1)
                    {
                        var x: usize = 0;
                        while(x < GameState.BoardWidth) : (x += 1)
                        {
                            self.board[x + y * GameState.BoardWidth] = self.board[x + (y - 1) * GameState.BoardWidth];
                        }
                    }
                    var x: usize = 0;
                    while(x < GameState.BoardWidth) : (x += 1)
                    {
                        self.board[x + y * GameState.BoardWidth] = 0;
                    }
                    rowY += 1;
                }
            }

        }
        switch(rowsCleared)
        {
            1 => self.score += 100,
            2 => self.score += 400,
            3 => self.score += 1000,
            4 => self.score += 5000,
            else => {}
        }
    }

};



const Block = struct
{
    up:    [4]Math.IVec2,
    right: [4]Math.IVec2,
    down:  [4]Math.IVec2,
    left:  [4]Math.IVec2,
};

const tBlock = Block{
    .up    = .{ .{ 0, -1 }, .{-1,  0 }, .{ 0,  0 }, .{ 1,  0 } },
    .right = .{ .{ 0, -1 }, .{ 0,  0 }, .{ 1,  0 }, .{ 0,  1 } },
    .down  = .{ .{-1,  0 }, .{ 0,  0 }, .{ 1,  0 }, .{ 0,  1 } },
    .left  = .{ .{ 0, -1 }, .{-1,  0 }, .{ 0,  0 }, .{ 0,  1 } },
};

const squareBlock = Block{
    .up    = .{ .{ 0, -1 }, .{ 1, -1 }, .{ 0,  0 }, .{ 1,  0 } },
    .right = .{ .{ 0,  0 }, .{ 1,  0 }, .{ 0,  1 }, .{ 1,  1 } },
    .down  = .{ .{-1,  0 }, .{ 0,  0 }, .{-1,  1 }, .{ 0,  1 } },
    .left  = .{ .{-1, -1 }, .{ 0, -1 }, .{-1,  0 }, .{ 0,  0 } },
};

const lBlock = Block{
    .up    = .{ .{ 0, -2 }, .{ 0, -1 }, .{ 0,  0 }, .{ 1,  0 } },
    .right = .{ .{ 0,  0 }, .{ 1,  0 }, .{ 2,  0 }, .{ 0,  1 } },
    .down  = .{ .{-1,  0 }, .{ 0,  0 }, .{ 0,  1 }, .{ 0,  2 } },
    .left  = .{ .{ 0, -1 }, .{-1,  0 }, .{-2,  0 }, .{ 0,  0 } },
};

const jBlock = Block{
    .up    = .{ .{ 0, -2 }, .{ 0, -1 }, .{-1,  0 }, .{ 0,  0 } },
    .right = .{ .{ 0,  0 }, .{ 1,  0 }, .{ 2,  0 }, .{ 0, -1 } },
    .down  = .{ .{ 1,  0 }, .{ 0,  0 }, .{ 0,  1 }, .{ 0,  2 } },
    .left  = .{ .{ 0,  1 }, .{-1,  0 }, .{-2,  0 }, .{ 0,  0 } },
};

const zBlock = Block{
    .up    = .{ .{-1, -1 }, .{ 0, -1 }, .{ 0,  0 }, .{ 1,  0 } },
    .right = .{ .{ 1, -1 }, .{ 0,  0 }, .{ 1,  0 }, .{ 0,  1 } },
    .down  = .{ .{-1,  0 }, .{ 0,  0 }, .{ 0,  1 }, .{ 1,  1 } },
    .left  = .{ .{ 0, -1 }, .{-1,  0 }, .{ 0,  0 }, .{-1,  1 } },
};

const nBlock = Block{
    .up    = .{ .{ 0, -1 }, .{ 1, -1 }, .{-1,  0 }, .{ 0,  0 } },
    .right = .{ .{-1, -1 }, .{ 0,  0 }, .{-1,  0 }, .{ 0,  1 } },
    .down  = .{ .{ 0,  0 }, .{ 1,  0 }, .{-1,  1 }, .{ 0,  1 } },
    .left  = .{ .{ 0, -1 }, .{ 1,  0 }, .{ 0,  0 }, .{ 1,  1 } },
};

const iBlock = Block{
    .up    = .{ .{-2,  0 }, .{-1,  0 }, .{ 0,  0 }, .{ 1,  0 } },
    .right = .{ .{ 0, -2 }, .{ 0, -1 }, .{ 0,  0 }, .{ 0,  1 } },
    .down  = .{ .{-1,  0 }, .{ 0,  0 }, .{ 1,  0 }, .{ 2,  0 } },
    .left  = .{ .{ 0, -1 }, .{ 0,  0 }, .{ 0,  1 }, .{ 0,  2 } },
};

const Blocks  = [_]Block{
    tBlock,
    squareBlock,
    lBlock,
    jBlock,
    zBlock,
    nBlock,
    iBlock,
};


pub fn main() anyerror!void
{
    var eng = try engine.Engine.init(640, 480, "Tetris Zig");
    defer eng.deinit();


    var program = ogl.Shader.createGraphicsProgram(vertexShaderSource, fragmentShaderSource);
    if(program.program == 0)
    {
        panic("Failed to initialize opengl.\n", .{});
        return;
    }
    defer program.deleteProgram(); // c.glDeleteProgram(program);


    var vao: c.GLuint = 0;
    c.glGenBuffers(1, &vao);
    c.glGenVertexArrays(1, &vao);
    defer c.glDeleteVertexArrays(1, &vao);
    c.glBindVertexArray(vao);


    // IBO
    var ibo = ogl.ShaderBuffer{};
    {
        var iboData: [6 * 65536]c.GLuint = undefined;
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
    defer ibo.deleteBuffer();


    var ssbo = ogl.ShaderBuffer{};
    {
        ssbo = ogl.ShaderBuffer.createBuffer(c.GL_SHADER_STORAGE_BUFFER, (GameState.VisibleBoardSize + 4) * @sizeOf(Vertex2D),
            null, c.GL_DYNAMIC_COPY);
        if(!ssbo.isValid())
        {
            panic("Failed to create ssbo\n", .{});
            return;
        }
    }
    defer ssbo.deleteBuffer();

    var frameDataBuffer = ogl.ShaderBuffer{};
    {
        const frame = FrameData {.width = @intToFloat(f32, eng.width), .height = @intToFloat(f32, eng.height), .pad1 = 0, .pad2 = 0};
        frameDataBuffer = ogl.ShaderBuffer.createBuffer(c.GL_UNIFORM_BUFFER, @sizeOf(FrameData), &frame, c.GL_DYNAMIC_COPY);
        if(!frameDataBuffer.isValid())
        {
            panic("Failed to create frameDataBuffer\n", .{});
            return;
        }

    }


    const fontInit = try FontSystem.init();
    defer FontSystem.deinit();
    if(!fontInit)
        return;

    c.glClearColor(0.0, 0.2, 0.4, 1.0);
    const ran = @intCast(u64, std.time.nanoTimestamp() & 0xffff_ffff_ffff_ffff);
    var gameState = GameState.new(ran);

    while (eng.running)
    {
        try eng.update();
        const currPos = gameState.currentBlockPosition;
        const currRota = gameState.currentBlockRotation;
        const currInd = gameState.currentBlockIndex;
        const wasRunning = gameState.running;
        if(gameState.running)
        {
            if(eng.totalNanos - gameState.lastMoveTime > 200_000_000)
            {
                _ = gameState.dropRow(eng.totalNanos);
            }

            if(eng.wasPressed(c.SDLK_ESCAPE))
            {
                gameState.running = false;
            }
            if(eng.wasPressed(c.SDLK_LEFT) or eng.wasPressed(c.SDLK_a))
            {
                if(gameState.testCanMove(Math.IVec2{-1, 0}))
                {
                    gameState.currentBlockPosition[0] -= 1;
                }
            }
            if(eng.wasPressed(c.SDLK_RIGHT) or eng.wasPressed(c.SDLK_d))
            {
                if(gameState.testCanMove(Math.IVec2{1, 0}))
                {
                    gameState.currentBlockPosition[0] += 1;
                }
            }

            if(eng.wasPressed(c.SDLK_DOWN) or eng.wasPressed(c.SDLK_s))
            {
                while(!gameState.dropRow(eng.totalNanos))
                {}
            }

            if(eng.wasPressed(c.SDLK_UP) or eng.wasPressed(c.SDLK_w))
            {
                const currRot = gameState.currentBlockRotation;
                gameState.currentBlockRotation = (gameState.currentBlockRotation + 1) % 4;
                if(!gameState.testCanMove(Math.IVec2{0, 0}))
                {
                    gameState.currentBlockRotation = currRot;
                }
            }

            if(eng.wasPressed(c.SDLK_x))
            {
                const currentBlockIndex = gameState.currentBlockIndex;
                gameState.currentBlockIndex = (gameState.currentBlockIndex + 1) % @intCast(u8, Blocks.len);
                if(!gameState.testCanMove(Math.IVec2{0, 0}))
                {
                    gameState.currentBlockIndex = currentBlockIndex;
                }
            }
        }
        else
        {
            if(eng.wasPressed(c.SDLK_ESCAPE))
            {
                eng.running = false;
            }

            if(eng.wasPressed(c.SDLK_r))
            {
                gameState.reset();
            }
        }
        if(currPos[0] == gameState.currentBlockPosition[0] and currPos[1] == gameState.currentBlockPosition[1] and
            currRota == gameState.currentBlockRotation and currInd == gameState.currentBlockIndex and
            wasRunning == gameState.running )
        {
            try eng.endFrame();
            continue;
        }
        const frame = FrameData {.width = @intToFloat(f32, eng.width), .height = @intToFloat(f32, eng.height), .pad1 = 0, .pad2 = 0};
        frameDataBuffer.writeData(@sizeOf(FrameData), 0, &frame);

        // update board visuals
        {
            var vertData: [GameState.VisibleBoardSize + 4]Vertex2D = undefined;
            const BlockSize: f32 = 20.0;
            const offsetX: f32 = 100.0;
            const offsetY: f32 = 20.0;

            for(gameState.board) |block, i|
            {
                var x = @intToFloat(f32, @intCast(u32, i) % GameState.BoardWidth);
                var y = @intToFloat(f32, @intCast(u32, i) / GameState.BoardWidth);
                if(y < 4)
                    continue;
                y -= 4;
                var data = &vertData[i - 4 * GameState.BoardWidth];

                data.topLeft[0] =     offsetX + x * BlockSize - BlockSize * 0.5;
                data.topLeft[1] =     offsetY + y * BlockSize - BlockSize * 0.5;
                data.rightBottom[0] = offsetX + x * BlockSize + BlockSize * 0.5;
                data.rightBottom[1] = offsetY + y * BlockSize + BlockSize * 0.5;
                data.color = Colors[block];
                data.rotAngle = 0.0;
            }

            const bl = Blocks[gameState.currentBlockIndex];
            const b = switch(gameState.currentBlockRotation)
            {
                0 => bl.up,
                1 => bl.right,
                2 => bl.down,
                3 => bl.left,
                else => bl.up,
            };
            for(b) |block|
            {
                var pos = Math.add(block, gameState.currentBlockPosition);

                if(pos[1] < 4)
                    continue;
                if(pos[0] < 0)
                    continue;
                if(pos[0] >= GameState.BoardWidth)
                    continue;
                if(pos[1] >= GameState.BoardHeight)
                    continue;
                pos[1] -= 4;
                const ind = @intCast(u32, pos[0]) + @intCast(u32, pos[1]) * GameState.BoardWidth;
                var data = &vertData[ind];
                data.color = Colors[gameState.currentBlockIndex + 1];
            }

            for(Blocks[gameState.nextBlockIndex].up) |block, i|
            {
                const offset = Math.Vec2{450.0, 160.0 };
                const blo = Math.Vec2{BlockSize * @intToFloat(f32, block[0]),
                    BlockSize * @intToFloat(f32, block[1])};
                var pos = Math.add(blo, offset);


                var data = &vertData[GameState.VisibleBoardSize + i];
                data.topLeft = Math.add(pos, -BlockSize * 0.5);
                data.rightBottom = Math.add(pos, BlockSize * 0.5);
                data.color = Colors[gameState.nextBlockIndex + 1];
                data.rotAngle = 0.0;
            }

            ssbo.writeData(@sizeOf(Vertex2D) * vertData.len, 0, &vertData);

        }

        {
            var printBuffer = std.mem.zeroes([32]u8);
            _ = try std.fmt.bufPrint(&printBuffer, "Score {}", .{gameState.score});
            FontSystem.drawString(&printBuffer, Math.Vec2{400.0, 10.0}, Math.Vec2{8.0, 12.0}, utils.getColor256(255, 255, 255, 255));

            if(!gameState.running)
            {
                FontSystem.drawString("Game over!", Math.Vec2{150.0, 200.0}, Math.Vec2{8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
                FontSystem.drawString("R to reset", Math.Vec2{150.0, 212.0}, Math.Vec2{8.0, 12.0}, utils.getColor256(255, 255, 255, 255));
            }
        }
        // Bind frame data
        frameDataBuffer.bind(0);


        program.useShader();

        // Set ssbo vertexdata
        ssbo.bind(1);

        //Set index data and render
        //c.glBindBuffer( c.GL_ELEMENT_ARRAY_BUFFER, ibo );
        ibo.bind(0);
        c.glDrawElements( c.GL_TRIANGLES, 6 * (GameState.VisibleBoardSize + 4), c.GL_UNSIGNED_INT, null );

        FontSystem.draw();
        //Unbind program
        c.glUseProgram( 0 );

        eng.swapBuffers();
        try eng.endFrame();

    }
}

