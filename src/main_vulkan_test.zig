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

var window: ?*c.SDL_Window = null;

var currentFrame: usize = 0;
var instance: c.VkInstance = undefined;
var callback: c.VkDebugReportCallbackEXT = c.VK_NULL_HANDLE; // NEEDED?
var surface: c.VkSurfaceKHR = null;
var physicalDevice: c.VkPhysicalDevice = null; // Is this needed?
var logicalDevice: c.VkDevice = null;

var graphicsQueue: c.VkQueue = null;
var presentQueue: c.VkQueue = null;
var computeQueue: c.VkQueue = null;
var transferQueue: c.VkQueue = null;
var uniqueQueues: u32 = 0;


var swapChainImages: []c.VkImage = undefined;
var swapChain: c.VkSwapchainKHR = c.VK_NULL_HANDLE;
var swapChainImageFormat: c.VkFormat = c.VK_NULL_HANDLE;
var swapChainExtent: c.VkExtent2D = c.VK_NULL_HANDLE;
var swapChainImageViews: []c.VkImageView = undefined;
var renderPass: c.VkRenderPass = c.VK_NULL_HANDLE;
var pipelineLayout: c.VkPipelineLayout = c.VK_NULL_HANDLE;
var graphicsPipeline: c.VkPipeline = c.VK_NULL_HANDLE;
var swapChainFramebuffers: []c.VkFramebuffer = undefined;
var commandPool: c.VkCommandPool = c.VK_NULL_HANDLE;
var commandBuffers: []c.VkCommandBuffer = undefined;

var debugMessenger: c.VkDebugUtilsMessengerEXT = c.VK_NULL_HANDLE;


fn debugCallback(messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT, messageType: c.VkDebugUtilsMessageTypeFlagsEXT,
    pCallbackData: [*c]const c.VkDebugUtilsMessengerCallbackDataEXT, pUserData: ?*anyopaque) callconv(.C) c.VkBool32
{
    _ = messageType;
    _ = pUserData;
    if (messageSeverity >= c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) 
    {
        const data = pCallbackData.*;
        print("Validation layer: {s}\n", .{data.pMessage});
    }
    return c.VK_FALSE;
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

    const sdlExtensions = try allocator.alloc([*c]const u8, if(enableValidationLayers) sdlExtensionCount + 1 else sdlExtensionCount);
    defer allocator.free(sdlExtensions);

    if(c.SDL_Vulkan_GetInstanceExtensions(window, &sdlExtensionCount, sdlExtensions.ptr) == 0)
        return error.NoSDLExtensions;

    if(enableValidationLayers)
    {
        sdlExtensionCount += 1;
        sdlExtensions[sdlExtensionCount - 1] = c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    }


    {
        var i: u32 = 0;
        while(i < sdlExtensionCount) : (i += 1)
        {
            print("SDL - {}/{}, ext: {s}\n", .{i + 1, sdlExtensionCount, sdlExtensions[i]});
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

    var createInfo = c.VkInstanceCreateInfo {
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &appInfo,
        .flags = 0,
        .enabledExtensionCount = sdlExtensionCount,
        .ppEnabledExtensionNames = sdlExtensions.ptr,
        .enabledLayerCount = if(enableValidationLayers) validationLayers.len else 0,
        .ppEnabledLayerNames = if(enableValidationLayers) &validationLayers else null,
        .pNext = if(enableValidationLayers) &debugUtilMessengerCreateInfo else null,
    };

    try(checkSuccess(c.vkCreateInstance(&createInfo, null, &instance)));
}

pub fn main() anyerror!void
{
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());

    const allocator = general_purpose_allocator.allocator();

    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    window = c.SDL_CreateWindow("SDL vulkan zig test", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_SHOWN);
    defer c.SDL_DestroyWindow(window);

    try(createInstance(allocator));
    defer c.vkDestroyInstance(instance, null);


    // Create surface!
    if (c.SDL_Vulkan_CreateSurface(window, instance, &surface) != c.SDL_TRUE)
    {
        print("Failed to create surface\n", .{});
        return error.FailedToSDLVulkanCreateSurface;
    }
    defer c.vkDestroySurfaceKHR(instance, surface, null);

    // Pick physical device!
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
            var graphicsIndex: u32 = ~@as(u32, 0);
            var transferIndex: u32 = ~@as(u32, 0);
            var computeIndex: u32 = ~@as(u32, 0);
            var presentIndex: u32 = ~@as(u32, 0);

            while(j < queueFamilyCount) : (j += 1)
            {
                // Probably bad to force all queues to work in same index.
                const bits = c.VK_QUEUE_GRAPHICS_BIT | c.VK_QUEUE_COMPUTE_BIT | c.VK_QUEUE_TRANSFER_BIT;
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

                if (presentSupport == 0)
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
            var queueCreateInfo = c.VkDeviceQueueCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = graphicsIndex,
                .queueCount = 1,
                .pQueuePriorities = &queuePriority,
                .flags = 0,
                .pNext = null,
            };
            
            var  deviceCreateInfo = c.VkDeviceCreateInfo {
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .pQueueCreateInfos = &queueCreateInfo,
                .queueCreateInfoCount = 1,
                .pEnabledFeatures = &deviceFeatures,
                .enabledLayerCount = if(enableValidationLayers) validationLayers.len else 0,
                .ppEnabledLayerNames = if(enableValidationLayers) &validationLayers else null,
                .enabledExtensionCount = deviceExtensions.len,
                .ppEnabledExtensionNames = &deviceExtensions,
                .flags = 0,
                .pNext = null
            };
            var tmpDevice: c.VkDevice = undefined;
            if (c.vkCreateDevice(device, &deviceCreateInfo, null, &tmpDevice) != c.VK_SUCCESS) 
            {
                print("Failed to create logical device.\n", .{});
                continue;
            }
            physicalDevice = device;
            logicalDevice = tmpDevice;
            c.vkGetDeviceQueue(logicalDevice, presentIndex, 0, &presentQueue);
            c.vkGetDeviceQueue(logicalDevice, graphicsIndex, 0, &graphicsQueue);
            c.vkGetDeviceQueue(logicalDevice, computeIndex, 0, &computeQueue);
            c.vkGetDeviceQueue(logicalDevice, transferIndex, 0, &transferQueue);
            
            break;
        }

        if(logicalDevice == null)
        {
            print("Failed to find working logical device.\n", .{});
            return error.PhysicalDeviceNotFound;
        }
    }
    defer c.vkDestroyDevice(logicalDevice, null);
}


