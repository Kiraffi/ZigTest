
pub const Vec2 = extern struct
{
    x: f32,
    y: f32,
};
pub const Vec3 = extern struct
{
    x: f32,
    y: f32,
    z: f32,
};
pub const Vec4 = extern struct
{
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const UVec2 = extern struct
{
    x: u32,
    y: u32,
};
pub const UVec3 = extern struct
{
    x: u32,
    y: u32,
    z: u32,
};
pub const UVec4 = extern struct
{
    x: u32,
    y: u32,
    z: u32,
    w: u32,
};

pub const IVec2 = extern struct
{
    x: i32,
    y: i32,
};
pub const IVec3 = extern struct
{
    x: i32,
    y: i32,
    z: i32,
};
pub const IVec4 = extern struct
{
    x: i32,
    y: i32,
    z: i32,
    w: i32,
};


pub fn cross3(comptime typ: type, v1: typ, v2: typ) typ
{
    var v: typ = undefined;
    v.x = v1.y * v2.z - v1.z * v2.y;
    v.y = v1.z * v2.x - v1.x * v2.z;
    v.z = v1.x * v2.y - v1.y * v2.x;
    return v;
}


pub fn add(comptime typ: type , v1: typ , v2: typ ) typ
{
    if(typ == Vec2 or typ == UVec2 or typ == IVec2)
    {
        return typ {.x = v1.x + v2.x, .y = v1.y + v2.y };
    }
    else if(typ == Vec3 or typ == UVec3 or typ == IVec3)
    {
        return typ {.x = v1.x + v2.x, .y = v1.y + v2.y, .z = v1.z + v2.z };
    }
    else if(typ == Vec4 or typ == UVec4 or typ == IVec4)
    {
        return typ {.x = v1.x + v2.x, .y = v1.y + v2.y, .z = v1.z + v2.z, .w = v1.w + v2.w };
    }
    else
    {
        unreachable;
    }
}


pub fn mul(comptime typ: type , v1: typ , v2: typ ) typ
{
    if(typ == Vec2 or typ == UVec2 or typ == IVec2)
    {
        return typ {.x = v1.x * v2.x, .y = v1.y * v2.y };
    }
    else if(typ == Vec3 or typ == UVec3 or typ == IVec3)
    {
        return typ {.x = v1.x * v2.x, .y = v1.y * v2.y, .z = v1.z * v2.z };
    }
    else if(typ == Vec4 or typ == UVec4 or typ == IVec4)
    {
        return typ {.x = v1.x * v2.x, .y = v1.y * v2.y, .z = v1.z * v2.z, .w = v1.w * v2.w };
    }
    else
    {
        unreachable;
    }
}


pub fn dot2f(v1: Vec2, v2: Vec2) f32
{
    return v1.x * v2.x + v1.y * v2.y;
}
pub fn dot3f(v1: Vec3, v2: Vec3) f32
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}
pub fn dot4f(v1: Vec4, v2: Vec4) f32
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z + v1.w * v2.w;
}

pub fn dot2u(v1: UVec2, v2: UVec2) u32
{
    return v1.x * v2.x + v1.y * v2.y;
}
pub fn dot3u(v1: UVec3, v2: UVec3) u32
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}
pub fn dot4u(v1: UVec4, v2: UVec4) u32
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z + v1.w * v2.w;
}


pub fn dot2i(v1: IVec2, v2: IVec2) u32
{
    return v1.x * v2.x + v1.y * v2.y;
}
pub fn dot3i(v1: IVec3, v2: IVec3) u32
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}
pub fn dot4i(v1: IVec4, v2: IVec4) u32
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z + v1.w * v2.w;
}

