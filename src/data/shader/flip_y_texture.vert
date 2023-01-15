#version 450 core

layout (std140, binding=0) uniform frame_data
{
    vec2 screenSizes;
    vec2 padding;
};

layout (location = 0) out vec4 vColor;
layout (location = 1) out vec2 vTexCoord;

void main()
{
    uint vertId = gl_VertexID;

    vec2 pos = vec2(1.0f, 1.0f);
    vec4 col = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    if(vertId == 0 || vertId == 3)// || vertId == 5)
        pos.x = -1.0f;

    if(vertId == 0 || vertId == 1)// || vertId == 3)
        pos.y = -1.0f;

    vColor = col;
    gl_Position = vec4(pos, 1.0f, 1.0f);
    vTexCoord = (pos * 0.5f) + 0.5f;
    vTexCoord.y = 1.0f - vTexCoord.y;
}