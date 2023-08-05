pub fn getColor(r: f32, g: f32, b: f32, a: f32) u32
{
    const rr: u32 = @min(255, @max(0, @as(u32, @intFromFloat(r * 255.0))));
    const gg: u32 = @min(255, @max(0, @as(u32, @intFromFloat(g * 255.0))));
    const bb: u32 = @min(255, @max(0, @as(u32, @intFromFloat(b * 255.0))));
    const aa: u32 = @min(255, @max(0, @as(u32, @intFromFloat(a * 255.0))));
    return rr + (gg << 8) + (bb << 16) + (aa << 24);
}

pub fn getColor256(r: u32, g: u32, b: u32, a: u32) u32
{
    const rr: u32 = @min(255, @as(u32, @max(0, r)));
    const gg: u32 = @min(255, @as(u32, @max(0, g)));
    const bb: u32 = @min(255, @as(u32, @max(0, b)));
    const aa: u32 = @min(255, @as(u32, @max(0, a)));
    return rr + (gg << 8) + (bb << 16) + (aa << 24);
}

