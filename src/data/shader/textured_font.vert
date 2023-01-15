#version 450 core

struct VertexData
{
    vec2 pos;
    vec2 size;
    vec2 uv;
    uint col;
    float tmp;
};

layout (std140, binding=0) uniform frame_data
{
    vec2 screenSizes;
    vec2 padding;
};

layout (std430, binding=1) restrict readonly buffer shader_data
{
    VertexData values[];
} vData;


layout (location = 0) out vec4 vColor;
layout (location = 1) out vec2 vTexCoord;

void main()
{
    uint vertId = gl_VertexID / 4;
    uint v = gl_VertexID % 4;
    vec2 pp = vec2(0.5f, 0.5f);
    if(v == 0 || v == 1)
    {
        pp.y = -0.5f;
    }
    if(v == 0 || v == 3)
    {
        pp.x = -0.5f;
    }

    vTexCoord = pp + 0.5f;
    vTexCoord.y = 1.0f - vTexCoord.y;
    vTexCoord.x += vData.values[(vertId)].uv.x;
    vTexCoord.x /= (128.0f-32.0f);


    pp.xy *= vData.values[vertId].size;
    pp.xy += vData.values[vertId].pos;

    pp.xy = pp.xy / (screenSizes.xy * 0.5f) - 1.0f;
    gl_Position = vec4(vec3(pp.xy, 1.0f) , 1.0);
    uint col = vData.values[vertId].col;

    uvec4 cu = uvec4((col & 255u), (col >> 8u) & 255u, (col >> 16u) & 255u, (col >> 24u) & 255u);
    vColor = vec4(cu) / 255.0f;
}