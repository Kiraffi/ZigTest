#version 450
#extension GL_ARB_separate_shader_objects : enable

out gl_PerVertex 
{
    vec4 gl_Position;
};

struct VData
{
    vec3 pos;
    uint col;
};

layout (set = 0, std430, binding=0) restrict readonly buffer vertex_data
{
    VData vertexValues[];
};


layout(location = 0) out vec3 fragColor;

vec2 positions[3] = vec2[](
    vec2(0.0, -0.5),
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5)
);

vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void main() 
{
    //gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    //fragColor = colors[gl_VertexIndex];

    gl_Position = vec4(vertexValues[gl_VertexIndex].pos.xyz, 1.0);
    uint col = vertexValues[gl_VertexIndex].col;
    fragColor = vec3( float(col & 255u), float((col >> 8u) & 255u), float((col >> 16u) & 255u) ) / 255.0f;
}


