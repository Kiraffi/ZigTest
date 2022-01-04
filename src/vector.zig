const std = @import("std");
const assert = std.debug.assert;
const Vector = std.meta.Vector;


pub const Vec2 = Vector(2, f32);
pub const Vec3 = Vector(3, f32);
pub const Vec4 = Vector(4, f32);

pub const UVec2 = Vector(2, u32);
pub const UVec3 = Vector(3, u32);
pub const UVec4 = Vector(4, u32);

pub const IVec2 = Vector(2, i32);
pub const IVec3 = Vector(3, i32);
pub const IVec4 = Vector(4, i32);

pub const Mat44 = Vector(16, f32);


pub const Quat = extern struct
{
    v: Vec3 = Vec3{0.0, 0.0, 0.0 },
    w: f32 = 1.0,
};


pub fn cross3(v1: anytype, v2: anytype) @TypeOf(v1)
{
    assert(@TypeOf(v1) == @TypeOf(v2));
    var v: @TypeOf(v1) = undefined;
    v[0] = v1[1] * v2[2] - v1[2] * v2[1];
    v[1] = v1[2] * v2[0] - v1[0] * v2[2];
    v[2] = v1[0] * v2[1] - v1[1] * v2[0];
    return v;
}

pub fn sqLen(v1: anytype) @TypeOf(v1.x)
{
    return dot(v1, v1);
}

pub fn len(v1: anytype) f32
{
    return std.math.sqrt.sqrt(dot(v1, v1));
}

const MinLen: f32 = 1.0e-15;

pub fn normalize(v1: anytype) @TypeOf(v1)
{
    const typ = @TypeOf(v1);
    if(typ == Vec2 or typ == UVec2 or typ == IVec2)
    {
        const le = len(typ, v1);
        assert(le >= MinLen);
        const l = 1.0 / le;
        return typ{ v1[0] * l, v1[1] * l };
    }
    else if(typ == Vec3 or typ == UVec3 or typ == IVec3)
    {
        const le = len(typ, v1);
        assert(le >= MinLen);
        const l = 1.0 / le;
        return typ{ v1[0] * l, v1[1] * l, v1[2] * l };
    }
    else if(typ == Vec4 or typ == UVec4 or typ == IVec4)
    {
        const le = len(typ, v1);
        assert(le >= MinLen);
        const l = 1.0 / le;
        return typ{ v1[0] * l, v1[1] * l, v1[2] * l, v1[3] * l };
    }
    else if(typ == Quat)
    {
        var result = Quat{};
        result.w = std.math.clamp(v1.w, -1.0, 1.0);
        if(result.w != 1.0 and result.w != -1.0)
            result.v = normalize(Vec3, v1.v) * std.math.sqrt(1.0 - result.w * result.w);
        return result;
    }
    else
    {
        unreachable;
    }
}

pub fn add(v1: anytype, v2: anytype ) ReturnType(@TypeOf(v1), @TypeOf(v2))
{
    const t1 = @TypeOf(v1);
    const t2 = @TypeOf(v2);
    if(t1 == t2)
    {
        switch(t1)
        {
            Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => return v1 + v2,
            else => {},
        }
        unreachable;
    }
    switch(t1)
    {
        Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => return addScalar(v1, v2),
        else => {},
    }
    switch(t2)
    {
        Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => return addScalar(v2, v1),
        else => {},
    }
    unreachable;
}

// Is there some sense to have quaternion scalar multiply?
fn ReturnType(comptime A: type, comptime B: type) type
{
    if( A == B)
        return A;
    if( (A == Mat44 and B == Vec4) or (A == Vec4 and B == Mat44) )
        return Vec4;

    switch(A)
    {
        Vec2, Vec3, Vec4, Mat44 => {
            if(B == f32)
                return A;
        },
        UVec2, UVec3, UVec4 => {
            if(B == u32)
                return A;
        },
        IVec2, IVec3, IVec4 => {
            if(B == i32)
                return A;
        },
        else => {}
    }
    switch(B)
    {
        Vec2, Vec3, Vec4, Mat44 => {
            if(A == f32)
                return B;
        },
        UVec2, UVec3, UVec4 => {
            if(A == u32)
                return B;
        },
        IVec2, IVec3, IVec4 => {
            if(A == i32)
                return B;
        },
        else => {}
    }

    unreachable;
}

