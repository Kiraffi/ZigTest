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

const WIDTH = 800;
const HEIGHT = 600;

const MAX_FRAMES_IN_FLIGHT = 2;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const deviceExtensions = [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

const swapchainWantedFormat = c.VkSurfaceFormatKHR {
    .format = c.VK_FORMAT_B8G8R8A8_SRGB,
    .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
};

var swapchainFormat = c.VkSurfaceFormatKHR {
    .format = c.VK_FORMAT_UNDEFINED,
    .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
};
var swapchainImageSize: c.VkExtent2D = undefined;


const presentModeWanted = c.VK_PRESENT_MODE_MAILBOX_KHR;
var presentMode: c.VkPresentModeKHR = c.VK_PRESENT_MODE_FIFO_KHR;

var windowWidth: u32 = WIDTH;
var windowHeight: u32 = HEIGHT;

var window: ?*c.SDL_Window = null;
var resized = false;

var currentFrame: usize = 0;
var instance: c.VkInstance = undefined;
var surface: c.VkSurfaceKHR = null;
var physicalDevice: c.VkPhysicalDevice = null; // Is this needed?
var logicalDevice: c.VkDevice = null;

var graphicsQueue: c.VkQueue = null;
var presentQueue: c.VkQueue = null;
var computeQueue: c.VkQueue = null;
var transferQueue: c.VkQueue = null;

var graphicsIndex: u32 = ~@as(u32, 0);
var transferIndex: u32 = ~@as(u32, 0);
var computeIndex: u32 = ~@as(u32, 0);
var presentIndex: u32 = ~@as(u32, 0);

//var uniqueQueues: u32 = 0;


var swapChainImages: []c.VkImage = undefined;
var swapChain: c.VkSwapchainKHR = null;
var swapChainImageViews: []c.VkImageView = undefined;
var renderPass: c.VkRenderPass = null;
var pipelineLayout: c.VkPipelineLayout = null;
var graphicsPipeline: c.VkPipeline = null;
var swapChainFramebuffers: []c.VkFramebuffer = undefined;

var debugMessenger: c.VkDebugUtilsMessengerEXT = null;

var commandPools: [MAX_FRAMES_IN_FLIGHT]c.VkCommandPool = undefined;
var commandBuffers: [MAX_FRAMES_IN_FLIGHT]c.VkCommandBuffer = undefined;

var imageAvailableSemaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore = undefined;
var renderFinishedSemaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore = undefined;
var inFlightFences: [MAX_FRAMES_IN_FLIGHT]c.VkFence = undefined;
const IMAGES_IN_FLIGHT_MAX: u32 = 64;
var imagesInFlight: [IMAGES_IN_FLIGHT_MAX]c.VkFence = undefined;
var imagesInFlightAmount: usize = 0;








const VulkanMemoryAllocation = struct {
    pos: u32 = 0,
    size: u32 = 0,
    memoryProperties: c.VkMemoryPropertyFlags,
    deviceMemory: c.VkDeviceMemory = null,
};

const VulkanMemory = struct {
    memorySize: u32 = 0,
    used: u32 = 0,
    usageFlags: c.VkBufferUsageFlags,
    allocations: std.ArrayList(VulkanMemoryAllocation),
    buffer: c.VkBuffer = null,

    pub fn createBuffer(allocator: std.mem.Allocator, usage: c.VkBufferUsageFlags, bufferSize: u32) !VulkanMemory 
    {
        const bufferInfo = c.VkBufferCreateInfo {
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = bufferSize,
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        };

        var vulkanMemory = VulkanMemory{.memorySize = bufferSize, .usageFlags = usage, 
            .allocations = std.ArrayList(VulkanMemoryAllocation).init(allocator) };

        try checkSuccess(c.vkCreateBuffer(logicalDevice, &bufferInfo, null, &vulkanMemory.buffer));
        return vulkanMemory;
    }

    pub fn deinit(self: *VulkanMemory) void
    {
        for(self.allocations.items) |alloc|
            c.vkFreeMemory(logicalDevice, alloc.deviceMemory, null);

        c.vkDestroyBuffer(logicalDevice, self.buffer, null);
        self.allocations.deinit();
    }

    pub fn createAllocation(self: *VulkanMemory, allocationSize: u32, memoryProperties: c.VkMemoryPropertyFlags) !VulkanMemoryAllocation
    {
        var memRequirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(logicalDevice, self, &memRequirements);

        if(allocationSize > memRequirements.size or allocationSize + self.used > self.memorySize)
            return error.NoMemoryForAllocation;

        const allocInfo = c.VkMemoryAllocateInfo {
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = memRequirements.size,
            .memoryTypeIndex = findMemoryType(memRequirements.memoryTypeBits, memoryProperties),
        };
        var allocation = VulkanMemoryAllocation {.pos = self.used, .size = allocationSize, .memoryProperties = memoryProperties };
        try checkSuccess(c.vkAllocateMemory(logicalDevice, &allocInfo, null, &allocation.deviceMemory));

        try self.allocations.append(allocation);
        return allocation;
    }
};



var deviceOnlyMemory: VulkanMemory = undefined;


fn findMemoryType(typeFilter: u32, properties: c.VkMemoryPropertyFlags) !u32
{
    var memProperties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);
    var i: u32 = 0;
    while(i < memProperties.memoryTypeCount) : (i += 1 )
    {
        if ((typeFilter & (1 << i)) != 0 and (memProperties.memoryTypes[i].propertyFlags & properties) == properties)
        {
            return i;
        }
    }
    return error.NoAppropriateMemoryTypeFound;
}


