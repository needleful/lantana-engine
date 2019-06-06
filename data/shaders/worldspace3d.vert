#version 130

in vec3 position;

out vec4 vert_color;

uniform mat4 transform;
uniform mat4 projection;

void main()
{
	vec4 world_pos = transform * vec4(position.x, position.y, position.z, 1.0);
	vert_color = clamp(world_pos, 0.0, 1.0);
	vert_color.a = 1.0;

	gl_Position = projection * world_pos;
}