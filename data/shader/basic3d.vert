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
	vec3 norm;
    uint tmp;
};

layout (std430, binding=2) restrict readonly buffer vertex_data
{
	VData vertexValues[];
};

//layout (location = 0) out flat vec4 colOut;
layout (location = 0) out vec4 colOut;
layout (location = 1) out vec4 posOut;
layout (location = 2) out vec4 normOut;

void main()
{
	vec3 pos = vertexValues[gl_VertexID].pos;
	uint col = vertexValues[gl_VertexID].col;
	vec3 norm = vertexValues[gl_VertexID].norm;

	gl_Position =  mvp * (matrix_padding * vec4(pos, 1.0f));
	vec3 rotatedNorm =  (matrix_padding * vec4(norm, 0.0f)).xyz;

    uvec4 cu = uvec4((col & 255u), (col >> 8u) & 255u, (col >> 16u) & 255u, (col >> 24u) & 255u);

	vec3 sunDir = normalize(vec3(0.5f, -1.0f, 0.5f));
	colOut = vec4(cu.xyz * 0.95f + 0.05f * (-dot(rotatedNorm, sunDir)), cu.w) / 255.0f;

	posOut = vec4(pos, 1.0f);
	normOut = vec4(norm, 1.0f);
}