fn debugCallback(messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: c.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT, pUserData: ?*anyopaque) callconv(.C) c.VkBool32
{
    _ = messageType;
    _ = pUserData;
    _ = messageSeverity;
    if (messageSeverity >= c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT)
    {
        const data = pCallbackData.*;
        print("Validation layer: {s}\n", .{data.pMessage});
    }
    return c.VK_FALSE;
}

fn cleanupSwapchain(allocator: std.mem.Allocator) !void
{
    for (swapChainFramebuffers) |framebuffer|
    {
        c.vkDestroyFramebuffer(logicalDevice, framebuffer, null);
    }
    allocator.free(swapChainFramebuffers);

    for (swapChainImageViews) |imageView|
    {
        c.vkDestroyImageView(logicalDevice, imageView, null);
    }
    allocator.free(swapChainImages);
    allocator.free(swapChainImageViews);
}

pub fn deinit(allocator : std.mem.Allocator) void
{
    deviceOnlyMemory.deinit();
    if(swapChain != null)
        try cleanupSwapchain(allocator);
    if(swapChain != null)
        c.vkDestroySwapchainKHR(logicalDevice, swapChain, null);

    var i: usize = 0;
    while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1)
    {
        c.vkDestroySemaphore(logicalDevice, renderFinishedSemaphores[i], null);
        c.vkDestroySemaphore(logicalDevice, imageAvailableSemaphores[i], null);
        c.vkDestroyFence(logicalDevice, inFlightFences[i], null);
        c.vkDestroyCommandPool(logicalDevice, commandPools[i], null);
    }
    //allocator.free(commandBuffers);



    c.vkDestroyPipeline(logicalDevice, graphicsPipeline, null);
    c.vkDestroyPipelineLayout(logicalDevice, pipelineLayout, null);

    c.vkDestroyRenderPass(logicalDevice, renderPass, null);

    c.vkDestroyDevice(logicalDevice, null);

    if(enableValidationLayers)
    {
        const func = @ptrCast(c.PFN_vkDestroyDebugUtilsMessengerEXT, c.vkGetInstanceProcAddr(
            instance, "vkDestroyDebugUtilsMessengerEXT")) orelse unreachable;
        func(instance, debugMessenger, null);
    }

    c.vkDestroySurfaceKHR(instance, surface, null);
    c.vkDestroyInstance(instance, null);
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

pub fn main() anyerror!void
{
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());

    const allocator = general_purpose_allocator.allocator();
    defer deinit(allocator);

    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    //if(c.SDL_Vulkan_LoadLibrary(null) != 0)
    //{
    //    print("Failed to load vulkan library with sdlk\n", .{});
    //    return error.FailedToLoadVulkanLibrary;
    //}
    //defer c.SDL_Vulkan_UnloadLibrary();

    window = c.SDL_CreateWindow("SDL vulkan zig test",
        c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE);

    try(createInstance(allocator));


    // Create surface!
    if (c.SDL_Vulkan_CreateSurface(window, instance, &surface) != c.SDL_TRUE)
    {
        print("Failed to create surface\n", .{});
        return error.FailedToSDLVulkanCreateSurface;
    }



    try(pickPhysicalDevice(allocator));

    try(createSwapchain(allocator));

    try(createRenderPass());

    try(createGraphicsPipeline());


    try createFramebuffers(allocator);
    try createCommandPoolsAndBuffers();
    try createSyncObjects();


    var running = true;
    while(running)
    {
        var ev: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&ev) != 0)
        {
            switch (ev.type)
            {
                c.SDL_QUIT => running = false,
                else => {}
            }
        }
        try drawFrame(allocator);
        c.SDL_Delay(10);
    }
    try checkSuccess(c.vkDeviceWaitIdle(logicalDevice));

}