pub fn mul(v1: anytype, v2: anytype ) ReturnType(@TypeOf(v1), @TypeOf(v2))
{
    const t1 = @TypeOf(v1);
    const t2 = @TypeOf(v2);
    if(t1 == t2)
    {
        switch(t1)
        {
            Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => return v1 * v2,
            Mat44 => {
                var r: Mat44 = undefined;
                r[0] = v1[0] * v2[0] + v1[1] * v2[4] + v1[2] * v2[ 8] + v1[3] * v2[12];
                r[1] = v1[0] * v2[1] + v1[1] * v2[5] + v1[2] * v2[ 9] + v1[3] * v2[13];
                r[2] = v1[0] * v2[2] + v1[1] * v2[6] + v1[2] * v2[10] + v1[3] * v2[14];
                r[3] = v1[0] * v2[3] + v1[1] * v2[7] + v1[2] * v2[11] + v1[3] * v2[15];

                r[4] = v1[4] * v2[0] + v1[5] * v2[4] + v1[6] * v2[ 8] + v1[7] * v2[12];
                r[5] = v1[4] * v2[1] + v1[5] * v2[5] + v1[6] * v2[ 9] + v1[7] * v2[13];
                r[6] = v1[4] * v2[2] + v1[5] * v2[6] + v1[6] * v2[10] + v1[7] * v2[14];
                r[7] = v1[4] * v2[3] + v1[5] * v2[7] + v1[6] * v2[11] + v1[7] * v2[15];

                r[ 8] = v1[8] * v2[0] + v1[9] * v2[4] + v1[10] * v2[ 8] + v1[11] * v2[12];
                r[ 9] = v1[8] * v2[1] + v1[9] * v2[5] + v1[10] * v2[ 9] + v1[11] * v2[13];
                r[10] = v1[8] * v2[2] + v1[9] * v2[6] + v1[10] * v2[10] + v1[11] * v2[14];
                r[11] = v1[8] * v2[3] + v1[9] * v2[7] + v1[10] * v2[11] + v1[11] * v2[15];

                r[12] = v1[12] * v2[0] + v1[13] * v2[4] + v1[14] * v2[ 8] + v1[15] * v2[12];
                r[13] = v1[12] * v2[1] + v1[13] * v2[5] + v1[14] * v2[ 9] + v1[15] * v2[13];
                r[14] = v1[12] * v2[2] + v1[13] * v2[6] + v1[14] * v2[10] + v1[15] * v2[14];
                r[15] = v1[12] * v2[3] + v1[13] * v2[7] + v1[14] * v2[11] + v1[15] * v2[15];
                return r;
            },
            Quat => {
                const v3 = Vec3{v2[0] * v1.w + v1[0] * v2.w, v2[1] * v1.w + v1[1] * v2.w, v2[2] * v1.w + v1[2] * v2.w };
                const v4 = cross3(v1.v, v2.v);
                const v5 = Vec3{v3[0] + v4[0], v3[1] + v4[1], v3[2] + v4[2] };
                return Quat{.v = v5, .w = v1.w * v2.w - dot(Vec3, v1.v, v2.v) };
            },
            else => { unreachable; }
        }
    }
    else if(t1 == Mat44 and t2 == Vec4)
    {
        var r: Vec4 = undefined;
        r[0] = v2[0] * (v1[0]  + v1[1]  + v1[2]  + v1[3]);
        r[1] = v2[1] * (v1[4]  + v1[5]  + v1[6]  + v1[7]);
        r[2] = v2[2] * (v1[8]  + v1[9]  + v1[10] + v1[11]);
        r.w = v2.w * (v1[12] + v1[13] + v1[14] + v1[14]);

        return r;
    }
    else if(t1 == Vec4 and t2 == Mat44)
    {
        var r: Vec4 = undefined;
        r[0] = v1[0] * v2[0]  + v1[1] * v2[1]  + v1[2] * v2[ 2] + v1.w * v2[ 3];
        r[1] = v1[0] * v2[4]  + v1[1] * v2[5]  + v1[2] * v2[ 6] + v1.w * v2[ 7];
        r[2] = v1[0] * v2[8]  + v1[1] * v2[9]  + v1[2] * v2[10] + v1.w * v2[11];
        r.w = v1[0] * v2[12] + v1[1] * v2[13] + v1[2] * v2[14] + v1.w * v2[15];
        return r;
    }

    switch(t1)
    {
        Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => return mulScalar(v1, v2),
        else => {},
    }
    switch(t2)
    {
        Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => return mulScalar(v2, v1),
        else => {},
    }
    unreachable;
}

