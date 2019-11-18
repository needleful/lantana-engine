#version 150

uniform mat4 transform;
uniform mat4 projection;

uniform mat4x3 bones[24];

in vec3 position;
in vec3 normal;

in vec4 bone_weight;
in uvec4 bone_idx;

out vec3 vert_normal;

vec3 skinned(vec4 invec)
{
	return
		  bone_weight.x * (bones[bone_idx.x]*invec)
		+ bone_weight.y * (bones[bone_idx.y]*invec)
		+ bone_weight.z * (bones[bone_idx.z]*invec)
		+ bone_weight.w * (bones[bone_idx.w]*invec);
}

void main()
{
	vec3 skpos = skinned(vec4(position, 1));
	vec4 world_pos = transform * vec4(skpos, 1.0);
	gl_Position = projection * world_pos;

	vec3 sknorm = inverse(transpose(
		  bone_weight.x * mat3(bones[bone_idx.x])
		+ bone_weight.y * mat3(bones[bone_idx.y])
		+ bone_weight.z * mat3(bones[bone_idx.z])
		+ bone_weight.w * mat3(bones[bone_idx.w])
		)) * normal;
	vert_normal = (transform * vec4(sknorm, 0)).xyz;

}