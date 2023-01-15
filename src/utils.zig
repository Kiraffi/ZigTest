pub fn getColor(r: f32, g: f32, b: f32, a: f32) u32
{
    const rr = @min(255, @max(0, @floatToInt(u32, r * 255.0)));
    const gg = @min(255, @max(0, @floatToInt(u32, g * 255.0)));
    const bb = @min(255, @max(0, @floatToInt(u32, b * 255.0)));
    const aa = @min(255, @max(0, @floatToInt(u32, a * 255.0)));
    return rr + (gg << 8) + (bb << 16) + (aa << 24);
}

pub fn getColor256(r: u32, g: u32, b: u32, a: u32) u32
{
    const rr = @min(255, @max(0, r));
    const gg = @min(255, @max(0, g));
    const bb = @min(255, @max(0, b));
    const aa = @min(255, @max(0, a));
    return rr + (gg << 8) + (bb << 16) + (aa << 24);
}

