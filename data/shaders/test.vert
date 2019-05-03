#version 130

in vec2 position;
in vec2 UV;

out vec2 vert_uv;

uniform vec2 uv_offset;
uniform vec2 translate;
uniform vec2 scale;
uniform vec2 cam_position;
uniform ivec2 cam_resolution;

void main()
{
	vert_uv = UV+uv_offset;
	// Camera-space position
	vec2 pos = position + translate - cam_position;
	// camera-space scale
	vec2 s = scale/cam_resolution;
	gl_Position = vec4(pos*s, 0, 1);
}