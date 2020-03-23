#version 130

uniform mat4 transform;
uniform mat4 projection;

// The y coordinate for the ceiling of the lights
uniform float area_ceiling;
// The distance from the ceiling before the light is completely dark
uniform float area_span;

uniform float nearPlane;
uniform float farPlane;

in vec3 position;
in vec3 normal;
in vec2 uv;

out vec3 vert_normal;
out vec2 vert_uv;
out float area_gradient;

void main()
{
	vec4 world_pos = transform * vec4(position, 1.0);
	gl_Position = projection * world_pos;
	gl_Position.z = (2*log(nearPlane*gl_Position.w + 1)/log(nearPlane*farPlane + 1) - 1) * gl_Position.w;

	vert_normal = (transform * vec4(normal, 0)).xyz;
	vert_uv = uv;
	area_gradient = 1 - clamp(-(area_ceiling - world_pos.y)/area_span, 0, 1);

}