fn drawFrame(allocator : std.mem.Allocator) !void
{
    const oldSize = swapchainImageSize;
    var w: i32 = 0;
    var h: i32 = 0;
    c.SDL_Vulkan_GetDrawableSize(window, &w, &h);
    if(oldSize.width != w or oldSize.height != h)
    {
        resized = true;
         try checkSuccess(c.vkDeviceWaitIdle(logicalDevice));
    }
    c.SDL_GetWindowSize(window, &w, &h);
    if(w == 0 or h == 0)
        return;

    const sdlWindowFlags = c.SDL_GetWindowFlags(window);
    if((sdlWindowFlags & c.SDL_WINDOW_MINIMIZED) != 0)
        return;

    try checkSuccess(c.vkWaitForFences(logicalDevice, 1, @as(*[1]c.VkFence, &inFlightFences[currentFrame]), c.VK_TRUE, std.math.maxInt(u64)));
    if(imageAvailableSemaphores[currentFrame] == null)
        return;

    var imageIndex: u32 = undefined;

    {
        const result = c.vkAcquireNextImageKHR(logicalDevice, swapChain, std.math.maxInt(u64), imageAvailableSemaphores[currentFrame], null, &imageIndex);

        if (result == c.VK_ERROR_OUT_OF_DATE_KHR) 
        {
            try recreateSwapchain(allocator);
            return;
        } 
        else if (result != c.VK_SUCCESS and result != c.VK_SUBOPTIMAL_KHR) 
        {
            return error.FailedToAquireSwapchainImage;
        }
    }

    if (imagesInFlight[imageIndex] != null) 
    {
        try checkSuccess(c.vkWaitForFences(logicalDevice, 1, &imagesInFlight[imageIndex], c.VK_TRUE, std.math.maxInt(u64)));
    }
    imagesInFlight[imageIndex] = inFlightFences[currentFrame];

    const commandPool = commandPools[currentFrame];
    const commandBuffer = commandBuffers[currentFrame];
    try beginSingleTimeCommands(commandPool, commandBuffer);

    const clearColor = [1]c.VkClearValue{c.VkClearValue{
        .color = c.VkClearColorValue{ .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 } },
    }};

    const renderPassInfo = c.VkRenderPassBeginInfo{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = renderPass,
        .framebuffer = swapChainFramebuffers[imageIndex],
        .renderArea = c.VkRect2D {
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = swapchainImageSize,
        },
        .clearValueCount = 1,
        .pClearValues = @as(*const [1]c.VkClearValue, &clearColor),

        .pNext = null,
    };

    c.vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);
    {
        
        const viewPort = c.VkViewport{ .x = 0.0, .y = 0.0, .width = @intToFloat(f32, swapchainImageSize.width), .height = @intToFloat(f32, swapchainImageSize.height), .minDepth = 0.0, .maxDepth = 1.0 };
        const scissors = c.VkRect2D{ .offset = c.VkOffset2D{ .x = 0, .y = 0 }, .extent = swapchainImageSize };

        //insertDebugRegion(commandBuffer, "Render", Vec4(1.0f, 0.0f, 0.0f, 1.0f));
        c.vkCmdSetViewport(commandBuffer, 0, 1, &viewPort);
        c.vkCmdSetScissor(commandBuffer, 0, 1, &scissors);

        c.vkCmdBindPipeline(commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
        c.vkCmdDraw(commandBuffer, 3, 1, 0, 0);
    }
    c.vkCmdEndRenderPass(commandBuffer);

    try checkSuccess(c.vkEndCommandBuffer(commandBuffer));










    var waitSemaphores = [_]c.VkSemaphore{imageAvailableSemaphores[currentFrame]};
    var waitStages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

    const signalSemaphores = [_]c.VkSemaphore{renderFinishedSemaphores[currentFrame]};

   
    var submitInfo = [_]c.VkSubmitInfo{c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &waitSemaphores,
        .pWaitDstStageMask = &waitStages,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signalSemaphores,

        .pNext = null,
    }};

    try checkSuccess(c.vkResetFences(logicalDevice, 1, @as(*[1]c.VkFence, &inFlightFences[currentFrame])));

    try checkSuccess(c.vkQueueSubmit(graphicsQueue, 1, &submitInfo, inFlightFences[currentFrame]));

    const swapChains = [_]c.VkSwapchainKHR{swapChain};
    const presentInfo = c.VkPresentInfoKHR{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,

        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signalSemaphores,

        .swapchainCount = 1,
        .pSwapchains = &swapChains,

        .pImageIndices = @ptrCast(*[1]u32, &imageIndex),

        .pNext = null,
        .pResults = null,
    };

    {
        const result = c.vkQueuePresentKHR(presentQueue, &presentInfo);

        if (result == c.VK_ERROR_OUT_OF_DATE_KHR or result == c.VK_SUBOPTIMAL_KHR or resized) 
        {
            try recreateSwapchain(allocator);
        }
        else if (result != c.VK_SUCCESS) 
        {
            return error.FailedToPresentSwapchainImage;
        }
    }


    currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT;
}


fn createFramebuffers(allocator: std.mem.Allocator) !void
{
    swapChainFramebuffers = try allocator.alloc(c.VkFramebuffer, swapChainImageViews.len);
    for (swapChainImageViews) | swapchainImageview, i |
    {
        const attachments = [_]c.VkImageView{ swapchainImageview };

        const framebufferInfo = c.VkFramebufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = renderPass,
            .attachmentCount = 1,
            .pAttachments = &attachments,
            .width = swapchainImageSize.width,
            .height = swapchainImageSize.height,
            .layers = 1,

            .pNext = null,
            .flags = 0,
        };

        try checkSuccess(c.vkCreateFramebuffer(logicalDevice, &framebufferInfo, null, &swapChainFramebuffers[i]));
    }
}

fn createCommandPoolsAndBuffers() !void
{
    const poolInfo = c.VkCommandPoolCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = graphicsIndex,
        .pNext = null,
        .flags = 0,
    };

    var i: usize = 0;
    while(i < MAX_FRAMES_IN_FLIGHT) : (i += 1)
    {
        try checkSuccess(c.vkCreateCommandPool(logicalDevice, &poolInfo, null, &commandPools[i]));

        const allocInfo = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = commandPools[i],
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
            .pNext = null,
        };

        try checkSuccess(c.vkAllocateCommandBuffers(logicalDevice, &allocInfo, &commandBuffers[i]));
    }
}


fn beginSingleTimeCommands(commandPool: c.VkCommandPool, commandBuffer: c.VkCommandBuffer) !void
{
     try checkSuccess(c.vkResetCommandPool(logicalDevice, commandPool, 0));

    const beginInfo = c.VkCommandBufferBeginInfo { 
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
        .pNext = null,
    };

     try checkSuccess(c.vkBeginCommandBuffer(commandBuffer, &beginInfo));

    return;
}

fn endSingleTimeCommands(commandBuffer: c.VkCommandBuffer, queue: c.VkQueue) !void
{
    try checkSuccess(c.vkEndCommandBuffer(commandBuffer));

    var submitInfo = [_]c.VkSubmitInfo{c.VkSubmitInfo{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &commandBuffer,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,

        .pNext = null,
    }};

    try checkSuccess(c.vkQueueSubmit(queue, 1, &submitInfo, c.VK_NULL_HANDLE));
    try checkSuccess(c.vkQueueWaitIdle(queue));
}



