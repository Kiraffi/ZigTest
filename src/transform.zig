const Math = @import("vector.zig");

pub const Transform = extern struct
{
    pos: Math.Vec3 = Math.Vec3{0.0, 0.0, 0.0},
    parentIndex: u32 = 0,

    rot: Math.Quat = Math.Quat{},

    scale: Math.Vec3 = Math.Vec3{1, 1, 1},
    padding: u32 = 0,

    pub fn getTransformAsCameraMatrix(self: *const Transform) Math.Mat44
    {
        const upDir =      Math.rotateVector(Math.Vec3{0, 1, 0}, self.rot);
        const forwardDir = Math.rotateVector(Math.Vec3{0, 0, 1}, self.rot);

        return (Math.createMatrixFromLookAt(self.pos, self.pos + forwardDir, upDir));
    }
};


