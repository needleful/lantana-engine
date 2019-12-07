#version 150

uniform mat4 transform;
uniform mat4 projection;

uniform mat4 bones[24];

in vec3 position;
in vec3 normal;

in vec4 bone_weight;
in uvec4 bone_idx;

out vec3 vert_normal;
out vec3 debug_color;

void main()
{

	vec4 pos = vec4(position, 1);
	vec4 skpos = 
		  bone_weight.x * (bones[bone_idx.x]*pos)
		+ bone_weight.y * (bones[bone_idx.y]*pos)
		+ bone_weight.z * (bones[bone_idx.z]*pos)
		+ bone_weight.w * (bones[bone_idx.w]*pos);

	//debug_color = vec3(bones[bone_idx.x][0][0], bones[bone_idx.y][0][0], bones[bone_idx.z][0][0])*bone_weight.xyz;
	debug_color = vec3(
		bone_weight.x + bone_weight.y + bone_weight.z + bone_weight.w,
		bone_idx.x < 23u && bone_idx.y < 23u && bone_idx.z < 23u && bone_idx.w <23u,
		(bones[bone_idx.x][0][0] + bones[bone_idx.y][0][0] + bones[bone_idx.z][0][0] + bones[bone_idx.w][0][0])/4);

	vec4 world_pos = transform * vec4(skpos.xyz, 1);
	gl_Position = projection * world_pos;

	vec3 sknorm = inverse(transpose(
		  bone_weight.x * mat3(bones[bone_idx.x])
		+ bone_weight.y * mat3(bones[bone_idx.y])
		+ bone_weight.z * mat3(bones[bone_idx.z])
		+ bone_weight.w * mat3(bones[bone_idx.w])
		)) * normal;
	vert_normal = (transform * vec4(sknorm, 0)).xyz;
}