fn mulScalar(v1: anytype, s: anytype) @TypeOf(v1)
{
    if(@TypeOf(s) != @TypeOf(v1[0]))
        unreachable;
    const t1 = @TypeOf(v1);
    switch(t1)
    {
        Vec2, UVec2, IVec2 => return t1{v1[0] * s, v1[1] * s },
        Vec3, UVec3, IVec3 => return t1{v1[0] * s, v1[1] * s, v1[2] * s },
        Vec4, UVec4, IVec4 => return t1{v1[0] * s, v1[1] * s, v1[2] * s, v1[3] * s },
        else => {},
    }
    unreachable;
}

fn addScalar(v1: anytype, s: anytype) @TypeOf(v1)
{
    if(@TypeOf(s) != @TypeOf(v1[0]))
        unreachable;
    const t1 = @TypeOf(v1);
    switch(t1)
    {
        Vec2, UVec2, IVec2 => return t1{v1[0] + s, v1[1] + s },
        Vec3, UVec3, IVec3 => return t1{v1[0] + s, v1[1] + s, v1[2] + s },
        Vec4, UVec4, IVec4 => return t1{v1[0] + s, v1[1] + s, v1[2] + s, v1[3] + s },
        else => {},
    }
    unreachable;
}


pub fn dot(comptime typ: type, v1: typ, v2: typ) @TypeOf(v1[0])
{
    if(typ == Vec2 or typ == UVec2 or typ == IVec2)
    {
        return v1[0] * v2[0] + v1[1] * v2[1];
    }
    else if(typ == Vec3 or typ == UVec3 or typ == IVec3)
    {
        return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
    }
    else if(typ == Vec4 or typ == UVec4 or typ == IVec4)
    {
        return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1.w * v2.w;
    }
    else
    {
        unreachable;
    }
}

pub fn createPerspectiveMatrixRH(fovRad: f32, aspectRatio: f32, nearPlane: f32, farPlane: f32) Mat44
{
    assert(std.math.fabs(fovRad) > 0.00001);
    assert(std.math.fabs(aspectRatio) > 0.001);
    assert(std.math.fabs(farPlane - nearPlane) > 0.00001);
    assert(std.math.fabs(nearPlane) > 0.0);

    const yScale: f32 = 1.0 / std.math.tan(fovRad * 0.5);
    const xScale: f32 = yScale / aspectRatio;
    const fRange: f32 = farPlane / (farPlane - nearPlane);

    var result = Mat44{};
    result[0] = xScale;
    result[1] = yScale;

    result[10] = -fRange;
    result[11] = -1.0;
    result[14] = -nearPlane * fRange;
    result[15] = 0.0;
    return result;
}

pub fn createMatrixFromLookAt(pos: *const Vec3, target: *const Vec3, up: *const Vec3) Mat44
{
    const dis = target - pos;
    const forward = normalize(Vec3, dis);
    const right = normalize(Vec3, cross3(up, forward));
    const realUp = normalize(Vec3, cross3(forward, right));

    var result: Mat44 = undefined;
    result[0] = right[0];
    result[1] = realUp[0];
    result[2] = forward[0];
    result[3] = 0.0;

    result[4] = right[1];
    result[5] = realUp[1];
    result[6] = forward[1];
    result[7] = 0.0;

    result[8]  = right[2];
    result[9]  = realUp[2];
    result[10] = forward[2];
    result[11] = 0.0;

    result[12] = -dot(Vec3, pos, right);
    result[13] = -dot(Vec3, pos, realUp);
    result[14] = -dot(Vec3, pos, forward);
    result[15] = 1.0;
    return result;
}

pub fn transposeMat44(v1: Mat44) Mat44
{
    var result: Mat44 = undefined;
    result[0] = v1[0];
    result[1] = v1[4];
    result[2] = v1[8];
    result[3] = v1[12];

    result[4] = v1[1];
    result[5] = v1[5];
    result[6] = v1[9];
    result[7] = v1[13];

    result[8]  = v1[2];
    result[9]  = v1[6];
    result[10] = v1[10];
    result[11] = v1[14];

    result[12] = v1[3];
    result[13] = v1[7];
    result[14] = v1[11];
    result[15] = v1[15];

    return result;
}


