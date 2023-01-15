#version 450 core

layout (std140, binding=0) uniform frame_data
{
    vec2 screenSizes;
    vec2 padding;
};

layout (location = 0) out vec4 vColor;

void main()
{
    uint vertId = gl_VertexID;

    vec2 pos = vec2(0.0f, 0.0f);
    vec4 col = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    if(vertId == 0 || vertId == 3 || vertId == 5 || vertId == 12 || vertId == 15 || vertId == 17)
        pos.x = -1.0f;
    if(vertId == 1 || vertId == 2 || vertId == 4 || vertId == 13 || vertId == 14 || vertId == 16)
        pos.x = -0.9f;
    if(vertId == 6 || vertId == 9 || vertId == 11 || vertId == 18 || vertId == 21 || vertId == 23)
        pos.x = 0.9f;
    if(vertId == 7 || vertId == 8 || vertId == 10 || vertId == 19 || vertId == 20 || vertId == 22)
        pos.x = 1.0f;

    if(vertId == 0 || vertId == 1 || vertId == 3 || vertId == 6 || vertId == 7 || vertId == 9)
        pos.y = -1.0f;
    if(vertId == 2 || vertId == 4 || vertId == 5 || vertId == 8 || vertId == 10 || vertId == 11)
        pos.y = -0.9f;

    if(vertId == 12 || vertId == 13 || vertId == 15 || vertId == 18 || vertId == 19 || vertId == 21)
        pos.y = 0.9f;

    if(vertId == 14 || vertId == 16 || vertId == 17 || vertId == 20 || vertId == 22 || vertId == 23)
        pos.y = 1.0f;

    if(vertId < 6)
        col.r = 1.0f;
    else if(vertId < 12)
        col.g = 1.0f;
    else if(vertId < 18)
        col.b = 1.0f;
    else if(vertId < 24)
        col.rgb = vec3(1.0f, 1.0f, 1.0f);

    vColor = col;

    gl_Position = vec4(pos, 1.0f, 1.0f);

}