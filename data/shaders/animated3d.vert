#version 150

uniform mat4 transform;
uniform mat4 projection;

uniform mat4 bones[64];

// The y coordinate for the ceiling of the lights
uniform float area_ceiling;
// The distance from the ceiling before the light is completely dark
uniform float area_span;

uniform float nearPlane;
uniform float farPlane;

in vec3 position;
in vec3 normal;
in vec2 uv;

in vec4 bone_weight;
in uvec4 bone_idx;

out vec3 vert_normal;
out vec2 vert_uv;
out float area_gradient;

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
	gl_Position.z = (2*log(nearPlane*gl_Position.w + 1)/log(nearPlane*farPlane + 1) - 1) * gl_Position.w;

	vec4 sknorm = skmatrix * vec4(normal, 0);
	vert_normal = (transform * sknorm).xyz;
	vert_uv = uv;
	area_gradient = 1 - clamp(-(area_ceiling - world_pos.y)/area_span, 0, 1);
}