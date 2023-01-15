#version 450 core

layout (binding = 0) uniform frame_data
{
    vec2 windowSize;
    vec2 padding;

};

layout (binding = 1, row_major) uniform FrameDataBlock
{
    mat4 cameraMatrix;
    mat4 viewProjMat;
    mat4 mvp;
    mat4 matrix_padding;
};




struct VData
{
    vec3 pos;
    uint col;
};

layout (std430, binding=2) restrict readonly buffer vertex_data
{
    VData vertexValues[];
};

//layout (location = 0) out flat vec4 colOut;
layout (location = 0) out vec4 colOut;

void main()
{
    vec3 pos = vertexValues[gl_VertexID].pos;
    uint col = vertexValues[gl_VertexID].col;

    gl_Position =  vec4(pos, 1.0);

    uvec4 cu = uvec4((col & 255u), (col >> 8u) & 255u, (col >> 16u) & 255u, (col >> 24u) & 255u);
    colOut = cu / 255.0f;

    // depth vis
    //colOut = vec4(vec3(pos.z), 1.0f);
    //colOut = vec4(vec3(pos.z * pos.z), 1.0f);
}