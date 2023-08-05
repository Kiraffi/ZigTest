const std = @import("std");
const assert = std.debug.assert;
//const Vector = std.meta.Vector;


pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);

pub const UVec2 = @Vector(2, u32);
pub const UVec3 = @Vector(3, u32);
pub const UVec4 = @Vector(4, u32);

pub const IVec2 = @Vector(2, i32);
pub const IVec3 = @Vector(3, i32);
pub const IVec4 = @Vector(4, i32);

pub const Mat44 = @Vector(16, f32);

pub const Mat44Identity =  Mat44{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
pub const Quat = extern struct
{
    v: Vec3 = Vec3{0.0, 0.0, 0.0},
    w: f32 = 1.0,
};


pub fn cross(v1: anytype, v2: anytype) @TypeOf(v1)
{
    assert(@TypeOf(v1) == @TypeOf(v2));
    var v: @TypeOf(v1) = undefined;
    v[0] = v1[1] * v2[2] - v1[2] * v2[1];
    v[1] = v1[2] * v2[0] - v1[0] * v2[2];
    v[2] = v1[0] * v2[1] - v1[1] * v2[0];
    return v;
}

pub fn sqrLen(v1: anytype) @TypeOf(v1[0])
{
    return dot(v1, v1);
}

pub fn len(v1: anytype) f32
{
    return std.math.sqrt(dot(v1, v1));
}

const MinLen: f32 = 1.0e-15;

pub fn normalize(v1: anytype) @TypeOf(v1)
{
    const typ = @TypeOf(v1);
    switch(typ)
    {
        Vec2, UVec2, IVec2, Vec3, UVec3, IVec3, Vec4, IVec4, UVec4 => {
            const le = len(v1);
            assert(le >= MinLen);
            const l = 1.0 / le;
            return mul(v1, l);
        },
        Quat => {
            var result = Quat{};
            result.w = std.math.clamp(v1.w, -1.0, 1.0);
            if(result.w != 1.0 and result.w != -1.0)
                result.v = mul(normalize(v1.v), std.math.sqrt(1.0 - result.w * result.w));
            return result;
        },
        else => {}
    }

    unreachable;
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
                r[0]  = v1[0] * v2[0] + v1[1] * v2[4] + v1[2] * v2[ 8] + v1[3] * v2[12];
                r[1]  = v1[0] * v2[1] + v1[1] * v2[5] + v1[2] * v2[ 9] + v1[3] * v2[13];
                r[2]  = v1[0] * v2[2] + v1[1] * v2[6] + v1[2] * v2[10] + v1[3] * v2[14];
                r[3]  = v1[0] * v2[3] + v1[1] * v2[7] + v1[2] * v2[11] + v1[3] * v2[15];

                r[4]  = v1[4] * v2[0] + v1[5] * v2[4] + v1[6] * v2[ 8] + v1[7] * v2[12];
                r[5]  = v1[4] * v2[1] + v1[5] * v2[5] + v1[6] * v2[ 9] + v1[7] * v2[13];
                r[6]  = v1[4] * v2[2] + v1[5] * v2[6] + v1[6] * v2[10] + v1[7] * v2[14];
                r[7]  = v1[4] * v2[3] + v1[5] * v2[7] + v1[6] * v2[11] + v1[7] * v2[15];

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
                const v3 = mul(v2.v, v1.w) + mul(v1.v, v2.w);
                const v4 = cross(v1.v, v2.v);
                const v5 = v3 + v4;
                return Quat{.v = v5, .w = v1.w * v2.w - dot(v1.v, v2.v) };
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
        r[3] = v2[3] * (v1[12] + v1[13] + v1[14] + v1[14]);

        return r;
    }
    else if(t1 == Vec4 and t2 == Mat44)
    {
        var r: Vec4 = undefined;
        r[0] = v1[0] * v2[0]  + v1[1] * v2[1]  + v1[2] * v2[ 2] + v1[3] * v2[ 3];
        r[1] = v1[0] * v2[4]  + v1[1] * v2[5]  + v1[2] * v2[ 6] + v1[3] * v2[ 7];
        r[2] = v1[0] * v2[8]  + v1[1] * v2[9]  + v1[2] * v2[10] + v1[3] * v2[11];
        r[3] = v1[0] * v2[12] + v1[1] * v2[13] + v1[2] * v2[14] + v1[3] * v2[15];
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


pub fn dot(v1: anytype, v2: anytype) @TypeOf(v1[0])
{
    const typ = @TypeOf(v1);
    if(typ != @TypeOf(v2))
    {
        unreachable;
    }
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
        return v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3];
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

    var result = Mat44Identity;
    result[0] = xScale;
    result[5] = -yScale;

    result[10] = -fRange;
    result[11] = -nearPlane * fRange;
    result[14] = -1.0;
    result[15] = 0.0;
    return result;
}

pub fn createPerspectiveReverseInfiniteMatrixRH(fovRad: f32, aspectRatio: f32, nearPlane: f32) Mat44
{
    assert(std.math.fabs(fovRad) > 0.00001);
    assert(std.math.fabs(aspectRatio) > 0.001);
    assert(std.math.fabs(nearPlane) > 0.0);

    const yScale: f32 = 1.0 / std.math.tan(fovRad * 0.5);
    const xScale: f32 = yScale / aspectRatio;

    var result = Mat44Identity;
    result[0] = xScale;
    result[5] = -yScale;

    result[10] = 0;
    result[11] = nearPlane;
    result[14] = -1.0;
    result[15] = 0.0;
    return result;
}


pub fn createMatrixFromLookAt(pos: Vec3, target: Vec3, up: Vec3) Mat44
{
    const forward = normalize(target - pos);
    const right = normalize(cross(up, forward));
    const realUp = normalize(cross(forward, right));

    var result: Mat44 = undefined;
    result[0] = right[0];
    result[1] = right[1];
    result[2] = right[2];
    result[3] = -dot(pos, right);

    result[4] = realUp[0];
    result[5] = realUp[1];
    result[6] = realUp[2];
    result[7] = -dot(pos, realUp);

    result[8]  = forward[0];
    result[9]  = forward[1];
    result[10] = forward[2];
    result[11] = -dot(pos, forward);

    result[12] = 0.0;
    result[13] = 0.0;
    result[14] = 0.0;
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


pub fn getMatrixFromRotation(right: Vec3, up: Vec3, forward: Vec3) Mat44
{
    var result = Mat44Identity;

    result[0] = right[0];
    result[1] = right[1];
    result[2] = right[2];

    result[4] = up[0];
    result[5] = up[1];
    result[6] = up[2];

    result[8] = forward[0];
    result[9] = forward[1];
    result[10] = forward[2];

    return result;
}

pub fn getMatrixFromQuaternion(quat: Quat) Mat44
{
    var result = Mat44Identity;
    result[0] = 1.0 - 2.0 * quat.v[1] * quat.v[1] - 2.0 * quat.v[2] * quat.v[2];
    result[1] = 2.0 * quat.v[0] * quat.v[1] - 2.0 * quat.w * quat.v[2];
    result[2] = 2.0 * quat.v[0] * quat.v[2] + 2.0 * quat.w * quat.v[1];

    result[4] = 2.0 * quat.v[0] * quat.v[1] + 2.0 * quat.w * quat.v[2];
    result[5] = 1.0 - 2.0 * quat.v[0] * quat.v[0] - 2.0 * quat.v[2] * quat.v[2];
    result[6] = 2.0 * quat.v[1] * quat.v[2] - 2.0 * quat.w * quat.v[0];

    result[8] = 2.0 * quat.v[0] * quat.v[2] - 2.0 * quat.w * quat.v[1];
    result[9] = 2.0 * quat.v[1] * quat.v[2] + 2.0 * quat.w * quat.v[0];
    result[10] = 1.0 - 2.0 * quat.v[0] * quat.v[0] - 2.0 * quat.v[1] * quat.v[1];

    return result;
}

pub fn getMatrixFromScale(scale: Vec3) Mat44
{
    var result = Mat44Identity;
    result[0] = scale[0];
    result[5] = scale[1];
    result[10] = scale[2];

    return result;
}

pub fn getMatrixFromTranslation(pos: Vec3) Mat44
{
    var result = Mat44Identity;
    result[3] = pos[0];
    result[7] = pos[1];
    result[11] = pos[2];

    return result;
}





pub fn rotateVector(v: Vec3, q: Quat) Vec3
{
    const d = sqrLen(q.v);
    return mul(v, (q.w * q.w - d)) + mul(@as(f32, 2.0), mul(q.v, dot(v, q.v)) + mul(cross(v, q.v), q.w));
}


pub fn getAxis(quat: Quat, right: *Vec3, up: *Vec3, forward: *Vec3) void
{
    right.x = 1.0 - 2.0 * quat.v[1] * quat.v[1] - 2.0 * quat.v[2] * quat.v[2];
    right.y = 2.0 * quat.v[0] * quat.v[1] + 2.0 * quat.w * quat.v[2];
    right.z = 2.0 * quat.v[0] * quat.v[2] - 2.0 * quat.w * quat.v[1];

    up.x = 2.0 * quat.v[0] * quat.v[1] - 2.0 * quat.w * quat.v[2];
    up.y = 1.0 - 2.0 * quat.v[0] * quat.v[0] - 2.0 * quat.v[2] * quat.v[2];
    up.z = 2.0 * quat.v[1] * quat.v[2] + 2.0 * quat.w * quat.v[0];

    forward.x = 2.0 * quat.v[0] * quat.v[2] + 2.0 * quat.w * quat.v[1];
    forward.y = 2.0 * quat.v[1] * quat.v[2] - 2.0 * quat.w * quat.v[0];
    forward.z = 1.0 - 2.0 * quat.v[0] * quat.v[0] - 2.0 * quat.v[1] * quat.v[1];
}


pub fn getQuaternionFromAxisAngle(v: Vec3, angle: f32) Quat
{
    return Quat{.v = mul(normalize(v), std.math.sin(-angle * 0.5)), .w = std.math.cos(-angle * 0.5)};
}


pub fn toRadians(degree: f32) f32
{
    return degree / 180.0 * std.math.pi;
}

pub fn toDegrees(rad: f32) f32
{
    return rad / std.math.pi * 180.0;
}