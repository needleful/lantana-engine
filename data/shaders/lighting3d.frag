#version 130

uniform vec3 light_direction;
uniform float light_bias;

in vec3 vert_normal;
in float area_gradient;

out vec3 out_color;

void main()
{
	float light = dot(normalize(light_direction), normalize(vert_normal)) + light_bias;
	light = clamp(light, 0, 1);
	vec2 color_mult = vec2(light, area_gradient);
	out_color = vec3(color_mult, 0.1);
}