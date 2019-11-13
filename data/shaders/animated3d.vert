#version 130

in vec3 position;
in vec3 normal;

in vec4 bone_weight;
in uvec4 bone_idx;

out vec3 vert_normal;

uniform mat4 transform;
uniform mat4 projection;

void main()
{
	vec4 world_pos = transform * vec4(position, 1.0);
	vert_normal = (transform * vec4(normal, 0)).xyz;

	gl_Position = projection * world_pos;
}