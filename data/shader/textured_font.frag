#version 450 core
layout (location = 0) in vec4 vColor;
layout (location = 1) in vec2 vTexCoord;

layout (location = 0) out vec4 outColor;

layout (binding = 0) uniform sampler2D ourTexture;

void main()
{
    vec4 sampledColor = texture(ourTexture, vTexCoord);
    if(sampledColor.a > 0.5f)
        sampledColor.a = 1.0f;
    else
        sampledColor.a = 0.0f;
    outColor = sampledColor;
}