fn recreateSwapchain(allocator: std.mem.Allocator) !void
{

    const oldFormat = swapchainFormat;
    try checkSuccess(c.vkDeviceWaitIdle(logicalDevice));
    try cleanupSwapchain(allocator);
    try createSwapchain(allocator);
    if(oldFormat.format != swapchainFormat.format or oldFormat.colorSpace != swapchainFormat.colorSpace)
    {
        c.vkDestroyPipeline(logicalDevice, graphicsPipeline, null);
        c.vkDestroyPipelineLayout(logicalDevice, pipelineLayout, null);

        c.vkDestroyRenderPass(logicalDevice, renderPass, null);

        try(createRenderPass());
        try(createGraphicsPipeline());
    }
    try createFramebuffers(allocator);

//    var i: usize = 0;
//    while(i < IMAGES_IN_FLIGHT_MAX) : (i += 1)
//    {
//        if(imagesInFlight[i] != null)
//            try checkSuccess(c.vkWaitForFences(logicalDevice, 1, &imagesInFlight[i], c.VK_TRUE, std.math.maxInt(u64)));
//        imagesInFlight[i] = null;
//    }

    imagesInFlightAmount = swapChainImages.len;
    try checkSuccess(c.vkDeviceWaitIdle(logicalDevice));

}


fn createCommandBuffers() !void //allocator: std.mem.Allocator) !void
{

}

fn createSyncObjects() !void
{
    const semaphoreInfo = c.VkSemaphoreCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    const fenceInfo = c.VkFenceCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        .pNext = null,
    };

    var i: usize = 0;
    while (i < MAX_FRAMES_IN_FLIGHT) : (i += 1)
    {
        try checkSuccess(c.vkCreateSemaphore(logicalDevice, &semaphoreInfo, null, &imageAvailableSemaphores[i]));
        try checkSuccess(c.vkCreateSemaphore(logicalDevice, &semaphoreInfo, null, &renderFinishedSemaphores[i]));
        try checkSuccess(c.vkCreateFence(logicalDevice, &fenceInfo, null, &inFlightFences[i]));
    }
    i = 0;
    while( i < IMAGES_IN_FLIGHT_MAX ) : ( i += 1 )
        imagesInFlight[i] = null;

    imagesInFlightAmount = swapChainImages.len;
}

fn createRenderPass() anyerror !void
{
    const colorAttachment = c.VkAttachmentDescription {
        .format = swapchainFormat.format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };

    const colorAttachmentRef = [1]c.VkAttachmentReference{c.VkAttachmentReference {
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    }};

    const subpass = [_]c.VkSubpassDescription{c.VkSubpassDescription {
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = @as(*const [1]c.VkAttachmentReference, &colorAttachmentRef),

        .flags = 0,
        .inputAttachmentCount = 0,
        .pInputAttachments = null,
        .pResolveAttachments = null,
        .pDepthStencilAttachment = null,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = null,
    }};

    const dependency = [_]c.VkSubpassDependency{c.VkSubpassDependency {
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,

        .dependencyFlags = 0,
    }};

    const renderPassInfo = c.VkRenderPassCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = @ptrCast(*const [1]c.VkAttachmentDescription, &colorAttachment),
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,

        .pNext = null,
        .flags = 0,
    };
    try checkSuccess(c.vkCreateRenderPass(logicalDevice, &renderPassInfo, null, &renderPass));
}

fn createShaderModule(code: []align(@alignOf(u32)) const u8) !c.VkShaderModule
{
    const createInfo = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = std.mem.bytesAsSlice(u32, code).ptr,

        .pNext = null,
        .flags = 0,
    };

    var shaderModule: c.VkShaderModule = undefined;
    try checkSuccess(c.vkCreateShaderModule(logicalDevice, &createInfo, null, &shaderModule));

    return shaderModule;
}

fn createGraphicsPipeline() !void
{
    const vertShaderCode align(4) = @embedFile("../data/shader/vert.spv").*;
    const fragShaderCode align(4) = @embedFile("../data/shader/frag.spv").*;

    const vertShaderModule = try createShaderModule(&vertShaderCode);
    const fragShaderModule = try createShaderModule(&fragShaderCode);

    const vertShaderStageInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertShaderModule,
        .pName = "main",

        .pNext = null,
        .flags = 0,
        .pSpecializationInfo = null,
    };

    const fragShaderStageInfo = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragShaderModule,
        .pName = "main",
        .pNext = null,
        .flags = 0,

        .pSpecializationInfo = null,
    };

    const shaderStages = [_]c.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo };

    const vertexInputInfo = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .vertexAttributeDescriptionCount = 0,

        .pVertexBindingDescriptions = null,
        .pVertexAttributeDescriptions = null,
        .pNext = null,
        .flags = 0,
    };

    const inputAssembly = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
        .pNext = null,
        .flags = 0,
    };

