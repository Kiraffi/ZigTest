#version 450 core

layout (location = 0) out vec4 vColor;

struct Data
{
    vec4 positions;
    uint color;
    float rotationAngle;
    vec2 padding;
};

layout (std140, binding=0) uniform frame_data
{
    vec2 screenSizes;
    uvec2 padding;
} vFrame;

layout (std430, binding = 1) buffer shader_data
{
    Data values[];
} vData;


void main()
{
    int vertId = gl_VertexID / 4;
    int v = gl_VertexID % 4;
    vec4 poses = vData.values[vertId].positions;
    vec2 pos = poses.xy;
    pos.x = v % 2 == 0 ? poses.x : poses.z;
    pos.y = v / 2 == 0 ? poses.y : poses.w;
    uint col = vData.values[vertId].color;
    vColor = vec4( uvec4(col, col >> 8, col >> 16, col >> 24) & 255u) / 255.0f;
    gl_Position = vec4((pos.xy / vFrame.screenSizes)  * 2.0f - 1.0f, 0.0f, 1.0f);
};
