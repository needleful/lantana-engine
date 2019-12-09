#version 150

uniform mat4 transform;
uniform mat4 projection;

uniform mat4 bones[24];

in vec3 position;
in vec3 normal;

in vec4 bone_weight;
in uvec4 bone_idx;

out vec3 vert_normal;

void main()
{
	mat4 skmatrix = 
		  bones[bone_idx.x]*bone_weight.x
		+ bones[bone_idx.y]*bone_weight.y
		+ bones[bone_idx.z]*bone_weight.z
		+ bones[bone_idx.w]*bone_weight.w;

	vec4 skpos = skmatrix*vec4(position, 1);
	vec4 world_pos = transform * skpos;

	gl_Position = projection * world_pos;

	vec4 sknorm = skmatrix * vec4(normal, 0);
	vert_normal = (transform * sknorm).xyz;
}