// Dynamic state for these....
//    const viewport = [_]c.VkViewport{c.VkViewport{
//        .x = 0.0,
//        .y = 0.0, //@intToFloat(f32, swapChainExtent.height),
//        .width = @intToFloat(f32, swapchainImageSize.width),
//        .height = @intToFloat(f32, swapchainImageSize.height), // flipping viewport -height, y = height
//        .minDepth = 0.0,
//        .maxDepth = 1.0,
//    }};
//// dynamic state
//    const scissor = [_]c.VkRect2D{c.VkRect2D{
//        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
//        .extent = swapchainImageSize,
//    }};

    const viewportState = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = null, // dynamic &viewport,
        .scissorCount = 1,
        .pScissors = null, // dynamic .&scissor,

        .pNext = null,
        .flags = 0,
    };

    const rasterizer = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,

        .pNext = null,
        .flags = 0,
        .depthBiasConstantFactor = 0,
        .depthBiasClamp = 0,
        .depthBiasSlopeFactor = 0,
    };

    const multisampling = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        .pNext = null,
        .flags = 0,
        .minSampleShading = 0,
        .pSampleMask = null,
        .alphaToCoverageEnable = 0,
        .alphaToOneEnable = 0,
    };

    const colorBlendAttachment = c.VkPipelineColorBlendAttachmentState{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,

        .srcColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .dstColorBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .colorBlendOp = c.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VK_BLEND_OP_ADD,
    };

    const colorBlending = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &colorBlendAttachment,
        .blendConstants = [_]f32{ 0, 0, 0, 0 },

        .pNext = null,
        .flags = 0,
    };

    const pipelineLayoutInfo = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0,
        .pushConstantRangeCount = 0,
        .pNext = null,
        .flags = 0,
        .pSetLayouts = null,
        .pPushConstantRanges = null,
    };

    //const dynamicStates = ;
//    
//    typedef struct VkPipelineDynamicStateCreateInfo {
//    VkStructureType   sType;
//    const  void *             pNext;
//    VkPipelineDynamicStateCreateFlags      flags;
//    uint32_t                 dynamicStateCount;
//    const  VkDynamicState *   pDynamicStates;
//} VkPipelineDynamicStateCreateInfo;

    const dynamicStates = [_]c.VkDynamicState{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR };
    const dynamicStateInfo = c.VkPipelineDynamicStateCreateInfo{ 
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamicStates.len,
        .pDynamicStates = &dynamicStates,
        .flags = 0,
        .pNext = null
    };

    try checkSuccess(c.vkCreatePipelineLayout(logicalDevice, &pipelineLayoutInfo, null, &pipelineLayout));

    const pipelineInfo = [_]c.VkGraphicsPipelineCreateInfo{c.VkGraphicsPipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = @intCast(u32, shaderStages.len),
        .pStages = &shaderStages,
        .pVertexInputState = &vertexInputInfo,
        .pInputAssemblyState = &inputAssembly,
        .pViewportState = &viewportState,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &colorBlending,
        .layout = pipelineLayout,
        .renderPass = renderPass,
        .subpass = 0,
        .basePipelineHandle = null,

        .pNext = null,
        .flags = 0,
        .pTessellationState = null,
        .pDepthStencilState = null,
        .pDynamicState = &dynamicStateInfo,
        .basePipelineIndex = 0,
    }};

    try checkSuccess(c.vkCreateGraphicsPipelines(logicalDevice, null, @intCast(u32, pipelineInfo.len),
        &pipelineInfo, null, @as(*[1]c.VkPipeline, &graphicsPipeline),
    ));

    c.vkDestroyShaderModule(logicalDevice, fragShaderModule, null);
    c.vkDestroyShaderModule(logicalDevice, vertShaderModule, null);
}



fn createInstance(allocator: std.mem.Allocator) anyerror!void
{
    if(enableValidationLayers)
    {
        var layerCount: u32 = 0;
        try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, null));

        const layers = try allocator.alloc(c.VkLayerProperties, layerCount);
        defer allocator.free(layers);

        try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, layers.ptr));

        for (validationLayers) | layerName |
        {
            var layerFound = false;

            for (layers) | layerProp |
            {
                if (std.cstr.cmp(layerName, @ptrCast([*:0]const u8, &layerProp.layerName)) == 0)
                {
                    layerFound = true;
                    break;
                }
            }

            if (!layerFound)
            {
                print("Didnt find: {s}\n", .{layerName});
                return error.RequiredLayerNotFound;
            }
        }
    }

    var sdlExtensionCount: u32 = 0;

    if(c.SDL_Vulkan_GetInstanceExtensions(window, &sdlExtensionCount, null) == 0)
        return error.NoSDLExtensions;

    const sdlExtensions = try allocator.alloc([*c]const u8, sdlExtensionCount);
    defer allocator.free(sdlExtensions);

    if(c.SDL_Vulkan_GetInstanceExtensions(window, &sdlExtensionCount, sdlExtensions.ptr) == 0)
        return error.NoSDLExtensions;

    var extensions = std.ArrayList([*c]const u8).init(allocator);
    errdefer extensions.deinit();

    try extensions.appendSlice(sdlExtensions[0..sdlExtensionCount]);
    if (enableValidationLayers)
    {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME); //VK_EXT_DEBUG_REPORT_EXTENSION_NAME old
    }
    const neededExtension = extensions.toOwnedSlice();
    defer allocator.free(neededExtension);

    {
        var i: u32 = 0;
        while(i < neededExtension.len) : (i += 1)
        {
            print("SDL - {}/{}, ext: {s}\n", .{i + 1, neededExtension.len, neededExtension[i]});
        }
    }


    var availableExtensionCount: u32 = 0;
    try(checkSuccess(c.vkEnumerateInstanceExtensionProperties(0, &availableExtensionCount, null)));

    const availableExtensions = try allocator.alloc(c.VkExtensionProperties, availableExtensionCount);
    defer allocator.free(availableExtensions);

    try(checkSuccess(c.vkEnumerateInstanceExtensionProperties(0, &availableExtensionCount, availableExtensions.ptr)));

    {
        var i: u32 = 0;
        while(i < availableExtensionCount) : (i += 1)
        {
            // non-null terminated strings
            print("Vulkan - {}/{}, ext: {s}\n", .{i + 1, availableExtensionCount, @ptrCast([*:0]const u8, &availableExtensions[i].extensionName)});
        }
    }

    var appInfo = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Hello Triangle",
        .applicationVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .pEngineName = "No Engine",
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = c.VK_API_VERSION_1_2,
        .pNext = null,
    };

    var debugUtilMessengerCreateInfo = c.VkDebugUtilsMessengerCreateInfoEXT {
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = debugCallback,
        .pUserData = null,
        .flags = 0,
        .pNext = null
    };
    _ = debugUtilMessengerCreateInfo;

    var createInfo = c.VkInstanceCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .flags = 0,
        .enabledExtensionCount = @intCast(u32, neededExtension.len),
        .ppEnabledExtensionNames = neededExtension.ptr,
        .enabledLayerCount = if(enableValidationLayers) validationLayers.len else 0,
        .ppEnabledLayerNames = if(enableValidationLayers) &validationLayers else null,
        .pNext = if(enableValidationLayers) &debugUtilMessengerCreateInfo else null,
    };

    try(checkSuccess(c.vkCreateInstance(&createInfo, null, &instance)));

    if(enableValidationLayers)
    {
        const func = @ptrCast(c.PFN_vkCreateDebugUtilsMessengerEXT,
            c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")) orelse return error.NoDebugUtilExtension;

        try checkSuccess(func(instance, &debugUtilMessengerCreateInfo, null, &debugMessenger));
    }
}

