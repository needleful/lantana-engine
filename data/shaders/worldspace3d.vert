#version 130

uniform mat4 transform;
uniform mat4 projection;

// The y coordinate for the ceiling of the lights
uniform float area_ceiling;
// The distance from the ceiling before the light is completely dark
uniform float area_span;

in vec3 position;
in vec3 normal;

out vec3 vert_normal;
out float area_gradient;


void main()
{
	vec4 world_pos = transform * vec4(position, 1.0);
	vert_normal = (transform * vec4(normal, 0)).xyz;

	gl_Position = projection * world_pos;

	area_gradient = 1 - clamp(-(area_ceiling - world_pos.y)/area_span, 0, 1);
}