const std = @import("std");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("SDL.h");
    @cInclude("SDL_vulkan.h");
});

const print = std.debug.print;
const panic = std.debug.panic;

fn checkSuccess(result: c.VkResult) !void
{
    switch (result)
    {
        c.VK_SUCCESS => {},
        else => return error.Unexpected,
    }
}


pub fn main() anyerror!void
{
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    var window = c.SDL_CreateWindow("SDL vulkan zig test", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 640, 400, 0);
    defer c.SDL_DestroyWindow(window);

    var renderer = c.SDL_CreateRenderer(window, 0, c.SDL_RENDERER_PRESENTVSYNC);
    defer c.SDL_DestroyRenderer(renderer);


    var extensionCount: u32 = 0;
    try(checkSuccess(c.vkEnumerateInstanceExtensionProperties(0, &extensionCount, null)));

    print("Extensions supported: {}\n", .{extensionCount});

}


