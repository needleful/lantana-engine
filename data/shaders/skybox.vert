#version 130

uniform mat4 transform;
uniform mat4 projection;

in vec3 position;
in vec3 color;
in vec2 uv;

out vec2 vert_uv;
out vec3 vert_color;

void main()
{
	vec4 world_pos = transform * vec4(position, 1.0);
	gl_Position = projection * world_pos;

	vert_color = color;
	vert_uv = uv;
}