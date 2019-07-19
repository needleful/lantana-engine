#version 400
uniform ivec2 translation;
uniform uvec2 screen_size;

layout(location = 0) in ivec2 vert_position;
layout(location = 1) in vec2 vert_uv;

out vec2 frag_uv;

void main()
{
	ivec2 pos = vert_position + translation;
	vec2 pos_norm = pos*2.0/screen_size;
	frag_uv = vert_uv;
	gl_Position = vec4(pos_norm - vec2(1, 1), 0.0, 1.0);
}