fn pickPhysicalDevice(allocator: std.mem.Allocator) anyerror!void
{
    var deviceCount: u32 = 0;
    try(checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, null)));
    if(deviceCount == 0)
    {
        print("No vulkan devices found!\n", .{});
        return error.NoVulkanDevicesFound;
    }

    const devices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
    defer allocator.free(devices);

    try(checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, devices.ptr)));

    var i: u32 = 0;
    while(i < deviceCount) : (i += 1)
    {
        const device = devices[i];
        var deviceProperties: c.VkPhysicalDeviceProperties = undefined;
        var deviceFeatures: c.VkPhysicalDeviceFeatures = undefined;
        c.vkGetPhysicalDeviceProperties(device, &deviceProperties);
        c.vkGetPhysicalDeviceFeatures(device, &deviceFeatures);
        if(deviceProperties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)
        {
            print("Discrete gpu: {s}\n", .{deviceProperties.deviceName});
        }
        else if(deviceProperties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU)
        {
            print("Integrated gpu: {s}\n", .{deviceProperties.deviceName});
        }

        print("Device features: {}\n", .{deviceFeatures});
        if(deviceFeatures.shaderInt64 != 0)
        {
            print("Supports shaderint64\n", .{});
        }

        if(deviceFeatures.geometryShader == 0)
        {
            print("No geometry shader supported\n\n", .{});
            continue;
        }

        // Check device extensions
        if(deviceExtensions.len > 0)
        {
            var availableDeviceExtensionCount: u32 = 0;
            if(c.vkEnumerateDeviceExtensionProperties(device, null, &availableDeviceExtensionCount, null) != c.VK_SUCCESS)
            {
                print("Failed to enumerate device extensions.\n\n", .{});
                continue;
            }

            const availableDeviceExtensions = try allocator.alloc(c.VkExtensionProperties, availableDeviceExtensionCount);
            defer allocator.free(availableDeviceExtensions);

            if(c.vkEnumerateDeviceExtensionProperties(device, null, &availableDeviceExtensionCount, availableDeviceExtensions.ptr)  != c.VK_SUCCESS)
            {
                print("Failed to enumerate device extensions.\n\n", .{});
                continue;
            }

            var foundAllExtensions = true;
            for(deviceExtensions) |ext|
            {
                var index: u32 = 0;
                while(index < availableDeviceExtensionCount) : (index += 1)
                {
                    if (std.cstr.cmp(ext, @ptrCast([*:0]const u8, &availableDeviceExtensions[index].extensionName)) == 0)
                    {
                        break;
                    }
                }
                if(index == availableDeviceExtensionCount)
                {
                    print("Cannot find extension: {s}\n", .{ext});
                    foundAllExtensions = false;
                }
            }
            if(!foundAllExtensions)
            {
                print("Device was missing some extension\n\n", .{});
                continue;
            }
        }

        // Swapchain, maybe need to check capabilities like what surface srgb?
        {
            var formatCount: u32 = 0;
            if(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null) != c.VK_SUCCESS)
            {
                print("Failed to queue format count for swapchain\n", .{});
                continue;
            }

            var presentModeCount: u32 = 0;
            if(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null) != c.VK_SUCCESS)
            {
                print("Failed to queue present mode count for swapchain\n", .{});
                continue;
            }

            if(formatCount == 0 or presentModeCount == 0)
            {
                print("Failed to have swap chain\n", .{});
                continue;
            }
        }


        var subgroupProperties = c.VkPhysicalDeviceSubgroupProperties {
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES,
            .subgroupSize = 0,
            .supportedStages = 0,
            .supportedOperations = 0,
            .quadOperationsInAllStages = 0,
            .pNext = null
        };

        var physicalDeviceProperties = c.VkPhysicalDeviceProperties2 {
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
            .properties = deviceProperties,
            .pNext = &subgroupProperties
        };
        c.vkGetPhysicalDeviceProperties2(device, &physicalDeviceProperties);

        print("Subgroup size: {}\n", .{subgroupProperties.subgroupSize});
        print("Subgroup operations: {}\n\n", .{subgroupProperties.supportedOperations});
        if(subgroupProperties.subgroupSize < 16 or subgroupProperties.supportedOperations == 0)
        {
            print("Cannot use subgroup operations, or group size is less than 16.\n", .{});
            continue;
        }



        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

        const queues = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
        defer allocator.free(queues);
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queues.ptr);

        var j: u32 = 0;

        graphicsIndex = ~@as(u32, 0);
        transferIndex = ~@as(u32, 0);
        computeIndex = ~@as(u32, 0);
        presentIndex = ~@as(u32, 0);

        while(j < queueFamilyCount) : (j += 1)
        {
            // Probably bad to force all queues to work in same index. Transfer queue exists on graphics and compute....
            const bits = c.VK_QUEUE_GRAPHICS_BIT | c.VK_QUEUE_COMPUTE_BIT; // | c.VK_QUEUE_TRANSFER_BIT;
            const flags = queues[j].queueFlags;
            print("flags for family: {}\n", .{flags});
            if((queues[j].queueFlags & bits) != bits)
            {
                continue;
            }

            var presentSupport: c.VkBool32 = 0;
            if(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, j, surface, &presentSupport) != c.VK_SUCCESS)
            {
                print("Failed to get device surface support\n", .{});
                continue;
            }

            if (presentSupport == c.VK_FALSE)
                continue;

            graphicsIndex = j;
            transferIndex = j;
            computeIndex = j;
            presentIndex = j;
            break;
        }

        if(graphicsIndex == ~@as(u32, 0) or transferIndex == ~@as(u32, 0) or computeIndex == ~@as(u32, 0) or presentIndex ==~@as(u32, 0) )
        {
            print("Doesn't support needed queues.\n", .{});
            continue;
        }
        const queuePriority: f32 = 1.0;
        const queueCreateInfo = c.VkDeviceQueueCreateInfo {
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = graphicsIndex,
            .queueCount = 1,
            .pQueuePriorities = &queuePriority,
            .flags = 0,
            .pNext = null,
        };

        const queueInfos = [1]c.VkDeviceQueueCreateInfo { queueCreateInfo };

        const requestedFeatures = c.VkPhysicalDeviceFeatures{
            .robustBufferAccess = 0,
            .fullDrawIndexUint32 = 0,
            .imageCubeArray = 0,
            .independentBlend = 0,
            .geometryShader = 1,
            .tessellationShader = 0,
            .sampleRateShading = 0,
            .dualSrcBlend = 0,
            .logicOp = 0,
            .multiDrawIndirect = 0,
            .drawIndirectFirstInstance = 0,
            .depthClamp = 0,
            .depthBiasClamp = 0,
            .fillModeNonSolid = 0,
            .depthBounds = 0,
            .wideLines = 0,
            .largePoints = 0,
            .alphaToOne = 0,
            .multiViewport = 0,
            .samplerAnisotropy = 0,
            .textureCompressionETC2 = 0,
            .textureCompressionASTC_LDR = 0,
            .textureCompressionBC = 0,
            .occlusionQueryPrecise = 0,
            .pipelineStatisticsQuery = 0,
            .vertexPipelineStoresAndAtomics = 0,
            .fragmentStoresAndAtomics = 0,
            .shaderTessellationAndGeometryPointSize = 0,
            .shaderImageGatherExtended = 0,
            .shaderStorageImageExtendedFormats = 0,
            .shaderStorageImageMultisample = 0,
            .shaderStorageImageReadWithoutFormat = 0,
            .shaderStorageImageWriteWithoutFormat = 0,
            .shaderUniformBufferArrayDynamicIndexing = 0,
            .shaderSampledImageArrayDynamicIndexing = 0,
            .shaderStorageBufferArrayDynamicIndexing = 0,
            .shaderStorageImageArrayDynamicIndexing = 0,
            .shaderClipDistance = 0,
            .shaderCullDistance = 0,
            .shaderFloat64 = 0,
            .shaderInt64 = 1,
            .shaderInt16 = 0,
            .shaderResourceResidency = 0,
            .shaderResourceMinLod = 0,
            .sparseBinding = 0,
            .sparseResidencyBuffer = 0,
            .sparseResidencyImage2D = 0,
            .sparseResidencyImage3D = 0,
            .sparseResidency2Samples = 0,
            .sparseResidency4Samples = 0,
            .sparseResidency8Samples = 0,
            .sparseResidency16Samples = 0,
            .sparseResidencyAliased = 0,
            .variableMultisampleRate = 0,
            .inheritedQueries = 0,
        };

        const deviceCreateInfo = c.VkDeviceCreateInfo {
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,

            .pQueueCreateInfos = &queueInfos,
            .queueCreateInfoCount = 1,
            .pEnabledFeatures = &requestedFeatures,

            .enabledLayerCount = if(enableValidationLayers) validationLayers.len else 0,
            .ppEnabledLayerNames = if(enableValidationLayers) &validationLayers else null,

            .enabledExtensionCount = deviceExtensions.len,
            .ppEnabledExtensionNames = &deviceExtensions,

            .flags = 0,
            .pNext = null
        };
        if (c.vkCreateDevice(device, &deviceCreateInfo, null, &logicalDevice) != c.VK_SUCCESS)
        {
            print("Failed to create logical device.\n", .{});
            continue;
        }

        physicalDevice = device;
        c.vkGetDeviceQueue(logicalDevice, presentIndex, 0, &presentQueue);
        c.vkGetDeviceQueue(logicalDevice, graphicsIndex, 0, &graphicsQueue);
        c.vkGetDeviceQueue(logicalDevice, computeIndex, 0, &computeQueue);
        c.vkGetDeviceQueue(logicalDevice, transferIndex, 0, &transferQueue);
        print("pres: {}, graph: {} comp: {}, trans: {}\n", .{presentIndex, graphicsIndex, computeIndex, transferIndex});
        break;
    }

    if(logicalDevice == null)
    {
        print("Failed to find working logical device.\n", .{});
        return error.PhysicalDeviceNotFound;
    }
}

