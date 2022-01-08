#version 450 core

layout (location = 0) in vec4 vColor;

layout (location = 0) out vec4 outColor;
layout (location = 1) out vec4 outColor2;

void main()
{
   outColor = vColor; // vec4(1.0f, 0.5f, 0.2f, 1.0f);
   outColor2 = vColor.bgra; // vec4(1.0f, 0.5f, 0.2f, 1.0f);
};