fn createSwapchain(allocator: std.mem.Allocator) anyerror !void
{
    resized = false;
 
    var formatCount: u32 = 0;
    try checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, null));

    var presentModeCount: u32 = 0;
    try checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, &presentModeCount, null));

    if(formatCount == 0 or presentModeCount == 0)
    {
        print("Failed to have swap chain\n", .{});
        return error.FailedToCreateSwapchain;
    }

    const formats = try allocator.alloc(c.VkSurfaceFormatKHR, formatCount);
    defer allocator.free(formats);
    try checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, &formatCount, formats.ptr));

    const presentModes = try allocator.alloc(c.VkPresentModeKHR, presentModeCount);
    defer allocator.free(presentModes);
    try checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(physicalDevice, surface, &presentModeCount, presentModes.ptr));

    {
        swapchainFormat = formats[0];
        if (formatCount == 1 and formats[0].format == c.VK_FORMAT_UNDEFINED)
        {
            swapchainFormat = c.VkSurfaceFormatKHR {
                .format = c.VK_FORMAT_B8G8R8A8_UNORM,
                .colorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            };
        }
        else
        {
            var i: u32 = 0;
            while(i < formatCount) : (i += 1)
            {
                if (formats[i].format == swapchainWantedFormat.format and
                    formats[i].colorSpace == swapchainWantedFormat.colorSpace)
                {
                    swapchainFormat = swapchainWantedFormat;
                    break;
                }

            }
        }
        print("Swapchainformat: {}\n", .{swapchainFormat});
    }
    {
        var i: u32 = 0;
        presentMode = c.VK_PRESENT_MODE_FIFO_KHR;
        while(i < presentModeCount) : (i += 1)
        {
            if(presentModes[i] == presentModeWanted)
            {
                presentMode = presentModeWanted;
                break;
            }
        }
        print("presentMode: {}\n", .{presentMode});
    }

    {
        var capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        try checkSuccess(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, &capabilities));

        if(capabilities.currentExtent.width != std.math.maxInt(u32))
        {
            swapchainImageSize = capabilities.currentExtent;
        }
        else
        {
            var w: i32 = 0;
            var h: i32 = 0;
            c.SDL_Vulkan_GetDrawableSize(window, &w, &h);

            swapchainImageSize.width = std.math.max(capabilities.minImageExtent.width, std.math.min(capabilities.maxImageExtent.width, w));
            swapchainImageSize.height = std.math.max(capabilities.minImageExtent.height, std.math.min(capabilities.maxImageExtent.height, h));
        }
        print("swapchainimagesize: {}\n", .{swapchainImageSize});
        print("capabilities: {}\n", .{capabilities});
        var imageCount: u32 = capabilities.minImageCount + 1;
        if (capabilities.maxImageCount > 0 and imageCount > capabilities.maxImageCount)
        {
            imageCount = capabilities.maxImageCount;
        }

        var swapchainCreateInfo = c.VkSwapchainCreateInfoKHR {
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,

            .minImageCount = imageCount,
            .imageFormat = swapchainFormat.format,
            .imageColorSpace = swapchainFormat.colorSpace,
            .imageExtent = swapchainImageSize,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,

            .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0, // NOTICE SET THIS TO 0 OR 2+, CAN CRASH WITH 1
            .pQueueFamilyIndices = &([_]u32{ 0, 0 }),

            .preTransform = capabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = presentMode,
            .clipped = c.VK_TRUE,

            .oldSwapchain = swapChain,

            .pNext = null,
            .flags = 0,
        };

         try checkSuccess(c.vkCreateSwapchainKHR(logicalDevice, &swapchainCreateInfo, null, &swapChain));

        //swapChainImages
        try checkSuccess(c.vkGetSwapchainImagesKHR(logicalDevice, swapChain, &imageCount, null));
        swapChainImages = try allocator.alloc(c.VkImage, imageCount);
        try checkSuccess(c.vkGetSwapchainImagesKHR(logicalDevice, swapChain, &imageCount, swapChainImages.ptr));

        swapChainImageViews = try allocator.alloc(c.VkImageView, swapChainImages.len);
        errdefer allocator.free(swapChainImageViews);

        for( swapChainImages ) |swapchainImage, i|
        {
            const imageViewCreateInfo = c.VkImageViewCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = swapchainImage,
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .format = swapchainFormat.format,
                .components = c.VkComponentMapping {
                    .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = c.VkImageSubresourceRange{
                    .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },

                .pNext = null,
                .flags = 0,
            };
            try checkSuccess(c.vkCreateImageView(logicalDevice, &imageViewCreateInfo, null, &swapChainImageViews[i]));
        }
    }
}